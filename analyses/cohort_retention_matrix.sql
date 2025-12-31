/*
    Cohort Retention Matrix Analysis

    This complex analytical query builds a customer retention matrix from scratch,
    demonstrating advanced SQL techniques:
    - CTEs for modular logic
    - Window functions (LAG, SUM OVER, FIRST_VALUE)
    - CROSS JOIN for generating time periods
    - Pivot-style aggregation
    - Conditional aggregation with CASE

    Business Question: How well do we retain customers over time, segmented by their signup cohort?
*/

with customer_cohorts as (
    -- Assign each customer to their signup month cohort
    select
        customer_id,
        date_trunc('month', signup_date)::date as cohort_month,
        signup_date
    from {{ ref('dim_customers') }}
),

customer_orders as (
    -- Get all orders with their order month
    select
        user_id as customer_id,
        order_id,
        order_date,
        date_trunc('month', order_date)::date as order_month,
        subtotal as order_value
    from {{ ref('fct_orders') }}
    where order_status = 'completed'
),

-- Generate all possible cohort + period combinations
cohort_periods as (
    select distinct
        c.cohort_month,
        o.order_month as period_month,
        -- Calculate months since cohort start
        (extract(year from o.order_month) - extract(year from c.cohort_month)) * 12 +
        (extract(month from o.order_month) - extract(month from c.cohort_month)) as months_since_signup
    from customer_cohorts c
    cross join (select distinct date_trunc('month', order_date)::date as order_month from {{ ref('fct_orders') }}) o
    where o.order_month >= c.cohort_month
),

-- Calculate cohort sizes (customers who signed up in each cohort)
cohort_sizes as (
    select
        cohort_month,
        count(distinct customer_id) as cohort_size
    from customer_cohorts
    group by 1
),

-- Calculate activity per cohort per period
cohort_activity as (
    select
        cc.cohort_month,
        cp.months_since_signup,
        cp.period_month,
        count(distinct co.customer_id) as active_customers,
        count(distinct co.order_id) as total_orders,
        coalesce(sum(co.order_value), 0) as period_revenue
    from cohort_periods cp
    inner join customer_cohorts cc on cp.cohort_month = cc.cohort_month
    left join customer_orders co on cc.customer_id = co.customer_id
        and cp.period_month = co.order_month
    group by 1, 2, 3
),

-- Build the retention matrix with advanced metrics
retention_matrix as (
    select
        ca.cohort_month,
        to_char(ca.cohort_month, 'YYYY-MM') as cohort_label,
        cs.cohort_size,
        ca.months_since_signup,
        ca.period_month,
        ca.active_customers,
        ca.total_orders,
        ca.period_revenue,

        -- Retention rate: % of cohort still active in this period
        round(
            (ca.active_customers::decimal / nullif(cs.cohort_size, 0)) * 100,
            2
        ) as retention_rate_pct,

        -- Orders per active customer
        round(
            ca.total_orders::decimal / nullif(ca.active_customers, 0),
            2
        ) as orders_per_active_customer,

        -- Average order value in period
        round(
            ca.period_revenue / nullif(ca.total_orders, 0),
            2
        ) as avg_order_value,

        -- Cumulative revenue per cohort customer (LTV proxy)
        round(
            sum(ca.period_revenue) over (
                partition by ca.cohort_month
                order by ca.months_since_signup
                rows between unbounded preceding and current row
            ) / nullif(cs.cohort_size, 0),
            2
        ) as cumulative_ltv_per_customer,

        -- Month-over-month retention change
        ca.active_customers - lag(ca.active_customers) over (
            partition by ca.cohort_month
            order by ca.months_since_signup
        ) as customer_change_vs_prior_month,

        -- First month revenue for comparison
        first_value(ca.period_revenue) over (
            partition by ca.cohort_month
            order by ca.months_since_signup
        ) as first_month_revenue,

        -- Revenue as % of first month (revenue retention)
        round(
            ca.period_revenue / nullif(
                first_value(ca.period_revenue) over (
                    partition by ca.cohort_month
                    order by ca.months_since_signup
                ), 0
            ) * 100,
            2
        ) as revenue_retention_pct

    from cohort_activity ca
    inner join cohort_sizes cs on ca.cohort_month = cs.cohort_month
    where ca.active_customers > 0  -- Only show periods with activity
)

-- Final output: Retention matrix with all metrics
select
    cohort_label,
    cohort_size,
    months_since_signup as period,
    active_customers,
    retention_rate_pct,
    total_orders,
    orders_per_active_customer,
    period_revenue,
    avg_order_value,
    cumulative_ltv_per_customer,
    customer_change_vs_prior_month as churn_indicator,
    revenue_retention_pct,

    -- Retention health classification
    case
        when months_since_signup = 0 then 'New'
        when retention_rate_pct >= 50 then 'Excellent'
        when retention_rate_pct >= 30 then 'Good'
        when retention_rate_pct >= 15 then 'Average'
        else 'At Risk'
    end as retention_health

from retention_matrix
order by cohort_month, months_since_signup

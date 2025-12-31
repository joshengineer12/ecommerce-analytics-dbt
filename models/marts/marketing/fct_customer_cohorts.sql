{{
    config(
        materialized='table'
    )
}}

with customers as (
    select * from {{ ref('dim_customers') }}
),

orders as (
    select * from {{ ref('fct_orders') }}
),

-- Get signup cohort for each customer
customer_cohorts as (
    select
        customer_id,
        date_trunc('month', signup_date)::date as cohort_month
    from customers
),

-- Calculate months since signup for each order
order_cohort_data as (
    select
        o.order_id,
        o.user_id as customer_id,
        o.order_date,
        o.subtotal as gross_amount,
        o.net_revenue,
        cc.cohort_month,
        {{ datediff('cc.cohort_month', 'o.order_date', 'month') }} as months_since_signup
    from orders o
    inner join customer_cohorts cc on o.user_id = cc.customer_id
),

-- Aggregate by cohort and period
cohort_metrics as (
    select
        cohort_month,
        months_since_signup,

        -- Customer Metrics
        count(distinct customer_id) as active_customers,
        count(distinct order_id) as order_count,

        -- Revenue Metrics
        sum(gross_amount) as gross_revenue,
        sum(net_revenue) as net_revenue,
        avg(gross_amount) as avg_order_value

    from order_cohort_data
    group by 1, 2
),

-- Get cohort size (total customers who signed up in each month)
cohort_sizes as (
    select
        cohort_month,
        count(distinct customer_id) as cohort_size
    from customer_cohorts
    group by 1
),

final as (
    select
        cm.cohort_month,
        cm.months_since_signup,
        cs.cohort_size,

        -- Activity Metrics
        cm.active_customers,
        cm.order_count,

        -- Retention Rate
        (cm.active_customers::float / cs.cohort_size) * 100 as retention_rate_pct,

        -- Revenue Metrics
        cm.gross_revenue,
        cm.net_revenue,
        cm.avg_order_value,

        -- Revenue per Cohort Customer
        cm.gross_revenue / cs.cohort_size as revenue_per_cohort_customer,

        -- Cumulative Revenue
        sum(cm.net_revenue) over (
            partition by cm.cohort_month
            order by cm.months_since_signup
            rows between unbounded preceding and current row
        ) as cumulative_revenue,

        -- Cumulative Revenue per Customer
        sum(cm.net_revenue) over (
            partition by cm.cohort_month
            order by cm.months_since_signup
            rows between unbounded preceding and current row
        ) / cs.cohort_size as cumulative_revenue_per_customer,

        -- Metadata
        current_timestamp as _updated_at

    from cohort_metrics cm
    left join cohort_sizes cs on cm.cohort_month = cs.cohort_month
)

select * from final

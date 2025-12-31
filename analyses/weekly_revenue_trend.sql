-- Weekly Revenue Trend Analysis
-- Shows revenue trends with week-over-week growth

with weekly_metrics as (
    select
        date_trunc('week', order_date)::date as week_start,
        count(distinct order_id) as orders,
        count(distinct user_id) as customers,
        sum(subtotal) as gross_revenue,
        sum(net_revenue) as net_revenue,
        avg(subtotal) as avg_order_value
    from {{ ref('fct_orders') }}
    group by 1
),

with_growth as (
    select
        week_start,
        orders,
        customers,
        gross_revenue,
        net_revenue,
        avg_order_value,

        -- Week-over-Week Changes
        lag(net_revenue) over (order by week_start) as prev_week_revenue,
        lag(orders) over (order by week_start) as prev_week_orders,

        -- Cumulative Metrics
        sum(net_revenue) over (order by week_start rows unbounded preceding) as cumulative_revenue

    from weekly_metrics
)

select
    week_start,
    orders,
    customers,
    round(gross_revenue, 2) as gross_revenue,
    round(net_revenue, 2) as net_revenue,
    round(avg_order_value, 2) as avg_order_value,

    -- Growth Metrics
    round(
        case
            when prev_week_revenue > 0 then
                ((net_revenue - prev_week_revenue) / prev_week_revenue) * 100
            else null
        end, 2
    ) as revenue_wow_growth_pct,

    round(
        case
            when prev_week_orders > 0 then
                ((orders - prev_week_orders)::float / prev_week_orders) * 100
            else null
        end, 2
    ) as orders_wow_growth_pct,

    round(cumulative_revenue, 2) as cumulative_revenue

from with_growth
order by week_start

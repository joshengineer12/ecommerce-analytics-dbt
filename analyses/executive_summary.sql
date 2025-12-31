-- Executive Summary Dashboard Query
-- Provides high-level KPIs for leadership reporting

with date_range as (
    select
        min(order_date) as period_start,
        max(order_date) as period_end
    from {{ ref('fct_orders') }}
),

order_metrics as (
    select
        count(distinct order_id) as total_orders,
        count(distinct user_id) as unique_customers,
        sum(subtotal) as gross_revenue,
        sum(net_revenue) as net_revenue,
        sum(gross_profit) as gross_profit,
        avg(subtotal) as avg_order_value,
        sum(case when is_returned then 1 else 0 end) as orders_with_returns
    from {{ ref('fct_orders') }}
),

customer_metrics as (
    select
        count(distinct customer_id) as total_customers,
        sum(case when is_repeat_customer then 1 else 0 end) as repeat_customers,
        avg(total_revenue) as avg_customer_ltv
    from {{ ref('dim_customers') }}
),

product_metrics as (
    select
        count(distinct product_id) as active_products,
        sum(total_revenue) as product_revenue,
        avg(return_rate) as avg_return_rate
    from {{ ref('mart_product_performance') }}
    where total_revenue > 0
)

select
    -- Period
    dr.period_start,
    dr.period_end,

    -- Order KPIs
    om.total_orders,
    om.unique_customers as ordering_customers,
    om.gross_revenue,
    om.net_revenue,
    om.gross_profit,
    round(om.avg_order_value, 2) as avg_order_value,
    round((om.gross_profit / nullif(om.gross_revenue, 0)) * 100, 2) as gross_margin_pct,

    -- Customer KPIs
    cm.total_customers,
    cm.repeat_customers,
    round((cm.repeat_customers::float / nullif(cm.total_customers, 0)) * 100, 2) as repeat_rate_pct,
    round(cm.avg_customer_ltv, 2) as avg_customer_ltv,

    -- Product KPIs
    pm.active_products,
    round(pm.avg_return_rate * 100, 2) as avg_return_rate_pct,

    -- Return KPIs
    om.orders_with_returns,
    round((om.orders_with_returns::float / nullif(om.total_orders, 0)) * 100, 2) as order_return_rate_pct

from date_range dr
cross join order_metrics om
cross join customer_metrics cm
cross join product_metrics pm

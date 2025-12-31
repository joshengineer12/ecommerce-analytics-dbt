{{
    config(
        materialized='table'
    )
}}

with customers as (
    select * from {{ ref('dim_customers') }}
),

segment_metrics as (
    select
        -- Segment Dimensions
        customer_segment,
        customer_tier,
        region,
        activity_status,

        -- Customer Counts
        count(distinct customer_id) as customer_count,

        -- Order Metrics
        sum(lifetime_orders) as total_orders,
        sum(total_orders) as completed_orders,
        avg(lifetime_orders) as avg_orders_per_customer,

        -- Revenue Metrics
        sum(total_revenue) as total_revenue,
        sum(total_net_revenue) as total_net_revenue,
        avg(total_revenue) as avg_revenue_per_customer,
        avg(avg_order_value) as avg_order_value,

        -- Profitability
        sum(total_gross_profit) as total_gross_profit,
        avg(total_gross_profit / nullif(total_revenue, 0)) * 100 as avg_margin_pct,

        -- Behavior Metrics
        sum(total_returned_items) as total_returns,
        sum(total_refunds) as total_refunds,
        avg(orders_with_returns::float / nullif(total_orders, 0)) * 100 as avg_return_rate_pct,

        -- Customer Quality
        sum(case when is_repeat_customer then 1 else 0 end) as repeat_customers,
        sum(high_value_orders) as high_value_orders

    from customers
    group by 1, 2, 3, 4
),

final as (
    select
        *,

        -- Derived Metrics
        {{ safe_divide('repeat_customers', 'customer_count') }} * 100 as repeat_customer_pct,

        {{ safe_divide('total_refunds', 'total_revenue') }} * 100 as refund_rate_pct,

        -- Customer Lifetime Value Proxy
        {{ safe_divide('total_net_revenue', 'customer_count') }} as avg_customer_ltv,

        -- Metadata
        current_timestamp as _updated_at

    from segment_metrics
)

select * from final

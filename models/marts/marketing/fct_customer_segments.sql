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
        0 as high_value_orders  -- simplified since column doesn't exist

    from customers
    group by 1, 2, 3, 4
),

final as (
    select
        *,

        -- Derived Metrics
        case
            when customer_count > 0 then
                (repeat_customers::float / customer_count) * 100
            else 0
        end as repeat_customer_pct,

        case
            when total_revenue > 0 then
                (total_refunds / total_revenue) * 100
            else 0
        end as refund_rate_pct,

        -- Customer Lifetime Value Proxy
        total_net_revenue / nullif(customer_count, 0) as avg_customer_ltv,

        -- Metadata
        current_timestamp as _updated_at

    from segment_metrics
)

select * from final

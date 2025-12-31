with orders_enriched as (
    select * from {{ ref('int_orders_enriched') }}
),

order_items_enriched as (
    select * from {{ ref('int_order_items_enriched') }}
),

-- Customer-level order aggregations
customer_orders as (
    select
        user_id,

        -- Order Counts
        count(distinct order_id) as total_orders,
        count(distinct case when is_completed then order_id end) as completed_orders,
        count(distinct case when is_cancelled then order_id end) as cancelled_orders,
        count(distinct case when is_completed and is_high_value_order then order_id end) as high_value_orders,

        -- Revenue Metrics
        sum(case when is_completed then total_amount else 0 end) as total_revenue,
        sum(case when is_completed then net_revenue else 0 end) as total_net_revenue,
        sum(case when is_completed then total_gross_profit else 0 end) as total_gross_profit,

        -- Average Order Value
        avg(case when is_completed then total_amount end) as avg_order_value,

        -- Order Dates
        min(case when is_completed then order_date end) as first_order_date,
        max(case when is_completed then order_date end) as last_order_date

    from orders_enriched
    group by 1
),

-- Customer-level item aggregations
customer_items as (
    select
        user_id,
        sum(quantity) as total_items_ordered,
        avg(quantity) as avg_items_per_order,
        count(distinct case when is_returned then order_item_id end) as total_returned_items,
        sum(case when is_returned then refund_amount else 0 end) as total_refunds,
        count(distinct case when is_returned then order_id end) as orders_with_returns
    from order_items_enriched
    where is_completed = true
    group by 1
),

final as (
    select
        co.user_id,

        -- Order Metrics
        co.total_orders,
        co.completed_orders,
        co.cancelled_orders,
        co.high_value_orders,

        -- Revenue Metrics
        co.total_revenue,
        co.total_net_revenue,
        co.total_gross_profit,
        co.avg_order_value,

        -- Date Metrics
        co.first_order_date,
        co.last_order_date,

        -- Item Metrics
        coalesce(ci.total_items_ordered, 0) as total_items_ordered,
        coalesce(ci.avg_items_per_order, 0) as avg_items_per_order,
        coalesce(ci.total_returned_items, 0) as total_returned_items,
        coalesce(ci.total_refunds, 0) as total_refunds,
        coalesce(ci.orders_with_returns, 0) as orders_with_returns

    from customer_orders co
    left join customer_items ci on co.user_id = ci.user_id
)

select * from final

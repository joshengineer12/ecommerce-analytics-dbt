{{
    config(
        materialized='view'
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
),

users as (
    select * from {{ ref('stg_users') }}
),

order_items_enriched as (
    select * from {{ ref('int_order_items_enriched') }}
),

-- Aggregate order items to order level
order_line_items as (
    select
        order_id,
        count(distinct order_item_id) as item_count,
        sum(quantity) as total_units,
        sum(gross_amount) as total_amount,
        sum(total_cost) as total_cost,
        sum(gross_profit) as total_gross_profit,
        sum(refund_amount) as total_refund_amount,
        sum(net_revenue) as net_revenue,
        max(case when is_returned then 1 else 0 end) as has_returns
    from order_items_enriched
    group by 1
),

final as (
    select
        -- Order Keys
        o.order_id,
        o.user_id,
        o.order_date,

        -- User Context
        u.email,
        u.customer_segment,
        u.country,
        u.region,
        u.signup_date,

        -- Order Status
        o.order_status,
        o.is_completed,
        o.is_cancelled,
        o.is_high_value_order,

        -- Order Composition
        coalesce(oli.item_count, 0) as item_count,
        coalesce(oli.total_units, 0) as total_units,
        coalesce(oli.total_amount, 0) as total_amount,
        coalesce(oli.total_cost, 0) as total_cost,
        coalesce(oli.total_gross_profit, 0) as total_gross_profit,
        coalesce(oli.total_refund_amount, 0) as total_refund_amount,
        coalesce(oli.net_revenue, 0) as net_revenue,

        -- Return Flag
        case when oli.has_returns = 1 then true else false end as has_returns,

        -- Date Dimensions
        o.order_month,
        o.order_week,
        o.day_of_week,

        -- Surrogate Key
        {{ dbt_utils.generate_surrogate_key(['o.order_id', 'o.user_id']) }} as order_surrogate_key,

        -- Metadata
        o._loaded_at

    from orders o
    left join users u on o.user_id = u.user_id
    left join order_line_items oli on o.order_id = oli.order_id
)

select * from final

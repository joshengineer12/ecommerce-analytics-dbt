-- Test to ensure all order items belong to existing orders

with orphan_items as (
    select
        oi.order_item_id,
        oi.order_id
    from {{ ref('stg_order_items') }} oi
    left join {{ ref('stg_orders') }} o on oi.order_id = o.order_id
    where o.order_id is null
)

select *
from orphan_items

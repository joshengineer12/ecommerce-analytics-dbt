-- Test to ensure refund amounts don't exceed order totals

with returns_with_orders as (
    select
        r.return_id,
        r.order_item_id,
        r.refund_amount,
        oi.line_total as item_total
    from {{ ref('stg_returns') }} r
    inner join {{ ref('stg_order_items') }} oi on r.order_item_id = oi.order_item_id
)

select *
from returns_with_orders
where refund_amount > item_total * 1.1  -- Allow 10% tolerance for shipping refunds

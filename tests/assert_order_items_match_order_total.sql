-- Test to ensure order item line totals approximately match order totals
-- Allows for small rounding differences (within $1)

with order_totals as (
    select
        order_id,
        total_amount
    from {{ ref('stg_orders') }}
    where order_status = 'completed'
),

item_totals as (
    select
        order_id,
        sum(line_total) as calculated_total
    from {{ ref('stg_order_items') }}
    group by 1
),

comparison as (
    select
        ot.order_id,
        ot.total_amount,
        it.calculated_total,
        abs(ot.total_amount - it.calculated_total) as difference
    from order_totals ot
    inner join item_totals it on ot.order_id = it.order_id
)

select *
from comparison
where difference > 1  -- Allow $1 tolerance for rounding

{{
    config(
        materialized='view'
    )
}}

with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

returns as (
    select * from {{ ref('stg_returns') }}
),

final as (
    select
        -- Order Item Keys
        oi.order_item_id,
        oi.order_id,
        oi.product_id,

        -- Order Context
        o.user_id,
        o.order_date,
        o.order_status,
        o.is_completed,
        o.is_cancelled,

        -- Product Context
        p.product_name,
        p.category,
        p.category_group,
        p.supplier_id,
        p.unit_cost,

        -- Line Item Details
        oi.quantity,
        oi.unit_price,
        oi.line_total as gross_amount,

        -- Unit Economics
        p.unit_cost * oi.quantity as total_cost,
        oi.line_total - (p.unit_cost * oi.quantity) as gross_profit,
        case
            when oi.line_total > 0
            then (oi.line_total - (p.unit_cost * oi.quantity)) / oi.line_total
            else 0
        end as gross_margin_pct,

        -- Return Information
        case when r.return_id is not null then true else false end as is_returned,
        r.return_id,
        r.return_date,
        r.return_reason,
        r.return_reason_category,
        r.is_quality_issue,
        coalesce(r.refund_amount, 0) as refund_amount,

        -- Net Revenue
        oi.line_total - coalesce(r.refund_amount, 0) as net_revenue,

        -- Metadata
        oi._loaded_at

    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    inner join products p on oi.product_id = p.product_id
    left join returns r on oi.order_item_id = r.order_item_id
)

select * from final

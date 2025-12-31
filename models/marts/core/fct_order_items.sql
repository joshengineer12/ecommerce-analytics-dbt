{{
    config(
        materialized='table'
    )
}}

/*
    Order Items Fact Table

    Grain: One row per order line item
    Materialization: Table (full refresh)

    This model provides line-item level analytics including:
    - Product and order context
    - Unit economics (price, cost, margin)
    - Return information

    Example Query:
    SELECT product_name, category, sum(gross_amount) as revenue,
           sum(case when is_returned then 1 else 0 end) as returns
    FROM fct_order_items
    GROUP BY 1, 2
    ORDER BY revenue DESC;
*/

with order_items as (
    select * from {{ ref('int_order_items_enriched') }}
),

final as (
    select
        -- Keys
        order_item_id,
        order_id,
        product_id,
        user_id as customer_id,
        order_date as order_date_id,

        -- Product Context
        product_name,
        category,
        category_group,
        supplier_id,

        -- Quantities
        quantity,
        unit_price,
        unit_cost,
        line_total as gross_amount,

        -- Profitability
        gross_profit,
        gross_margin_pct,

        -- Return Information
        is_returned,
        return_id,
        return_date,
        return_reason,
        return_reason_category,
        refund_amount,
        is_quality_issue,

        -- Net Revenue
        line_total - coalesce(refund_amount, 0) as net_revenue,

        -- Order Context
        order_status,
        is_completed,
        order_month,

        -- Metadata
        current_timestamp as _updated_at

    from order_items
    where is_completed = true  -- Only completed orders
)

select * from final

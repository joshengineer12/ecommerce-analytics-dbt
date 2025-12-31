{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        on_schema_change='sync_all_columns',
        post_hook=[
            "{{ log('fct_orders incremental load completed at ' ~ run_started_at, info=True) }}"
        ]
    )
}}

/*
    Incremental Order Fact Table

    This fact table provides order-level analytics including:
    - Order details and status
    - Customer and product dimensions
    - Return information

    Grain: One row per order

    INCREMENTAL STRATEGY:
    ---------------------
    Strategy: Merge on order_id
    - New orders are inserted
    - Existing orders are updated (handles status changes, returns added later)

    Why Incremental:
    - Order data grows continuously; full refresh becomes expensive at scale
    - Returns can be processed days after the original order
    - Status updates (e.g., completed → returned) need to be captured

    Late-Arriving Data Handling:
    - On incremental runs, we look back 3 days from the max date
    - This window captures: late order entries, status changes, return processing
    - Adjust the lookback window based on your data latency requirements

    Usage:
    - dbt run --select fct_orders                    (incremental)
    - dbt run --select fct_orders --full-refresh    (full reload)

    Example Query:
    SELECT order_id, order_date, customer_email, customer_segment, order_status,
           total_items, total_quantity, subtotal, is_returned, days_to_return
    FROM fct_orders
    WHERE is_returned = TRUE
    ORDER BY order_date DESC
    LIMIT 5;
*/

with orders as (
    select * from {{ ref('int_orders_enriched') }}

    {% if is_incremental() %}
        -- On incremental runs, only process recent orders
        -- Look back 3 days to capture late-arriving data and updates
        where order_date >= (select max(order_date) - interval '3 days' from {{ this }})
    {% endif %}
),

returns_info as (
    -- Get return information at order level
    select
        oi.order_id,
        min(r.return_date) as first_return_date,
        count(r.return_id) as return_count
    from {{ ref('stg_order_items') }} oi
    left join {{ ref('stg_returns') }} r on oi.order_item_id = r.order_item_id
    where r.return_id is not null
    group by 1
),

final as (
    select
        -- Keys
        o.order_id,
        o.user_id,
        o.order_date,

        -- Customer Context (matching expected output)
        o.email as customer_email,
        o.customer_segment,
        o.country,
        o.region,

        -- Order Status
        o.order_status,
        o.is_completed,
        o.is_cancelled,

        -- Order Composition (matching expected output)
        o.item_count as total_items,
        o.total_units as total_quantity,
        o.total_amount as subtotal,

        -- Return Information (matching expected output)
        case when o.has_returns then true else false end as is_returned,
        case
            when ri.first_return_date is not null
            then ri.first_return_date - o.order_date
            else null
        end as days_to_return,

        -- Additional Amounts
        o.total_refund_amount as refund_amount,
        o.net_revenue,
        o.total_gross_profit as gross_profit,

        -- Margins
        o.avg_gross_margin_pct,

        -- Flags
        o.is_high_value_order,
        case when o.item_count > 1 then true else false end as is_multi_item_order,

        -- Time Context
        o.order_month,
        o.order_week,
        o.day_of_week,

        -- Customer Tenure
        o.days_since_signup,

        -- Metadata
        current_timestamp as _updated_at

    from orders o
    left join returns_info ri on o.order_id = ri.order_id
)

select * from final

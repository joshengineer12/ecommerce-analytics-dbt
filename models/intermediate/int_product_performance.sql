{{
    config(
        materialized='view'
    )
}}

with order_items_enriched as (
    select * from {{ ref('int_order_items_enriched') }}
    where is_completed = true  -- Only completed orders
),

product_metrics as (
    select
        product_id,

        -- Sales Volume
        sum(quantity) as total_units_sold,
        count(distinct order_id) as order_count,
        count(distinct user_id) as unique_customers,

        -- Revenue
        sum(gross_amount) as total_revenue,
        sum(net_revenue) as net_revenue,
        avg(unit_price) as avg_selling_price,
        min(unit_price) as min_selling_price,
        max(unit_price) as max_selling_price,

        -- Profitability
        sum(gross_profit) as total_gross_profit,
        avg(gross_margin_pct) as avg_gross_margin_pct,

        -- Returns
        count(case when is_returned then 1 end) as return_count,
        sum(refund_amount) as total_refund_amount,
        count(case when is_quality_issue then 1 end) as quality_issue_count,

        -- Return Rate Calculation
        case
            when sum(quantity) > 0
            then count(case when is_returned then 1 end)::float / sum(quantity)
            else 0
        end as return_rate,

        -- Quality Issue Percentage
        case
            when count(case when is_returned then 1 end) > 0
            then count(case when is_quality_issue then 1 end)::float / count(case when is_returned then 1 end)
            else 0
        end as quality_issue_pct

    from order_items_enriched
    group by 1
)

select * from product_metrics

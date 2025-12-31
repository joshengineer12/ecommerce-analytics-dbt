{{
    config(
        materialized='table',
        post_hook=[
            "{{ log('mart_product_performance refreshed at ' ~ run_started_at, info=True) }}"
        ]
    )
}}

/*
    Product Performance Mart

    This mart provides product-level analytics including:
    - Sales volume and revenue
    - Return rates and quality metrics
    - Profitability analysis

    Grain: One row per product

    Example Query:
    SELECT product_id, product_name, category, total_quantity_sold,
           total_revenue, total_returns, return_rate, gross_profit, profit_margin
    FROM mart_product_performance
    WHERE return_rate > 0.10
    ORDER BY return_rate DESC;
*/

with products as (
    select * from {{ ref('stg_products') }}
),

product_performance as (
    select * from {{ ref('int_product_performance') }}
),

final as (
    select
        -- Product Identifiers
        p.product_id,
        p.product_name,
        p.category,
        p.category_group,
        p.supplier_id,

        -- Cost Information
        p.unit_cost,

        -- Sales Metrics (matching expected output)
        coalesce(pp.total_units_sold, 0) as total_quantity_sold,
        coalesce(pp.total_revenue, 0) as total_revenue,
        coalesce(pp.order_count, 0) as total_orders,
        coalesce(pp.unique_customers, 0) as unique_customers,

        -- Return Metrics (matching expected output)
        coalesce(pp.return_count, 0) as total_returns,
        coalesce(
            case
                when pp.total_units_sold > 0
                then pp.return_count::float / pp.total_units_sold
                else 0
            end,
            0
        ) as return_rate,

        -- Profitability (matching expected output)
        coalesce(pp.total_gross_profit, 0) as gross_profit,
        coalesce(
            case
                when pp.total_revenue > 0
                then pp.total_gross_profit / pp.total_revenue
                else 0
            end,
            0
        ) as profit_margin,

        -- Additional Metrics
        coalesce(pp.avg_selling_price, 0) as avg_selling_price,
        coalesce(pp.min_selling_price, 0) as min_selling_price,
        coalesce(pp.max_selling_price, 0) as max_selling_price,
        coalesce(pp.net_revenue, 0) as net_revenue,
        coalesce(pp.total_refund_amount, 0) as total_refund_amount,
        coalesce(pp.quality_issue_count, 0) as quality_issue_returns,

        -- Return Reason Breakdown (percentage of returns that are quality issues)
        coalesce(pp.quality_issue_pct, 0) as quality_issue_pct,

        -- Performance Classification
        case
            when pp.total_revenue >= 1000 and (pp.return_count::float / nullif(pp.total_units_sold, 0)) < 0.10 then 'Star'
            when pp.total_revenue >= 500 then 'Strong'
            when pp.total_revenue >= 100 then 'Average'
            when pp.total_revenue > 0 then 'Underperforming'
            else 'No Sales'
        end as performance_tier,

        -- Metadata
        current_timestamp as _updated_at

    from products p
    left join product_performance pp on p.product_id = pp.product_id
)

select * from final

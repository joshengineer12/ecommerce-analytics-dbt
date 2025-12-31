{{
    config(
        materialized='table'
    )
}}

with products as (
    select * from {{ ref('mart_product_performance') }}
),

order_items as (
    select * from {{ ref('fct_order_items') }}
),

monthly_product_metrics as (
    select
        product_id,
        order_month as month_id,

        -- Sales Volume
        count(distinct order_item_id) as items_sold,
        sum(quantity) as units_sold,
        count(distinct order_id) as order_count,
        count(distinct customer_id) as unique_customers,

        -- Revenue
        sum(gross_amount) as gross_revenue,
        sum(net_revenue) as net_revenue,

        -- Costs
        sum(unit_cost * quantity) as total_cost,

        -- Profitability
        sum(gross_profit) as gross_profit,
        avg(gross_margin_pct) as avg_margin_pct,

        -- Returns
        sum(case when is_returned then 1 else 0 end) as return_count,
        sum(coalesce(refund_amount, 0)) as refund_amount

    from order_items
    group by 1, 2
),

final as (
    select
        mpm.product_id,
        mpm.month_id,

        -- Product Context
        p.product_name,
        p.category,
        p.category_group,
        p.unit_cost,

        -- Volume Metrics
        mpm.items_sold,
        mpm.units_sold,
        mpm.order_count,
        mpm.unique_customers,

        -- Revenue Metrics
        mpm.gross_revenue,
        mpm.net_revenue,
        mpm.total_cost,

        -- Profitability
        mpm.gross_profit,
        mpm.avg_margin_pct,
        case
            when mpm.gross_revenue > 0 then
                (mpm.gross_profit / mpm.gross_revenue) * 100
            else 0
        end as net_margin_pct,

        -- Return Metrics
        mpm.return_count,
        mpm.refund_amount,
        case
            when mpm.items_sold > 0 then
                (mpm.return_count::float / mpm.items_sold) * 100
            else 0
        end as return_rate_pct,

        -- ROI
        case
            when mpm.total_cost > 0 then
                ((mpm.gross_revenue - mpm.total_cost) / mpm.total_cost) * 100
            else 0
        end as roi_pct,

        -- Metadata
        current_timestamp as _updated_at

    from monthly_product_metrics mpm
    left join products p on mpm.product_id = p.product_id
)

select * from final

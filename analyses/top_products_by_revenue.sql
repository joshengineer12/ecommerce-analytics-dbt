-- Top Products by Revenue Analysis
-- Identifies best-selling products with profitability metrics

select
    product_id,
    product_name,
    category,
    category_group,

    -- Sales Volume
    total_orders,
    total_quantity_sold,
    unique_customers,

    -- Revenue
    total_revenue,
    net_revenue,

    -- Profitability
    gross_profit,
    round(profit_margin * 100, 2) as profit_margin_pct,

    -- Performance
    performance_tier,

    -- Risk Indicators
    round(return_rate * 100, 2) as return_rate_pct,
    total_returns,

    -- Rankings
    row_number() over (order by net_revenue desc) as revenue_rank,
    row_number() over (order by gross_profit desc) as profit_rank,
    row_number() over (partition by category order by net_revenue desc) as category_revenue_rank

from {{ ref('mart_product_performance') }}
where total_revenue > 0
order by net_revenue desc
limit 20

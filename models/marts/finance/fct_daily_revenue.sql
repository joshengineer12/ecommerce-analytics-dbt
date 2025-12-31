{{
    config(
        materialized='table'
    )
}}

/*
    Daily Revenue Fact Table

    Grain: One row per day
    Materialization: Table (full refresh)

    This model aggregates order-level data to daily metrics including:
    - Revenue and profitability
    - Order counts and composition
    - Running totals and moving averages

    Why Table (not Incremental):
    - Daily aggregates result in a small table (~365 rows/year)
    - Window functions (cumulative totals, moving averages) require full dataset
    - Full refresh is fast and avoids complexity of maintaining window calculations

    Example Query:
    SELECT date_id, net_revenue, cumulative_revenue, revenue_7day_avg
    FROM fct_daily_revenue
    ORDER BY date_id DESC
    LIMIT 30;
*/

with orders as (
    select * from {{ ref('fct_orders') }}
),

daily_metrics as (
    select
        order_date as date_id,

        -- Order Counts
        count(distinct order_id) as order_count,
        count(distinct user_id) as unique_customers,

        -- Revenue Metrics
        sum(subtotal) as gross_revenue,
        sum(refund_amount) as total_refunds,
        sum(net_revenue) as net_revenue,

        -- Profitability
        sum(gross_profit) as gross_profit,
        avg(avg_gross_margin_pct) as avg_order_margin_pct,

        -- Order Composition
        sum(total_items) as total_items,
        sum(total_quantity) as total_units,
        avg(subtotal) as avg_order_value,

        -- High Value Orders
        count(distinct case when is_high_value_order then order_id end) as high_value_order_count,
        sum(case when is_high_value_order then subtotal else 0 end) as high_value_revenue,

        -- Returns
        count(distinct case when is_returned then order_id end) as orders_with_returns

    from orders
    group by 1
),

with_calculated_metrics as (
    select
        *,

        -- Calculated Metrics
        case
            when order_count > 0 then
                (high_value_order_count::float / order_count) * 100
            else 0
        end as high_value_order_pct,

        case
            when gross_revenue > 0 then
                (total_refunds / gross_revenue) * 100
            else 0
        end as refund_rate_pct

    from daily_metrics
),

final as (
    select
        date_id,
        order_count,
        unique_customers,
        gross_revenue,
        total_refunds,
        net_revenue,
        gross_profit,
        avg_order_margin_pct,
        total_items,
        total_units,
        avg_order_value,
        high_value_order_count,
        high_value_revenue,
        orders_with_returns,
        high_value_order_pct,
        refund_rate_pct,

        -- Running Totals
        sum(net_revenue) over (
            order by date_id
            rows between unbounded preceding and current row
        ) as cumulative_revenue,

        -- Moving Averages
        avg(net_revenue) over (
            order by date_id
            rows between 6 preceding and current row
        ) as revenue_7day_avg,

        -- Metadata
        current_timestamp as _updated_at

    from with_calculated_metrics
)

select * from final

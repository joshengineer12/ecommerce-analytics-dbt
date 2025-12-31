-- Customer Segmentation Summary
-- Analyzes customer base by RFM segments

with rfm_summary as (
    select
        rfm_customer_segment,
        recommended_action,
        count(*) as customer_count,
        round(avg(recency_days), 0) as avg_recency_days,
        round(avg(frequency), 1) as avg_orders,
        round(avg(monetary), 2) as avg_revenue,
        round(sum(monetary), 2) as total_revenue
    from {{ ref('fct_rfm_analysis') }}
    group by 1, 2
),

totals as (
    select
        sum(customer_count) as total_customers,
        sum(total_revenue) as grand_total_revenue
    from rfm_summary
)

select
    rs.rfm_customer_segment,
    rs.customer_count,
    round((rs.customer_count::float / t.total_customers) * 100, 2) as pct_of_customers,
    rs.avg_recency_days,
    rs.avg_orders,
    rs.avg_revenue,
    rs.total_revenue,
    round((rs.total_revenue / t.grand_total_revenue) * 100, 2) as pct_of_revenue,
    rs.recommended_action
from rfm_summary rs
cross join totals t
order by rs.total_revenue desc

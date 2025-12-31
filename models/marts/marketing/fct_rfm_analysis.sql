{{
    config(
        materialized='table'
    )
}}

/*
RFM Analysis (Recency, Frequency, Monetary)
A powerful customer segmentation technique for marketing
*/

with customers as (
    select * from {{ ref('dim_customers') }}
    where total_orders > 0  -- Only customers with purchases
),

rfm_base as (
    select
        customer_id,
        email,
        country,
        region,
        customer_segment,

        -- Recency: Days since last order (lower is better)
        {{ datediff('last_order_date', 'current_date', 'day') }} as recency_days,

        -- Frequency: Number of orders (higher is better)
        total_orders as frequency,

        -- Monetary: Total revenue (higher is better)
        total_revenue as monetary

    from customers
),

rfm_scores as (
    select
        *,

        -- Score each dimension 1-5 using ntile
        ntile(5) over (order by recency_days desc) as recency_score,
        ntile(5) over (order by frequency) as frequency_score,
        ntile(5) over (order by monetary) as monetary_score

    from rfm_base
),

final as (
    select
        customer_id,
        email,
        country,
        region,
        customer_segment,

        -- Raw Metrics
        recency_days,
        frequency,
        monetary,

        -- RFM Scores
        recency_score,
        frequency_score,
        monetary_score,

        -- Combined RFM Score
        recency_score + frequency_score + monetary_score as rfm_total_score,

        -- RFM Segment String
        recency_score::text || frequency_score::text || monetary_score::text as rfm_segment,

        -- Customer Segment Based on RFM
        case
            when recency_score >= 4 and frequency_score >= 4 and monetary_score >= 4 then 'Champions'
            when recency_score >= 4 and frequency_score >= 3 then 'Loyal Customers'
            when recency_score >= 4 and frequency_score <= 2 then 'New Customers'
            when recency_score >= 3 and frequency_score >= 3 and monetary_score >= 3 then 'Potential Loyalists'
            when recency_score >= 3 and monetary_score >= 4 then 'Big Spenders'
            when recency_score <= 2 and frequency_score >= 4 then 'At Risk'
            when recency_score <= 2 and frequency_score >= 2 then 'Hibernating'
            when recency_score <= 2 and frequency_score <= 2 then 'Lost'
            else 'Other'
        end as rfm_customer_segment,

        -- Recommended Actions
        case
            when recency_score >= 4 and frequency_score >= 4 then 'Reward them, make them brand advocates'
            when recency_score >= 4 and frequency_score >= 3 then 'Upsell higher value products'
            when recency_score >= 4 and frequency_score <= 2 then 'Build relationship, offer onboarding'
            when recency_score >= 3 and frequency_score >= 3 then 'Offer membership/loyalty program'
            when recency_score <= 2 and frequency_score >= 4 then 'Send personalized reactivation campaigns'
            when recency_score <= 2 and frequency_score >= 2 then 'Offer comeback promotions'
            when recency_score <= 2 and frequency_score <= 2 then 'Revive interest with aggressive offers'
            else 'Monitor and engage'
        end as recommended_action,

        -- Metadata
        current_timestamp as _updated_at

    from rfm_scores
)

select * from final

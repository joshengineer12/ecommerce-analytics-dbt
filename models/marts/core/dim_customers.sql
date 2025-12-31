{{
    config(
        materialized='table',
        post_hook=[
            "{{ log('dim_customers refreshed with ' ~ this ~ ' at ' ~ run_started_at, info=True) }}"
        ]
    )
}}

/*
    Customer Dimension

    This dimension provides customer-level analytics including:
    - Lifetime metrics (orders, revenue)
    - Behavioral segmentation
    - Activity status and recency

    Grain: One row per customer

    Example Query:
    SELECT customer_id, email, customer_segment, total_orders, total_revenue,
           avg_order_value, first_order_date, last_order_date, days_since_last_order
    FROM dim_customers
    WHERE customer_segment = 'Premium'
    ORDER BY total_revenue DESC
    LIMIT 10;
*/

with users as (
    select * from {{ ref('stg_users') }}
),

customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

final as (
    select
        -- Customer Identifiers (matching expected output)
        u.user_id as customer_id,
        u.email,
        u.customer_segment,  -- matches expected output column name

        -- Demographics
        u.country,
        u.region,
        u.signup_date,

        -- Order Metrics (matching expected output)
        coalesce(co.completed_orders, 0) as total_orders,
        coalesce(co.total_revenue, 0) as total_revenue,
        coalesce(co.avg_order_value, 0) as avg_order_value,

        -- Date Metrics (matching expected output)
        co.first_order_date,
        co.last_order_date,
        case
            when co.last_order_date is not null
            then current_date - co.last_order_date
            else null
        end as days_since_last_order,

        -- Additional Metrics
        coalesce(co.total_orders, 0) as lifetime_orders,
        coalesce(co.cancelled_orders, 0) as cancelled_orders,
        coalesce(co.total_net_revenue, 0) as total_net_revenue,
        coalesce(co.total_gross_profit, 0) as total_gross_profit,
        coalesce(co.avg_items_per_order, 0) as avg_items_per_order,

        -- Return Behavior
        coalesce(co.total_returned_items, 0) as total_returned_items,
        coalesce(co.total_refunds, 0) as total_refunds,
        coalesce(co.orders_with_returns, 0) as orders_with_returns,

        -- Derived Customer Tier (based on behavior)
        case
            when co.total_revenue >= 500 and co.completed_orders >= 3 then 'VIP'
            when co.total_revenue >= 200 or co.completed_orders >= 2 then 'Loyal'
            when co.completed_orders >= 1 then 'Active'
            else 'New'
        end as customer_tier,

        -- Activity Status
        case
            when co.first_order_date is null then 'Never Ordered'
            when co.last_order_date >= current_date - interval '30 days' then 'Active'
            when co.last_order_date >= current_date - interval '90 days' then 'At Risk'
            else 'Churned'
        end as activity_status,

        -- Customer Tenure
        {{ datediff('u.signup_date', 'current_date', 'day') }} as days_as_customer,

        -- Flags
        case when co.completed_orders > 1 then true else false end as is_repeat_customer,

        -- Metadata
        current_timestamp as _updated_at

    from users u
    left join customer_orders co on u.user_id = co.user_id
)

select * from final

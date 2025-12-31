with source as (
    select * from {{ ref('raw_orders') }}
),

renamed as (
    select
        -- Primary Key
        order_id,

        -- Foreign Key
        user_id,

        -- Order Information
        order_date,
        status as order_status,
        total_amount,

        -- Derived Fields
        case
            when status = 'completed' then true
            else false
        end as is_completed,

        case
            when status = 'cancelled' then true
            else false
        end as is_cancelled,

        case
            when total_amount >= {{ var('high_value_order_threshold') }} then true
            else false
        end as is_high_value_order,

        -- Date Parts (useful for aggregations)
        {{ date_trunc('month', 'order_date') }} as order_month,
        {{ date_trunc('week', 'order_date') }} as order_week,
        extract(dow from order_date) as day_of_week,

        -- Metadata
        current_timestamp as _loaded_at

    from source
)

select * from renamed

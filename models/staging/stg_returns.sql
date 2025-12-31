with source as (
    select * from {{ ref('raw_returns') }}
),

renamed as (
    select
        -- Primary Key
        return_id,

        -- Foreign Key
        order_item_id,

        -- Return Information
        return_date,
        return_reason,
        refund_amount,

        -- Categorized Return Reasons
        case
            when return_reason in ('defective', 'damaged_shipping') then 'Quality Issue'
            when return_reason = 'wrong_item' then 'Fulfillment Error'
            when return_reason = 'changed_mind' then 'Customer Decision'
            else 'Other'
        end as return_reason_category,

        -- Is it a quality-related return?
        case
            when return_reason in ('defective', 'damaged_shipping') then true
            else false
        end as is_quality_issue,

        -- Date Parts
        {{ date_trunc('month', 'return_date') }} as return_month,

        -- Metadata
        current_timestamp as _loaded_at

    from source
)

select * from renamed

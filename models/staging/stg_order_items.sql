with source as (
    select * from {{ ref('raw_order_items') }}
),

renamed as (
    select
        -- Primary Key
        order_item_id,

        -- Foreign Keys
        order_id,
        product_id,

        -- Item Details
        quantity,
        price as unit_price,

        -- Calculated Fields
        quantity * price as line_total,

        -- Metadata
        current_timestamp as _loaded_at

    from source
)

select * from renamed

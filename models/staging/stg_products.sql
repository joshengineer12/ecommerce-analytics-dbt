with source as (
    select * from {{ ref('raw_products') }}
),

renamed as (
    select
        -- Primary Key
        product_id,

        -- Product Information
        product_name,
        category,

        -- Supplier Information
        supplier_id,

        -- Financial Information
        cost as unit_cost,

        -- Derived Fields
        case
            when category = 'Electronics' then 'Tech'
            when category = 'Furniture' then 'Home & Office'
            when category = 'Office' then 'Home & Office'
            when category = 'Home' then 'Home & Office'
            else 'Other'
        end as category_group,

        -- Metadata
        current_timestamp as _loaded_at

    from source
)

select * from renamed

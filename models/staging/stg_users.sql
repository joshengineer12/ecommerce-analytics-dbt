with source as (
    select * from {{ ref('raw_users') }}
),

renamed as (
    select
        -- Primary Key
        user_id,

        -- User Information
        email,
        {{ extract_email_domain('email') }} as email_domain,

        -- Dates
        signup_date,

        -- Geographic Information
        country,
        {{ get_region('country') }} as region,

        -- Customer Classification
        customer_segment,

        -- Metadata
        current_timestamp as _loaded_at

    from source
)

select * from renamed

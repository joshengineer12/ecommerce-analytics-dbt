{{
    config(
        materialized='table'
    )
}}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('start_date') ~ "' as date)",
        end_date="cast('" ~ var('end_date') ~ "' as date)"
    ) }}
),

final as (
    select
        -- Date Key
        date_day as date_id,

        -- Date Parts
        extract(year from date_day) as year,
        extract(month from date_day) as month,
        extract(day from date_day) as day,
        extract(quarter from date_day) as quarter,
        extract(week from date_day) as week_of_year,
        extract(dow from date_day) as day_of_week,
        extract(doy from date_day) as day_of_year,

        -- Date Names
        strftime(date_day, '%B') as month_name,
        strftime(date_day, '%b') as month_short,
        strftime(date_day, '%A') as day_name,
        strftime(date_day, '%a') as day_short,

        -- Period Keys
        strftime(date_day, '%Y-%m') as year_month,
        strftime(date_day, '%Y-Q') || extract(quarter from date_day) as year_quarter,

        -- Week Boundaries
        date_trunc('week', date_day)::date as week_start_date,
        (date_trunc('week', date_day) + interval '6 days')::date as week_end_date,

        -- Month Boundaries
        date_trunc('month', date_day)::date as month_start_date,
        (date_trunc('month', date_day) + interval '1 month' - interval '1 day')::date as month_end_date,

        -- Quarter Boundaries
        date_trunc('quarter', date_day)::date as quarter_start_date,
        (date_trunc('quarter', date_day) + interval '3 months' - interval '1 day')::date as quarter_end_date,

        -- Flags
        case when extract(dow from date_day) in (0, 6) then true else false end as is_weekend,
        case when extract(dow from date_day) between 1 and 5 then true else false end as is_weekday,

        -- Relative Date Flags (useful for filtering)
        case when date_day = current_date then true else false end as is_today,
        case when date_day = current_date - interval '1 day' then true else false end as is_yesterday,
        case
            when date_day between date_trunc('month', current_date) and current_date then true
            else false
        end as is_current_month,
        case
            when date_day between date_trunc('quarter', current_date) and current_date then true
            else false
        end as is_current_quarter

    from date_spine
)

select * from final

{% snapshot snap_customers %}

{{
    config(
        target_schema='snapshots',
        unique_key='user_id',
        strategy='check',
        check_cols=['customer_segment', 'country'],
        invalidate_hard_deletes=True
    )
}}

/*
    Customer Snapshot
    Tracks changes to customer segment and country over time.
    Useful for historical analysis of customer migration between segments.

    Usage:
        - Run `dbt snapshot` to capture current state
        - Query with dbt_valid_from and dbt_valid_to for point-in-time analysis
*/

select
    user_id,
    email,
    signup_date,
    country,
    customer_segment,
    current_timestamp as _snapshot_at
from {{ ref('raw_users') }}

{% endsnapshot %}

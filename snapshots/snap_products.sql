{% snapshot snap_products %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='check',
        check_cols=['cost', 'category'],
        invalidate_hard_deletes=True
    )
}}

/*
    Product Snapshot
    Tracks changes to product cost and category over time.
    Essential for accurate historical margin calculations.

    Usage:
        - Run `dbt snapshot` to capture current state
        - Join with order data using valid_from/valid_to for accurate cost at time of sale
*/

select
    product_id,
    product_name,
    category,
    supplier_id,
    cost,
    current_timestamp as _snapshot_at
from {{ ref('raw_products') }}

{% endsnapshot %}

{% macro generate_surrogate_key(columns) %}
    {#-
    Generates a surrogate key from multiple columns using MD5 hash.

    Args:
        columns: List of column names to combine into a key

    Returns:
        MD5 hash of concatenated column values

    Example:
        {{ generate_surrogate_key(['order_id', 'product_id']) }}
    -#}

    md5(
        {%- for column in columns %}
            coalesce(cast({{ column }} as varchar), '_null_')
            {%- if not loop.last %} || '|' || {% endif %}
        {%- endfor %}
    )

{% endmacro %}

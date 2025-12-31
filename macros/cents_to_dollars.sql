{% macro cents_to_dollars(column_name, precision=2) %}
    {#-
    Converts cents to dollars.

    Args:
        column_name: The column containing amount in cents
        precision: Number of decimal places (default 2)

    Returns:
        Amount in dollars

    Example:
        {{ cents_to_dollars('amount_cents') }}
    -#}

    round({{ column_name }}::numeric / 100, {{ precision }})

{% endmacro %}


{% macro dollars_to_cents(column_name) %}
    {#-
    Converts dollars to cents.

    Args:
        column_name: The column containing amount in dollars

    Returns:
        Amount in cents as integer

    Example:
        {{ dollars_to_cents('amount_dollars') }}
    -#}

    round({{ column_name }}::numeric * 100)::integer

{% endmacro %}

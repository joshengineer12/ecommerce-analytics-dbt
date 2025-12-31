{% macro date_trunc(datepart, date_column) %}
    {#-
    Truncates a date to the specified precision.
    Cross-database compatible implementation.

    Args:
        datepart: The part to truncate to (day, week, month, quarter, year)
        date_column: The column containing the date

    Returns:
        Truncated date

    Example:
        {{ date_trunc('month', 'order_date') }}
    -#}

    date_trunc('{{ datepart }}', {{ date_column }})::date

{% endmacro %}

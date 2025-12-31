{% macro datediff(start_date, end_date, datepart) %}
    {#-
    Calculates the difference between two dates.
    Cross-database compatible implementation.

    Args:
        start_date: The start date column or expression
        end_date: The end date column or expression
        datepart: The unit to measure difference in (day, week, month, year)

    Returns:
        Integer difference in the specified unit

    Example:
        {{ datediff('signup_date', 'order_date', 'day') }}
    -#}

    {% if datepart == 'day' %}
        ({{ end_date }}::date - {{ start_date }}::date)
    {% elif datepart == 'week' %}
        (({{ end_date }}::date - {{ start_date }}::date) / 7)
    {% elif datepart == 'month' %}
        (extract(year from {{ end_date }}) * 12 + extract(month from {{ end_date }}))
        - (extract(year from {{ start_date }}) * 12 + extract(month from {{ start_date }}))
    {% elif datepart == 'year' %}
        extract(year from {{ end_date }}) - extract(year from {{ start_date }})
    {% else %}
        {{ exceptions.raise_compiler_error("Invalid datepart: " ~ datepart) }}
    {% endif %}

{% endmacro %}

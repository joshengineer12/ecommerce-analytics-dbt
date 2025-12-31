{% macro safe_divide(numerator, denominator, default=0) %}
    {#-
    Performs safe division, returning a default value when denominator is zero or null.

    Args:
        numerator: The numerator expression
        denominator: The denominator expression
        default: Value to return when division is not possible (default 0)

    Returns:
        Result of division or default value

    Example:
        {{ safe_divide('total_refunds', 'total_revenue') }}
        {{ safe_divide('returns', 'orders', default='null') }}
    -#}

    case
        when {{ denominator }} is null or {{ denominator }} = 0 then {{ default }}
        else {{ numerator }}::float / {{ denominator }}::float
    end

{% endmacro %}

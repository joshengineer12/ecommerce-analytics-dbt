{% macro get_region(country_column) %}
    {#-
    Maps country codes to geographic regions.

    Args:
        country_column: The column containing country names

    Returns:
        Geographic region name

    Example:
        {{ get_region('country') }}
    -#}

    case
        when {{ country_column }} in ('USA', 'Canada') then 'North America'
        when {{ country_column }} in ('UK') then 'Europe'
        when {{ country_column }} in ('Australia') then 'Asia Pacific'
        else 'Other'
    end

{% endmacro %}

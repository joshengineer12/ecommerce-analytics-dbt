{% macro extract_email_domain(email_column) %}
    {#-
    Extracts the domain from an email address.

    Args:
        email_column: The column containing email addresses

    Returns:
        The domain portion of the email (everything after @)

    Example:
        {{ extract_email_domain('email') }}
        -- Returns: 'gmail.com' for 'user@gmail.com'
    -#}

    {% set extract_domain %}
        split_part({{ email_column }}, '@', 2)
    {% endset %}

    {{ return(extract_domain) }}

{% endmacro %}

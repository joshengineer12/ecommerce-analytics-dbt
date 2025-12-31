{% macro grant_select_on_schemas(schemas, role) %}
    {#-
    Grants SELECT permission on all tables in specified schemas to a role.
    Useful as a post-hook for managing access.

    Args:
        schemas: List of schema names
        role: Role to grant access to

    Example:
        {{ grant_select_on_schemas(['marts', 'staging'], 'analyst_role') }}
    -#}

    {% for schema in schemas %}
        grant usage on schema {{ schema }} to {{ role }};
        grant select on all tables in schema {{ schema }} to {{ role }};
    {% endfor %}

{% endmacro %}


{% macro grant_select(role) %}
    {#-
    Grants SELECT on the current model to a specified role.
    Use as a post-hook on models.

    Args:
        role: Role to grant access to

    Example in dbt_project.yml:
        models:
          +post-hook:
            - "{{ grant_select('analyst_role') }}"
    -#}

    grant select on {{ this }} to {{ role }}

{% endmacro %}

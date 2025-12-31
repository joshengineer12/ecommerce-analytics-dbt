{% test positive_value(model, column_name, allow_zero=true) %}
{#-
Tests that all values in a column are positive (or optionally zero).

Args:
    model: The model to test
    column_name: The column to check
    allow_zero: Whether zero is acceptable (default true)

Example:
    - positive_value:
        allow_zero: false
-#}

select *
from {{ model }}
where {{ column_name }} is not null
{% if allow_zero %}
  and {{ column_name }} < 0
{% else %}
  and {{ column_name }} <= 0
{% endif %}

{% endtest %}

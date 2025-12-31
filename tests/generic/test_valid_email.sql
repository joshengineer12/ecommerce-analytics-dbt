{% test valid_email(model, column_name) %}
{#-
Tests that all values in a column are valid email format.

Args:
    model: The model to test
    column_name: The column containing email addresses

Example:
    - valid_email
-#}

select *
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} not like '%@%.%'

{% endtest %}

{% test date_not_in_future(model, column_name) %}
{#-
Tests that date values are not in the future.

Args:
    model: The model to test
    column_name: The column containing dates

Example:
    - date_not_in_future
-#}

select *
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} > current_date

{% endtest %}

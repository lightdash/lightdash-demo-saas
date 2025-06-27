{% macro date_add_cross_db(date_column, days) %}
  {% if target.type == 'postgres' %}
    {{ date_column }} + interval '{{ days }} days'
  {% elif target.type == 'bigquery' %}
    date_add({{ date_column }}, interval {{ days }} day)
  {% else %}
    {{ date_column }} + interval {{ days }} day
  {% endif %}
{% endmacro %}
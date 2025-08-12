{% macro date_add_cross_db(date_column, days) %}
  {% if target.type == 'postgres' %}
    {{ date_column }} + interval '{{ days }} days'
  {% elif target.type == 'bigquery' %}
    date_add({{ date_column }}, interval {{ days }} day)
  {% elif target.type == 'snowflake' %}
    dateadd(day, {{ days }}, {{ date_column }})
  {% else %}
    {{ exceptions.raise_compiler_error("Unsupported database type: " ~ target.type) }}
  {% endif %}
{% endmacro %}
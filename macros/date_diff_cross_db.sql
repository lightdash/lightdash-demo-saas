{% macro date_diff_cross_db(end_date, start_date, unit) %}
  {% if target.type == 'bigquery' %}
    date_diff({{ end_date }}, {{ start_date }}, {{ unit }})
  {% elif target.type == 'postgres' %}
    extract(epoch from ({{ end_date }} - {{ start_date }})) / 86400
  {% elif target.type == 'snowflake' %}
    datediff({{ unit }}, {{ start_date }}, {{ end_date }})
  {% else %}
    {{ exceptions.raise_compiler_error("Unsupported database type: " ~ target.type) }}
  {% endif %}
{% endmacro %}
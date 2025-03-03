{% macro shift_date(date_col, max_tstamp = '2024-12-31 00:00:00') %}
  timestamp_add(
    {{ date_col }},
    interval timestamp_diff(current_timestamp(), timestamp '{{ max_tstamp }}', second) second
  )
{% endmacro %}
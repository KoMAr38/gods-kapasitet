{# Liten erstatning for dbt_utils.unique_combination_of_columns, uten pakkeavhengighet. #}
{% test dbt_utils_lite_unique_combination(model, kolonner) %}
select {{ kolonner }}, count(*) as n
from {{ model }}
group by {{ kolonner }}
having count(*) > 1
{% endtest %}

{% macro payload_hash(columns) -%}
    {% if target.type == 'snowflake' %}
        md5(to_json(array_construct({{ columns | join(', ') }})))
    {% else %}
        md5(to_json(list_value({{ columns | join(', ') }})))
    {% endif %}
{%- endmacro %}

{% test no_conflicting_payloads(model, key_columns, payload_columns) %}
    select {{ key_columns | join(', ') }}
    from {{ model }}
    group by {{ key_columns | join(', ') }}
    having count(distinct {{ payload_hash(payload_columns) }}) > 1
{% endtest %}

{% test expression_is_true(model, expression) %}
    select * from {{ model }} where not ({{ expression }}) or ({{ expression }}) is null
{% endtest %}

{% test unique_combination(model, columns) %}
    select {{ columns | join(', ') }} from {{ model }}
    group by {{ columns | join(', ') }} having count(*) > 1
{% endtest %}

{% macro add_days(days, expression) -%}
    {% if target.type == 'snowflake' %}
        dateadd(day, {{ days }}, {{ expression }})
    {% else %}
        ({{ expression }} + interval '1 day' * {{ days }})
    {% endif %}
{%- endmacro %}

{% macro analysis_cutoff() -%}
    cast('{{ var("analysis_cutoff") }}' as date)
{%- endmacro %}

{% macro strict_integer(expression) -%}
    case when
    {% if target.type == 'snowflake' %}
        regexp_like({{ expression }}, '[+-]?[0-9]+')
    {% else %}
        regexp_full_match({{ expression }}, '[+-]?[0-9]+')
    {% endif %}
    then try_cast({{ expression }} as integer) end
{%- endmacro %}

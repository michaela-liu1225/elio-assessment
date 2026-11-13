-- review_id alone is not unique: preserve the publisher's order/review pair.
-- Free text stays in restricted RAW, outside the analytical marts.
with deduplicated as (
    select * from {{ source('olist', 'reviews') }}
    qualify row_number() over (
        partition by order_id, review_id
        order by _loaded_at desc, _file_sha256 desc, _source_row_number desc
    ) = 1
), typed as (
    select
        nullif(trim(order_id), '') as order_id,
        nullif(trim(review_id), '') as review_id,
        {{ strict_integer("nullif(trim(review_score), '')") }} as review_score,
        try_cast(nullif(trim(review_creation_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) as review_created_at,
        try_cast(nullif(trim(review_answer_timestamp), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) as review_answered_at,
        _source, _source_row_number, _loaded_at, _file_sha256,
        ((nullif(trim(review_score), '') is not null and {{ strict_integer("nullif(trim(review_score), '')") }} is null)
         or (nullif(trim(review_creation_date), '') is not null and try_cast(nullif(trim(review_creation_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) is null)
         or (nullif(trim(review_answer_timestamp), '') is not null and try_cast(nullif(trim(review_answer_timestamp), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) is null)) as _has_parse_error
    from deduplicated
)
select * from typed

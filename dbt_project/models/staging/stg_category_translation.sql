-- Preserve nullable business fields; fail malformed non-empty values via tests.
with deduplicated as (
    select * from {{ source('olist', 'category_translation') }}
    qualify row_number() over (
        partition by product_category_name
        order by _loaded_at desc, _file_sha256 desc, _source_row_number desc
    ) = 1
)
select
    nullif(trim(product_category_name), '') as category_name,
    nullif(trim(product_category_name_english), '') as category_name_english,
    _source,
    _source_row_number,
    _loaded_at,
    _file_sha256,
    (false) as _has_parse_error
from deduplicated

-- Preserve nullable business fields; fail malformed non-empty values via tests.
with deduplicated as (
    select * from {{ source('olist', 'products') }}
    qualify row_number() over (
        partition by product_id
        order by _loaded_at desc, _file_sha256 desc, _source_row_number desc
    ) = 1
)
select
    nullif(trim(product_id), '') as product_id,
    nullif(trim(product_category_name), '') as category_name,
    try_cast(nullif(trim(product_name_lenght), '') as integer) as name_length,
    try_cast(nullif(trim(product_description_lenght), '') as integer) as description_length,
    try_cast(nullif(trim(product_photos_qty), '') as integer) as photo_count,
    try_cast(nullif(trim(product_weight_g), '') as integer) as weight_g,
    try_cast(nullif(trim(product_length_cm), '') as integer) as length_cm,
    try_cast(nullif(trim(product_height_cm), '') as integer) as height_cm,
    try_cast(nullif(trim(product_width_cm), '') as integer) as width_cm,
    _source,
    _source_row_number,
    _loaded_at,
    _file_sha256,
    ((nullif(trim(product_name_lenght), '') is not null and try_cast(nullif(trim(product_name_lenght), '') as integer) is null) or (nullif(trim(product_description_lenght), '') is not null and try_cast(nullif(trim(product_description_lenght), '') as integer) is null) or (nullif(trim(product_photos_qty), '') is not null and try_cast(nullif(trim(product_photos_qty), '') as integer) is null) or (nullif(trim(product_weight_g), '') is not null and try_cast(nullif(trim(product_weight_g), '') as integer) is null) or (nullif(trim(product_length_cm), '') is not null and try_cast(nullif(trim(product_length_cm), '') as integer) is null) or (nullif(trim(product_height_cm), '') is not null and try_cast(nullif(trim(product_height_cm), '') as integer) is null) or (nullif(trim(product_width_cm), '') is not null and try_cast(nullif(trim(product_width_cm), '') as integer) is null)) as _has_parse_error
from deduplicated

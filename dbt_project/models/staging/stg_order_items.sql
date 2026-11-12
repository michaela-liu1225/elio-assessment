-- Preserve nullable business fields; fail malformed non-empty values via tests.
with deduplicated as (
    select * from {{ source('olist', 'order_items') }}
    qualify row_number() over (
        partition by order_id, order_item_id
        order by _loaded_at desc, _file_sha256 desc, _source_row_number desc
    ) = 1
)
select
    nullif(trim(order_id), '') as order_id,
    try_cast(nullif(trim(order_item_id), '') as integer) as order_item_id,
    nullif(trim(product_id), '') as product_id,
    nullif(trim(seller_id), '') as seller_id,
    try_cast(nullif(trim(shipping_limit_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) as shipping_limit_at,
    try_cast(nullif(trim(price), '') as decimal(18,2)) as price,
    try_cast(nullif(trim(freight_value), '') as decimal(18,2)) as freight_value,
    _source,
    _source_row_number,
    _loaded_at,
    _file_sha256,
    ((nullif(trim(order_item_id), '') is not null and try_cast(nullif(trim(order_item_id), '') as integer) is null) or (nullif(trim(shipping_limit_date), '') is not null and try_cast(nullif(trim(shipping_limit_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) is null) or (nullif(trim(price), '') is not null and try_cast(nullif(trim(price), '') as decimal(18,2)) is null) or (nullif(trim(freight_value), '') is not null and try_cast(nullif(trim(freight_value), '') as decimal(18,2)) is null)) as _has_parse_error
from deduplicated

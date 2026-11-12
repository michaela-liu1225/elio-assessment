-- Preserve nullable business fields; fail malformed non-empty values via tests.
with deduplicated as (
    select * from {{ source('olist', 'orders') }}
    qualify row_number() over (
        partition by order_id
        order by _loaded_at desc, _file_sha256 desc, _source_row_number desc
    ) = 1
)
select
    nullif(trim(order_id), '') as order_id,
    nullif(trim(customer_id), '') as customer_id,
    nullif(trim(order_status), '') as order_status,
    try_cast(nullif(trim(order_purchase_timestamp), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) as purchased_at,
    try_cast(nullif(trim(order_approved_at), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) as approved_at,
    try_cast(nullif(trim(order_delivered_carrier_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) as carrier_received_at,
    try_cast(nullif(trim(order_delivered_customer_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) as delivered_at,
    try_cast(nullif(trim(order_estimated_delivery_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) as estimated_delivery_at,
    _source,
    _source_row_number,
    _loaded_at,
    _file_sha256,
    ((nullif(trim(order_purchase_timestamp), '') is not null and try_cast(nullif(trim(order_purchase_timestamp), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) is null)
        or (nullif(trim(order_approved_at), '') is not null and try_cast(nullif(trim(order_approved_at), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) is null)
        or (nullif(trim(order_delivered_carrier_date), '') is not null and try_cast(nullif(trim(order_delivered_carrier_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) is null)
        or (nullif(trim(order_delivered_customer_date), '') is not null and try_cast(nullif(trim(order_delivered_customer_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) is null)
        or (nullif(trim(order_estimated_delivery_date), '') is not null and try_cast(nullif(trim(order_estimated_delivery_date), '') as {{ 'timestamp_ntz' if target.type == 'snowflake' else 'timestamp' }}) is null)) as _has_parse_error
from deduplicated

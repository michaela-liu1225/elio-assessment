-- Preserve nullable business fields; fail malformed non-empty values via tests.
with deduplicated as (
    select * from {{ source('olist', 'customers') }}
    qualify row_number() over (
        partition by customer_id
        order by _loaded_at desc, _file_sha256 desc, _source_row_number desc
    ) = 1
)
select
    nullif(trim(customer_id), '') as customer_id,
    nullif(trim(customer_unique_id), '') as customer_unique_id,
    case when length(nullif(trim(customer_zip_code_prefix), '')) <= 5 then lpad(nullif(trim(customer_zip_code_prefix), ''), 5, '0') end as zip_code_prefix,
    lower(nullif(trim(customer_city), '')) as city,
    upper(nullif(trim(customer_state), '')) as state,
    _source,
    _source_row_number,
    _loaded_at,
    _file_sha256,
    ((nullif(trim(customer_zip_code_prefix), '') is not null and length(nullif(trim(customer_zip_code_prefix), '')) > 5)) as _has_parse_error
from deduplicated

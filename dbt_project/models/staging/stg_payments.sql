-- Preserve nullable business fields; fail malformed non-empty values via tests.
with deduplicated as (
    select * from {{ source('olist', 'payments') }}
    qualify row_number() over (
        partition by order_id, payment_sequential
        order by _loaded_at desc, _file_sha256 desc, _source_row_number desc
    ) = 1
)
select
    nullif(trim(order_id), '') as order_id,
    {{ strict_integer("nullif(trim(payment_sequential), '')") }} as payment_sequence,
    nullif(trim(payment_type), '') as payment_type,
    {{ strict_integer("nullif(trim(payment_installments), '')") }} as installment_count,
    try_cast(nullif(trim(payment_value), '') as decimal(18,2)) as payment_value,
    _source,
    _source_row_number,
    _loaded_at,
    _file_sha256,
    ((nullif(trim(payment_sequential), '') is not null and {{ strict_integer("nullif(trim(payment_sequential), '')") }} is null)
        or (nullif(trim(payment_installments), '') is not null and {{ strict_integer("nullif(trim(payment_installments), '')") }} is null)
        or (nullif(trim(payment_value), '') is not null and try_cast(nullif(trim(payment_value), '') as decimal(18,2)) is null)) as _has_parse_error
from deduplicated

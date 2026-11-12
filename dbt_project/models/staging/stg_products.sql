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
    {{ strict_integer("nullif(trim(product_name_lenght), '')") }} as name_length,
    {{ strict_integer("nullif(trim(product_description_lenght), '')") }} as description_length,
    {{ strict_integer("nullif(trim(product_photos_qty), '')") }} as photo_count,
    {{ strict_integer("nullif(trim(product_weight_g), '')") }} as weight_g,
    {{ strict_integer("nullif(trim(product_length_cm), '')") }} as length_cm,
    {{ strict_integer("nullif(trim(product_height_cm), '')") }} as height_cm,
    {{ strict_integer("nullif(trim(product_width_cm), '')") }} as width_cm,
    _source,
    _source_row_number,
    _loaded_at,
    _file_sha256,
    ((nullif(trim(product_name_lenght), '') is not null and {{ strict_integer("nullif(trim(product_name_lenght), '')") }} is null)
        or (nullif(trim(product_description_lenght), '') is not null and {{ strict_integer("nullif(trim(product_description_lenght), '')") }} is null)
        or (nullif(trim(product_photos_qty), '') is not null and {{ strict_integer("nullif(trim(product_photos_qty), '')") }} is null)
        or (nullif(trim(product_weight_g), '') is not null and {{ strict_integer("nullif(trim(product_weight_g), '')") }} is null)
        or (nullif(trim(product_length_cm), '') is not null and {{ strict_integer("nullif(trim(product_length_cm), '')") }} is null)
        or (nullif(trim(product_height_cm), '') is not null and {{ strict_integer("nullif(trim(product_height_cm), '')") }} is null)
        or (nullif(trim(product_width_cm), '') is not null and {{ strict_integer("nullif(trim(product_width_cm), '')") }} is null)) as _has_parse_error
from deduplicated

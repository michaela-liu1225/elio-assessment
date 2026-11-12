-- customer_id identifies the source order/customer context, not a person.
select customer_id, customer_unique_id, zip_code_prefix, city, state
from {{ ref('stg_customers') }}

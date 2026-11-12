-- Stable observed buyer identity, separated from per-order delivery context.
select distinct customer_unique_id
from {{ ref('stg_customers') }}

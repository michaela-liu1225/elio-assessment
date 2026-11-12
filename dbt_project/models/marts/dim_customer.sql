select
    md5('customer|' || customer_unique_id) as customer_sk,
    customer_unique_id
from {{ ref('int_customers') }}

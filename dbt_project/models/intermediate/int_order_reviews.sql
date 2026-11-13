-- One order, one primary score. Never join all review rows onto order GMV.
-- First response avoids selecting a favourable later revision; latest is sensitivity only.
with observed as (
    select *,
        count(*) over (partition by order_id) as review_record_count,
        first_value(review_score) over (
            partition by order_id order by review_answered_at desc, review_id desc
            rows between unbounded preceding and unbounded following
        ) as latest_review_score
    from {{ ref('stg_reviews') }}
    where cast(review_answered_at as date) <= {{ analysis_cutoff() }}
      and review_answered_at >= review_created_at
)
select order_id, review_id as first_review_id,
       review_score as first_review_score, review_answered_at as first_review_answered_at,
       latest_review_score, review_record_count
from observed
qualify row_number() over (
    partition by order_id order by review_answered_at, review_id
) = 1

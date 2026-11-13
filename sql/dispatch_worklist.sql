-- Reference integration query, NOT a live feed or a historical eligibility replay.
-- Replace the timestamp with a bound scheduler parameter and refresh the source first.
-- Current status / event freshness / cancellation / prior-action checks must be atomic
-- in the operational system immediately before notifying a seller.
with run_context as (
    select to_timestamp_ntz('2018-08-31 00:00:00') as as_of_at
)
select r.order_id, r.seller_id, r.shipping_deadline_at, r.estimated_delivery_date,
       'confirm carrier pickup; escalate only if unresolved' as proposed_action
from ELIO_ASSESSMENT.DEV_MARTS.MART_DELIVERY_RISK r
cross join run_context c
where r.has_valid_dispatch_context
  and r.order_status in ('approved', 'invoiced', 'processing')
  and r.approved_at <= c.as_of_at
  and r.carrier_received_at is null and r.delivered_at is null
  and r.trigger_at <= c.as_of_at
  and r.trigger_at > dateadd(day, -2, c.as_of_at) -- do not replay stale backlog
  and dateadd(day, 2, cast(c.as_of_at as date)) <= r.estimated_delivery_date
order by r.estimated_delivery_date, r.order_id;

-- Historical landmark reconstruction, NOT an as-of status/event log or a causal backtest.
-- Trigger inputs are separate from delivery/review outcomes. Single-seller only:
-- the source has one carrier timestamp per order, not one per seller/parcel.
with item_context as (
    select order_id, count(*) as source_item_count,
           count(shipping_limit_at) as items_with_deadline,
           count(seller_id) as items_with_seller,
           count(distinct seller_id) as seller_count,
           min(seller_id) as seller_id,
           min(shipping_limit_at) as shipping_deadline_at
    from {{ ref('stg_order_items') }}
    group by order_id
), landmarks as (
    select o.*, i.source_item_count, i.items_with_deadline, i.items_with_seller,
           i.seller_count, i.seller_id, i.shipping_deadline_at,
           {{ add_days(1, 'i.shipping_deadline_at') }} as trigger_at
    from {{ ref('fct_orders') }} o
    left join item_context i on o.order_id = i.order_id
), eligibility as (
    select *,
        coalesce(seller_count = 1 and source_item_count = items_with_deadline
            and source_item_count = items_with_seller
            and approved_at >= purchased_at and approved_at <= trigger_at
            and shipping_deadline_at >= purchased_at
            and (carrier_received_at is null or carrier_received_at >= purchased_at)
            and {{ add_days(2, 'cast(trigger_at as date)') }} <= estimated_delivery_date,
            false) as has_valid_dispatch_context,
        coalesce(trigger_at is not null
            and (carrier_received_at is null or carrier_received_at > trigger_at)
            and (delivered_at is null or delivered_at > trigger_at), false) as awaiting_handoff_at_trigger
    from landmarks
)
select e.order_id, e.seller_id, e.seller_count, e.delivery_state,
       e.order_status, e.purchased_at, e.purchase_date, e.approved_at,
       e.shipping_deadline_at, e.trigger_at, cast(e.trigger_at as date) as trigger_date,
       e.estimated_delivery_date, e.carrier_received_at, e.delivered_at,
       e.merchandise_gmv, e.has_valid_dispatch_context, e.awaiting_handoff_at_trigger,
       e.has_valid_dispatch_context and e.awaiting_handoff_at_trigger as is_historical_alert,
       coalesce({{ add_days(30, 'e.estimated_delivery_date') }} <= {{ analysis_cutoff() }}, false) as has_mature_delivery_window,
       coalesce(e.is_delivered and e.delivered_at >= e.purchased_at
           and cast(e.delivered_at as date) <= {{ analysis_cutoff() }}, false) as observed_delivered_by_cutoff,
       e.is_late,
       case when e.has_valid_dispatch_context and e.awaiting_handoff_at_trigger
                 and {{ add_days(2, 'e.trigger_at') }} < {{ add_days(1, analysis_cutoff()) }}
            then coalesce(e.carrier_received_at > e.trigger_at
                 and e.carrier_received_at <= {{ add_days(2, 'e.trigger_at') }}, false)
       end as handed_over_next_48h,
       r.first_review_score, r.latest_review_score, r.first_review_answered_at,
       coalesce(r.review_record_count, 0) as review_record_count,
       case when r.first_review_answered_at is not null and e.delivered_at is not null
            then r.first_review_answered_at < e.delivered_at end as review_before_delivery,
       {{ analysis_cutoff() }} as analysis_cutoff
from eligibility e
left join {{ ref('int_order_reviews') }} r on e.order_id = r.order_id

# Part C: productionisation discussion

## Implemented

The assessment implements content-hash ingestion audits, atomic per-file loads, serial reruns, row/amount reconciliation, stable keys, exact-duplicate collapse and conflict/parse failure gates. Target-derived schemas isolate dbt outputs, dependencies are pinned, and X-Small/60-second auto-suspend defaults limit unnecessary trial usage.

## Environments and CI

Separate production/development databases and roles. Give CI read-only RAW access, warehouse usage and write access only to its per-PR namespaces (`CI_12_STAGING`, `CI_12_CONFORMED`, `CI_12_MARTS`). `SYSADMIN` is a trial bootstrap convenience, not a production service identity.

A GitHub Actions job should check out a trusted PR, install pinned dependencies, authenticate with protected key-pair credentials or workload identity, run `dbt deps` and `dbt build --target ci`, and publish results. Never expose secrets to arbitrary fork code. Gate deployment on the actual Snowflake result; a green local-only check is insufficient. Zero-copy clones can provide realistic isolated input after account support and grants are verified. Track schema ownership and clean up expired PR environments through controlled maintenance.

This is a design discussion, not a claim that a cloud CI workflow executed. No Snowflake credentials have been uploaded to GitHub.

## Incremental loading and history

The static extract lacks reliable source `updated_at` or CDC. A purchase-date watermark would miss a later delivery/cancellation on an older order. Production should consume authoritative changes, deduplicate each incoming batch to one record per merge key, and update affected orders/items/payments. A bounded lookback is only a compromise requiring reconciliation and backfills; `unique_key` alone does not prove input uniqueness.

Snapshots can track genuine subsequent changes once a repeatable source exists. Do not manufacture historical SCD2 changes from one extract. Order-time addresses already remain on their contexts/facts and should not be replaced by the customer's latest address.

## Cost and operations

Start with X-Small, 60-second auto-suspend and query tags. The verified Snowflake build took 42.62 seconds; this is client-reported build elapsed time, not billable warehouse time or a credit estimate. Obtain actual credit usage from metering history before making a cost claim. Inspect query profiles, bytes scanned, join cardinality, spilling and queueing before resizing. Views plus small persisted marts are adequate at this scale; clustering needs evidence.

Orchestration should validate the source batch, load serially, build/test marts, reconcile totals and publish a complete version. Preserve the last validated version if a release fails. Derive live freshness rules from source delivery schedules, not from 2018 purchase dates; `_loaded_at` measures arrival, not source recency. Monitor changes in exception rates and confirm finance/consent inputs before activating a campaign.

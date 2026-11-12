# Ingestion decisions and manual steps

`dataset.py` specifies six exact files and headers. Before any warehouse write, the loader checks UTF-8 (including an optional BOM), CSV quoting and exact record widths. Portuguese text is preserved. The category-translation file has a UTF-8 BOM, handled by the parser/file format rather than by modifying source files.

Recorded counts and SHA-256 hashes are in `docs/source_manifest.json`: 99,441 orders, 112,650 items, 99,441 customer contexts, 32,951 products, 103,886 payments and 71 translations. Preflight found no structurally malformed record in these six files. This does not mean their business values are all complete or consistent.

## Snowflake operations

1. Optionally create the named database and X-Small warehouse (`--bootstrap`), leaving existing objects intact.
2. Create `DATABASE.RAW.OLIST_CSV`, `DATABASE.RAW.OLIST_STAGE` and explicit raw tables.
3. `PUT` unchanged files into checksum-specific stage directories.
4. `COPY INTO` with `METADATA$FILENAME`, `METADATA$FILE_ROW_NUMBER`, `METADATA$START_SCAN_TIME` and the source SHA-256.
5. Reconcile row count to preflight, then commit data and the audit record together. Successful COPY results are stored in ignored `data/load_report_snowflake.json`.

Business fields stay `VARCHAR` in RAW; staging explicitly converts analytical types. Empty fields remain empty strings in RAW. File format: UTF-8, optional double-quote enclosure, no backslash escape, one header record, BOM skipping, no silent invalid-character replacement, and errors on width mismatches.

## Failure and validation policy

`ON_ERROR=ABORT_STATEMENT` prevents silently skipped orders from biasing analysis. Preflight identifies structural errors by file/record; COPY errors roll back that file, leaving no success audit. Earlier successfully committed files are skipped on retry. Investigate failures instead of switching to `CONTINUE` just to produce a green build.

Metadata-enriching COPY uses a SELECT. Snowflake's `VALIDATION_MODE` and `VALIDATE` do not support transformed COPY, so this loader does not combine incompatible options. Additional server-side validation can use a separate untransformed validation COPY into a temporary table containing only original VARCHAR columns; otherwise inspect the failed COPY diagnostic. See [Snowflake COPY documentation](https://docs.snowflake.com/en/sql-reference/sql/copy-into-table).

## Rerun boundary

`RAW.LOAD_AUDIT` tracks logical table and source hash; a second check counts raw rows carrying that hash. A fully committed matching file is skipped; partial/inconsistent states raise an error. The stage is retained, `FORCE=TRUE` is avoided, and correctness does not rely only on Snowflake's expiring file-load memory.

This is a serial single-writer batch loader. Concurrent runs require orchestration/locking; an unenforced unique constraint is not a lock. Changed snapshots may generate conflicting business-key payloads and deliberately fail dbt. Last-write-wins/CDC needs an authoritative business update timestamp, not merely a newer ingestion time.

## Manual steps and execution evidence

The owner completes trial activation and authentication. Configure the README's environment variables and ignored profile; no credential belongs in source. All six files were loaded successfully on Snowflake; COPY results, actual build/query IDs and rerun evidence are recorded in `docs/evidence/`. See `docs/verification.md` for the exact verified scope.

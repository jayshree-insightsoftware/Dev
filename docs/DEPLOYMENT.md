# Deployment Architecture

The production architecture pattern. Based on lessons from the ARR Intelligence Dashboard project. Apply unless there's a specific reason not to.

## The pattern

```
GitHub Actions (cron, every N hours, + after every deploy)
  → Runs node jobs/snapshot.js against the warehouse
  → Reads from mart layer (NOT raw or staging)
  → Writes to local snapshot_staging.db (SQLite)
  → Atomic rename to snapshot.db
  → Uploads to Azure Blob Storage container 'snapshots'
       ↓
Azure App Service (on startup + every 30 min)
  → blobSync.downloadIfNewer() compares blob lastModified vs local mtime
  → Downloads to snapshot_staging.db
  → Atomic rename to snapshot.db, reloadDb() refreshes SQLite connection
       ↓
Express API reads from local SQLite (which mirrors the mart layer)
       ↓
Frontend (React, Vue, whatever)
```

## Why this pattern

The warehouse is the source of truth but is slow to query and has connection limits. The app needs millisecond responses and high concurrency. SQLite local cache solves both.

The snapshot job runs in GitHub Actions, not on the App Service. App Service has network proxy timeouts and other constraints that make long-running Snowflake streams unreliable. GitHub Actions runs in a clean Linux environment with no such constraints.

The staging/swap pattern (write to `_staging.db`, atomic rename) means the app never sees a half-written database. Old data continues to serve until the swap completes.

Blob Storage as the handoff between GitHub Actions and the App Service avoids requiring direct network access between them. Both write/read to the same blob, with the blob's last-modified timestamp serving as the freshness signal.

## Azure setup

App Service: Linux, Node 22 LTS (or current LTS at project start), startup command `node server.js`

Required environment variables on App Service:
- NODE_ENV=production
- DATA_DIR=/home/data (must include leading slash -- this was a real bug we hit)
- AZURE_STORAGE_CONNECTION_STRING
- PORT=8080 (or whatever the app uses)
- Any frontend build-time env vars (e.g., VITE_*) -- set as GitHub Actions repo variables

Storage Account: contains a private container called `snapshots` holding `snapshot.db`. The connection string from Access Keys key1 goes in BOTH Azure App Service env vars AND GitHub Actions secrets. Both must be identical -- mismatched connection strings (different storage accounts) is a common cause of "blob downloaded but app sees nothing".

GitHub Actions secrets:
- AZURE_STORAGE_CONNECTION_STRING (same as App Service)
- Warehouse credentials (SNOWFLAKE_ACCOUNT, USERNAME, PASSWORD, WAREHOUSE, DATABASE, etc.)
- Azure Service Principal credentials for the deploy step (AZUREAPPSERVICE_CLIENTID_*, TENANTID_*, SUBSCRIPTIONID_*)

After production is stable, remove warehouse credentials from App Service env vars. App Service should have no business knowing them -- it reads from blob, not directly from the warehouse.

## Workflow files

`.github/workflows/test.yml` -- triggered on push to dev. Runs tests only, never deploys.

`.github/workflows/deploy.yml` -- triggered on push to main. Builds, deploys to App Service. Final step auto-triggers snapshot.yml so fresh data follows fresh code.

`.github/workflows/snapshot.yml` -- triggered on cron (every 4 hours) and workflow_dispatch (manual + auto-trigger from deploy). Runs the snapshot job against the warehouse and uploads to Blob Storage.

Templates for all three are in `.github/workflows/` of this repo. Customize the specifics (timeouts, cron schedules, warehouse-specific env vars) when setting up a new project.

## Gotchas we learned the hard way

DATA_DIR must include a leading slash. `/home/data` works; `home/data` resolves relative to the working directory and silently fails.

The download step must complete BEFORE initDb() opens the SQLite connection. If initDb() opens first, the atomic rename fails because the live file is locked.

Periodic sync intervals shouldn't be too aggressive. 30 minutes is a good default. The cost of a stale 30-minute snapshot is much lower than the cost of churning through downloads.

Windows local dev can't always swap files cleanly (the dev server holds the file handle). The snapshot job should handle this gracefully: detect the lock, defer the swap, leave instructions for the user to complete it manually after stopping the dev server. Don't error -- the data is safe in `_staging.db`.

Connection strings between GitHub Actions and App Service must be byte-identical. If they point to different storage accounts, the upload succeeds but the download sees an empty container.

## When to deviate from this pattern

If the dataset is small enough that the app could just hit the warehouse directly with reasonable latency, skip the blob storage layer. The hybrid pattern adds complexity that's only justified for larger datasets or higher query volumes.

If the warehouse already provides a fast caching layer (e.g., Snowflake Search Optimization, materialized views), evaluate whether direct queries are fast enough. Sometimes they are.

If the app needs writes back to the warehouse (not just reads), this pattern doesn't fit and you need a different architecture entirely.

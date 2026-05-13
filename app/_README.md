# Application Layer

Empty by design. This folder is populated in Phase 4 of the project, when the mart layer has stabilized.

## Principles when you build the app

The app is thin. It reads marts. It does not compute business logic.

Every query the app runs against marts should be a SELECT with filtering, ordering, and pagination. No SUM, no GROUP BY, no CASE statements that encode business rules. If you need aggregation in the app, that aggregation belongs in a mart.

Define a typed schema (TypeScript types, Zod schemas, etc.) for every mart's row shape. Queries are typed. Schema drift is caught at compile time.

Period logic comes from `date_dim` joins, not JavaScript date arithmetic.

Reuse the deployment pattern in `docs/DEPLOYMENT.md` unless there's a specific reason not to.

## Stack choices to make at Phase 4

Frontend framework (React, Vue, Svelte, etc.)
Backend framework (Express, Fastify, Hono, etc.)
ORM or query builder (or raw SQL, which is fine for thin apps)
Hosting target (Azure App Service is the established pattern, but evaluate per project)
Authentication if needed

## Suggested folder structure (when you start)

```
app/
  backend/
    routes/         -- thin API endpoints, one per mart or per concept
    db/             -- SQLite connection, schema reload logic
    services/       -- if needed; should be minimal
    tests/
  frontend/
    src/
      pages/
      components/
      utils/
      styles/
    tests/
```

If the eventual stack matches the ARR Intelligence Dashboard project closely (Node + React + SQLite snapshot cache), copying that project's `backend/` and `frontend/` structure as a starting point is reasonable. Strip out the project-specific bits and customize.

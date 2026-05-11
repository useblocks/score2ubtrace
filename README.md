# score2ubtrace

Nightly orchestrator that mirrors [`eclipse-score/score`](https://github.com/eclipse-score/score) documentation to [ubTrace](https://team.useblocks.com).

See `docs/superpowers/specs/` (gitignored) for the full design.

## Operator setup

1. Create a repo secret `UBTRACE_INGEST_TOKEN` with Ingest permissions on `team.useblocks.com`.
2. Workflow runs nightly at 02:00 UTC; trigger manually from the Actions tab via **Run workflow** (input `ref` defaults to `main`).

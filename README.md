# score2ubtrace

Nightly orchestrator that publishes [`eclipse-score/score`](https://github.com/eclipse-score/score) documentation to the ubTrace instance at [team.useblocks.com](https://team.useblocks.com).

## What the workflow does

The GitHub Actions workflow at `.github/workflows/nightly-ubtrace.yml` runs at **02:00 UTC** nightly and on `workflow_dispatch`. For each matrix ref (currently `main` plus tags strictly newer than `v0.5.5`):

1. Checks out the orchestrator and `eclipse-score/score@<ref>` side-by-side.
2. Installs Graphviz, Bazel, Python 3.12, and `uv`.
3. Runs `bazel run //:ide_support` from inside the score checkout. This is score's own upstream target — it materializes `score/.venv_docs/` (with all `score_docs_as_code` extensions + transitive Python deps) and `score/bazel-bin/ide_support.runfiles/` (where `score_plantuml` looks for the plantuml jar). No patches to score's `MODULE.bazel`.
4. Uses `uv pip install --target ubt-overlay --extra-index-url=https://pypi.useblocks.com/ --index-strategy unsafe-best-match ubt-sphinx` to fetch the [`ubt-sphinx`](https://pypi.useblocks.com/) builder (which is on the useblocks PyPI, not pypi.org) into a sibling overlay directory.
5. Applies `patches/score-main-conf.py.patch` to score's `docs/conf.py` to load the `ubt_sphinx` extension and set `ubtrace_organization = "eclipse-score"` and `ubtrace_project = "score"`.
6. Runs `python3.12 -m sphinx -b ubtrace ...` with `PYTHONPATH` stitched as `<.venv_docs/lib/python3.12/site-packages>:<ubt-overlay>` so both the Bazel-managed extensions and ubt-sphinx are importable.
7. `bash upload.sh` tars `score/docs/_build/ubtrace/eclipse-score/score/<ref>/` and POSTs it to `https://api.team.useblocks.com/api/v1/ingest/eclipse-score/score/<ref>?overwrite=true`.

## Operator setup

1. Add a repo secret named **`UBTRACE_INGEST_TOKEN`** with `Ingest` permission on the `eclipse-score/score` project at `team.useblocks.com`.
2. The schedule runs nightly. To trigger manually: **Actions → *Nightly ubTrace publish* → Run workflow**. The `ref` input defaults to `main` and overrides the matrix for that run.

## Why the unusual stitching

`ubt-sphinx` is published only on `https://pypi.useblocks.com/`, which is uv-native and not a PEP 503 simple index. Bazel's `pip.parse` uses pip and can't resolve from it. So we let Bazel build the normal docs venv (which already has everything else `score_sphinx_bundle` needs, including the bazel-managed plantuml runfiles), and layer ubt-sphinx on top via `uv pip install --target`. Running Sphinx through system `python3.12` (not the Bazel-wrapped launcher in `.venv_docs/bin/python`, which needs runfiles env to bootstrap) keeps both trees on `PYTHONPATH` without venv-detection issues.

## Bumping the docs-as-code pin

The workflow uses whatever version of `score_docs_as_code` upstream `eclipse-score/score@main` (or the tag) currently pins — no override. When upstream bumps, you don't need to touch this orchestrator.

## Raising the tag cutoff

Edit `TAG_MIN` at the top of `.github/workflows/nightly-ubtrace.yml`. The bats tests in `scripts/tests/list-refs.bats` lock down the semantics: matched tags must be strictly newer than `TAG_MIN` (semver-aware — pre-releases of the cutoff like `v0.5.5-rc.1` are excluded).

## Local tests

```bash
brew install bats-core shellcheck actionlint
bats scripts/tests/list-refs.bats
shellcheck scripts/list-refs.sh upload.sh scripts/tests/stubs/gh
actionlint .github/workflows/nightly-ubtrace.yml
```

## Future deletion

When upstream `eclipse-score/docs-as-code` adopts `ubt-sphinx` as a direct dependency and score's `conf.py` loads it, delete `patches/score-main-conf.py.patch`, drop the `Install ubt-sphinx ...` and `Apply score conf.py patch` workflow steps, and trim `PYTHONPATH` to just `<.venv_docs/lib/python3.12/site-packages>`.

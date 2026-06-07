# Eval Scorers (v1)

x-qa's eval class tests non-deterministic LLM features. Instead of asserting equality,
it **scores** outputs with an LLM judge and gates on an N-sample pass-rate — and refuses
to let an *unvalidated* judge block a run.

## Scorers (v1)
- `llm-rubric` — judge scores the output 0–1 against `criteria`. `threshold` is the per-sample bar.
- `semantic-similarity` — judge rates 0–1 equivalence of the output to `reference`.

(Deferred to v2+: RAG metrics, agentic/trajectory + tool-correctness, jury, agent-as-judge,
embedding-backed similarity. See `docs/research/2026-06-06-*-eval-*.md`.)

## The cascade (suite-level)
Cost control is at the suite level: cheap deterministic HTTP cases (status/jsonpath/regex)
run on the HTTP runner; expensive judge cases run on the judge-runner. In v1 a case is either
deterministic OR eval — not both (within-case "run judge only if deterministic asserts pass"
is deferred to v2). Keep judge `samples` small (default 3) to bound cost.

## N-sample verdict
Each eval assertion is scored `samples` times (default 3, temp 0). `pass-rate.sh` computes
`pass_rate = passes / N`; `raw_pass` requires `pass_rate ≥ X_QA_MIN_PASS_RATE` (default 1.0).

## Meta-evaluation κ-gate (mandatory)
A judge may set a hard `fail` ONLY if it has been validated against a human gold set:
- gold set: `.x-skills/x-qa/kb/evals/gold/<rubric_id>.jsonl`
- calibrate: `/x-skills:x-qa kb eval-calibrate --rubric-id <id>` → `kb/evals/calibration/<rubric_id>.json`
- bands (`meta-gate.sh`): κ ≥ 0.90 → may fail · 0.85 ≤ κ < 0.90 → advisory(warn) · κ < 0.85 or uncalibrated → advisory(warn)

Calibration is honored only when its `judge_model` matches the runner's judge model.

## Anti-circularity & anti-bias
- The judge model SHOULD differ from the model behind the system-under-test (operator
  responsibility — x-qa drives an HTTP endpoint and cannot infer or enforce the SUT model in v1).
- x-qa generates cases AND scores them — keep the case-minting model ≠ judge model; ground both
  in the code/domain-model (the scout already does code-first domain research).
- Candidate output is untrusted input to the judge (injection-guarded rubric prompt).

## Result eval block
`score-case.sh` writes a CaseResult whose `eval` block carries: `kind`, `rubric_id`, `samples`,
`passes`, `pass_rate`, `mean_score`, `threshold`, `scores[]`, `kappa`, `advisory`, `uncalibrated`,
`reason`. On an infrastructure error (SUT/judge command failure) the case is a hard `fail` with
`{eval:{kind,error}}` and `attempts:0` — infra failures are never downgraded to advisory.

## Scripts
`scripts/evals/{pass-rate,cohens-kappa,meta-gate,score-case,calibrate-judge}.sh` — all
read JSON/flags, emit JSON, and isolate the LLM call behind `X_QA_JUDGE_CMD` for testability.

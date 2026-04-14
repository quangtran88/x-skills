# Mode B: Deep Investigation

For ambiguous, causal, multi-component bugs where the root cause isn't obvious from the stack trace. Uses competing hypotheses to avoid anchoring on the first plausible explanation.

## When to Use

- Bug is intermittent or timing-dependent
- No clear stack trace pointing to a single origin
- Symptom spans multiple modules or services
- Previous fix attempts haven't resolved the issue

## Phase 1: Frame the Problem

1. **Restate the observation exactly** — what was actually observed vs. expected
2. **Generate 3 competing hypotheses** — deliberately different explanations:
   - **Lane 1:** Code-path / implementation cause
   - **Lane 2:** Config / environment / orchestration cause
   - **Lane 3:** Measurement / artifact / assumption mismatch cause
3. Present hypotheses to user for confirmation before proceeding

## Phase 2: Parallel Evidence Collection

Dispatch OMC `tracer` agents or investigate lanes sequentially.

For EACH hypothesis lane, gather:
- **Evidence for** — what supports this explanation
- **Evidence against** — what contradicts it or is still missing
- **Evidence strength** — rank per `evidence-hierarchy.md`
- **Critical unknown** — the missing fact that would confirm or eliminate this lane

## Phase 3: Synthesis & Ranking

1. **Rank hypotheses** by evidence strength
2. **Cross-check lenses** — pressure-test the leading hypothesis with these lenses when relevant:
   - **Systems lens:** queues, retries, backpressure, feedback loops, upstream/downstream dependencies, boundary failures
   - **Premortem lens:** assume the current best explanation is wrong — what failure mode would embarrass this conclusion later?
   - **Science lens:** controls, confounders, measurement bias, alternative variables, falsifiable predictions
3. **Run a rebuttal** — let the strongest non-leading lane challenge the leader with evidence
4. **Check convergence** — if two hypotheses reduce to the same root mechanism, merge them
5. **Identify the discriminating probe** — the single cheapest test that would collapse uncertainty

Present ranked findings:
- Leading hypothesis is high-confidence → proceed to fix (SKILL.md Phase: Fix & Verify)
- Still uncertain → propose the discriminating probe to the user

## Phase 4: Fix & Verify

Same as Mode A (SKILL.md), but include the evidence trail in the debug report — which hypotheses were tested, which were eliminated, and what evidence confirmed the root cause.

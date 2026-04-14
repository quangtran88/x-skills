# Synthesis Rules

After collecting agent results, **verify before presenting** to the user.

## Verify Findings (MANDATORY)

Before synthesizing, spot-check key claims from each agent:

1. **File paths** — if an agent references a file, confirm it exists (`Glob` or `Read`)
2. **Code claims** — if an agent says "function X does Y", read the function and confirm
3. **External claims** — if an agent cites a library feature or API, verify it's current (not hallucinated from training data)
4. **Drop false positives** — discard any finding that doesn't survive verification
5. **Flag unverifiable claims** — if you can't check it (e.g., external URL), mark it as `[unverified]`

If >30% of an agent's findings fail verification, note this — its results are unreliable for this query.

**Type B exception:** For external docs research where the agent performed web research, the agent's results are the primary source. Explicit re-verification is optional — flag only claims that seem implausible or contradict known facts.

## Evidence Tiering

Rank evidence by source reliability before synthesizing:

| Tier | Source | Verification Need |
|------|--------|-------------------|
| **1 (Authoritative)** | context7 API docs, official documentation | Low — authoritative by definition |
| **2 (AI-Synthesized)** | deepwiki answers, perplexity_reason analysis | Medium — cross-check key claims |
| **3 (Agent Synthesis)** | OMO librarian/explore/oracle output | Medium — spot-check file paths and code claims |
| **4 (Web Content)** | exa results, perplexity_ask summaries, raw web | High — verify currency and accuracy |

When agents and MCP tools disagree, prefer higher-tier evidence. When same-tier sources conflict, present both for user decision.

## Verification Gate (MANDATORY before presenting findings)

Before claiming any finding is proven or complete:

1. **Identify** — What would verify this claim? (file exists, function works as described, API returns expected shape)
2. **Check** — Spot-check at least the highest-impact claims (read the file, grep for the function, confirm the URL)
3. **Confirm** — Does evidence support the claim?
4. **Only then** — Present the finding WITH the evidence

**Red flags — stop before claiming:**
- Using "should", "probably", "seems to" for key findings
- Trusting agent output without spot-checking file paths or code claims
- Presenting MCP tool output as verified without reading it
- Claiming synthesis is complete without checking against original question

## Then Synthesize

1. **Lead with the answer** — state the conclusion first, not the process
2. **Cite evidence** — reference specific files, URLs, code snippets from the response
3. **Flag uncertainty** — if the agent hedged or contradicted itself, note it
4. **Identify gaps** — if the research didn't fully answer the question, say what's missing
5. **Suggest next steps** — "Want me to dig deeper into X?" or "Ready to implement?"
6. **Never dump raw output** — always synthesize into a clear summary

## Attribute Agent Contributions (MANDATORY)

If background agents were dispatched, the final synthesis MUST attribute what each agent actually added — even when their findings overlap with your own direct reads.

- **Name the agent, name the contribution.** "deepwiki agent confirmed the contract-first architecture and surfaced the RRF fusion detail in hybrid search." Not just "agents confirmed the above."
- **Banned phrasing:** "No additional information beyond what I already reported" / "findings are already incorporated" / "agents confirmed the same thing." These are red flags that you either (a) didn't actually read the agent output carefully, or (b) dispatched an agent you didn't need. Either case is a finding to note.
- **If an agent genuinely added nothing new**, say so explicitly AND note that dispatching it was unnecessary — that's a signal to recalibrate depth next time: "deepwiki agent duplicated direct reads; should have tried morph first per Type E ladder."
- **Decision rule:** If you can't write a single concrete sentence attributing what an agent contributed, you didn't read its output — go back and read it before presenting synthesis.

## Include Negative Findings

When research evaluates patterns, approaches, or tools that were deliberately rejected, present them with reasons. This prevents "why didn't you consider X?" follow-ups and documents the decision boundary.

Format: a brief table or list of what was considered, why it was skipped, and what would change the decision.

## When Agents Disagree

If parallel agents return contradictory findings (e.g., explore shows one pattern, librarian recommends another):
- Present both perspectives clearly
- Note which has stronger evidence
- Flag for user decision — don't silently pick one

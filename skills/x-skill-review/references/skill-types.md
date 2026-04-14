# Skill Types

From Anthropic's official skill categorization. The best skills fit cleanly into one type. Skills that straddle multiple types are often confusing — consider splitting them.

## 1. Library & API Reference
Explains how to correctly use a library, CLI, or SDK. Includes reference code snippets and gotcha lists.
**Examples:** billing-lib, internal-platform-cli, frontend-design

## 2. Product Verification
Describes how to test or verify code is working. Often paired with playwright, tmux, or other verification tools. Includes scripts for programmatic assertions.
**Examples:** signup-flow-driver, checkout-verifier, tmux-cli-driver

## 3. Data Fetching & Analysis
Connects to data and monitoring stacks. Includes helper libraries, dashboard IDs, credentials, and common query workflows.
**Examples:** funnel-query, cohort-compare, grafana

## 4. Business Process & Team Automation
Automates repetitive workflows into one command. May depend on other skills or MCPs. Benefits from storing previous results in log files.
**Examples:** standup-post, create-ticket, weekly-recap

## 5. Code Scaffolding & Templates
Generates framework boilerplate for specific codebase functions. May include composable scripts. Useful when scaffolding has natural language requirements.
**Examples:** new-workflow, new-migration, create-app

## 6. Code Quality & Review
Enforces code quality and reviews code. Can include deterministic scripts/tools. May run via hooks or in CI.
**Examples:** adversarial-review, code-style, testing-practices

## 7. CI/CD & Deployment
Helps fetch, push, and deploy code. May reference other skills for data collection.
**Examples:** babysit-pr, deploy-service, cherry-pick-prod

## 8. Runbooks
Takes a symptom (alert, error, Slack thread) and walks through multi-tool investigation to produce a structured report.
**Examples:** service-debugging, oncall-runner, log-correlator

## 9. Infrastructure Operations
Performs routine maintenance and operational procedures. May involve destructive actions that benefit from guardrails.
**Examples:** resource-orphans, dependency-management, cost-investigation

## Classification Tips

- If a skill *orchestrates other skills*, it's likely type 4 (Business Process).
- If a skill *generates files*, it's likely type 5 (Scaffolding).
- If a skill *reads code and produces findings*, it's likely type 6 (Quality/Review).
- If a skill *connects to external services for data*, it's likely type 3 (Data Fetching).
- A skill that does "a little of everything" should probably be split.

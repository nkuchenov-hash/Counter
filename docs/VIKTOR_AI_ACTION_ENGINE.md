# Viktor — LIFE OS AI action assistant (implementation contract)

Status: **Phase A contract only (not an enabled user feature).** Created 2026-10-17.
Executor model for this scoped architectural foundation: **GPT-5.6 Terra**.
All production code, subscription billing, hosted inference, BYOK, ChatGPT
integration and voice UI remain unimplemented until integrated and tested.
This document is not authorization to deploy an incomplete feature.

## Goal

Viktor (the raven) is the single assistant identity across Life OS voice,
text, and future external chat integrations. The AI **must never write
application source code** or receive arbitrary filesystem, SQL, network or
PocketBase admin access. It selects named application capabilities; trusted
Life OS code executes only allowlisted operations.

User scenarios:

- "Plan today: exercises, breakfast, shower, walk with grandma, walk in the
  centre; RCC in the evening." Read current plans and fixed commitments,
  generate a non-overlapping preview, resolve omitted durations from saved
  preferences, then request confirmation of a multi-item schedule.
- "Change exercise from 40 to 30 minutes and put breakfast right after it."
  Resolve unique plan IDs first; check original duration, enforce category
  time rules and cascade, preview resulting changes, then execute through
  the existing Brain and retain undo.
- "Start walking" and "Stop the running record." Use current record
  services, singleton start/stop invariants, and offline outboxes.

## Existing code and ownership

- Smart Plan UI: `lib/features/planning/smart_plan_sheet.dart`
- Existing parse transport: `lib/data/plans/plan_ai_parse_helpers.dart`
  invokes `POST /api/ai/parse-task`; this is *not* a general action executor.
- Planning I/O: `lib/data/plan_service.dart` and `lib/data/plans/*`.
- Timeline I/O: `lib/data/records/record_crud.dart` and related Brain parts.
- Shared speech: `lib/shared/voice/`; Brain voice: `lib/data/voice/`;
  shell routing: `lib/app/shell/shared/shell_voice_*.dart`.
- Existing subscription field: `profiles.tier` `free|pro` (server authoritative).
- Phase A action proposals: `lib/data/ai/viktor_action_contract.dart`.
  This is independent Dart code, not an app-enabled AI endpoint.

Follow `docs/ARCHITECTURE.md`, `docs/UX_CONTRACT.md`,
`docs/APP_STRUCTURE.md`, `docs/DATA_MAP.md`,
`docs/POCKETBASE_MANIFEST.md`, `docs/DESIGN_SYSTEM.md`,
`docs/DEPLOY.md`, `CLAUDE.md` and `CHANGELOG.md`.
The actual live repo takes precedence over older uploaded doc snapshots.

## Action flow

1. User submits speech transcript or text. Existing STT preserves transcript.
2. Server verifies PocketBase auth and `profiles.tier` **before** using
   paid inference or honoring BYOK configuration. No client-only paywall.
3. Build **minimal relevant context only**, filtered by authenticated
   profile owner: selected profile wall-day, necessary plan IDs/titles/times,
   relevant categories/recurrence settings and active record. Never ship
   the entire record history to a model.
4. Provider adapter (hosted or BYOK) returns **structured proposals only**.
   Parse proposals through the versioned `ViktorActionBatch` allowlist.
   Treat output as untrusted. Discard unknown fields/actions.
5. Resolve and validate each ID against current user's PocketBase rows.
   Recheck current duration and entity revision/freshness on the executor
   side. Refuse stale or ambiguous targets; never invent an ID.
6. A deterministic scheduler, not an LLM, calculates actual times,
   sequential cascade, fixed-time commitments, recurrence instance scope,
   timezone and overlap constraints. Preview multi-action mutations.
7. Execute through existing Brain methods for in-app use (local optimistic
   state + offline queue); external clients use an authenticated app-owned
   server endpoint with equivalent domain invariants and realtime sync.
8. Store idempotency by authenticated user and request ID, plus an undo
   snapshot and per-action result. Never replay twice after a timeout.
9. Show actual changed cards and actionable errors, never fake success.

### Proposed phase A JSON envelope

```json
{
  "version": 1,
  "request_id": "req_20261017_01",
  "actions": [
    {
      "name": "update_plan_duration",
      "arguments": {
        "plan_id": "aaaaabbbbbccccc",
        "expected_duration_minutes": 40,
        "duration_minutes": 30
      }
    },
    {
      "name": "move_plan_after",
      "arguments": {
        "plan_id": "dddddeeeeefffff",
        "after_plan_id": "aaaaabbbbbccccc",
        "wall_day": "2026-10-17"
      }
    }
  ]
}
```

These IDs are **illustrative placeholders**, not live rows. The batch
validation does **not** mean any action was executed. A complete executor
must require user ownership and current-state checks even for valid JSON.

The initial proposal allowlist is: `list_day_plans`, `create_plan`,
`update_plan_duration`, `move_plan_after`, `start_record`,
`stop_record`. Historic record edits, deletes, recurring-series edits,
bulk edits, profile and billing edits are **not enabled by this contract**.
Actions that mutate a historical record or whole recurrence series require
explicit new capability design and scope confirmation.

## Subscription architecture

Three user-facing options:

- **Free**: normal app plus deterministic offline-friendly voice commands.
- **Pro / own provider (BYOK)**: subscriber pays Life OS for the action
  system and their provider for tokens. No bundled hosted inference.
- **Pro / included model**: subscriber pays Life OS for Action Engine and a
  measured, capped hosted inference allowance.

Avoid pretending `profiles.tier` alone accounts for both billing options.
Use a **server-owned** entitlement record with plan, provider mode, expiry,
billing state, monthly usage, cap, and optional overage policy. The app
may display the state but may not set it. Keep vendor keys in encrypted
server-side secret storage, not Flutter, PocketBase public record fields,
analytics events or raw logs. BYOK users may request token revocation.
Model selection must not determine domain permissions.

Run per-model benchmarks with Russian/English requests and real adversarial
cases: homonymous task titles, DST/time zones, fixed-time RCC, recurring
tasks, incomplete STT, 40→30 duration edits, offline/retry, 2-device
concurrent edits and untrusted prompt injection in plan notes. Validate
both task success and total cost (input, output, STT, retries).

## ChatGPT outside Life OS

Expose a **user-authorized, remotely hosted MCP server** with Life OS
OAuth and domain-scoped tools, package it as a ChatGPT Plugin. This is the
preferred 2026 route for fresh integrations; new custom GPT creation is no
longer available on personal Free/Go/Plus/Pro accounts. Legacy GPT Actions
can be supported for existing or eligible workspace GPTs, but should not be
our primary path. Plugin availability and write-tool permissions depend on
the user's plan, workspace and platform; verify ordinary Chat usage and
Work separately before advertising either surface. The user's ChatGPT
account is not their Life OS account, and ChatGPT subscription fees do not
fund Life OS hosted model inference. Both surfaces use the same domain
authorization, typed commands, subscription gate and audit trail.

## Phases and acceptance

- **A — contract (this branch)**: schema validator + adversarial tests
  without runtime behavior, schema, UI, deploy or auth changes.
- **B — executor**: ownership/revision checks, deterministic day scheduler,
  dry-run, preview and undo, app Brain adapters and integration tests.
- **C — provider**: secure server-side model adapters, free/paid routing,
  subscription enforcement, metering and BYOK, no plaintext secrets.
- **D — experience**: Viktor entry point in shared shell and voice input,
  text chat, contextual follow-ups, clear preview/results/undo.
- **E — external chat**: ChatGPT Plugin + remote MCP tools with OAuth, privacy
  disclosures, integration tests and release.
- **F — deployment**: full Android/Web smoke, real device STT,
  server migration, release gating and production logging/metrics.

Stop and revert risky changes if startup, record capture, Planning date
swipe, optimistic UI (~100 ms), timezone, PocketBase relations or sync
regress. Phase A alone is intentionally inert and needs no build/deploy.
Before merging any further implementation, run `flutter analyze`,
`flutter test test/viktor_action_contract_test.dart`, full targeted
integration tests, web release build and Android ARM64 smoke if shared
runtime changes. Update `CHANGELOG.md`, `ARCHITECTURE.md`,
`UX_CONTRACT.md`, `APP_STRUCTURE.md`, `DATA_MAP.md` /
`POCKETBASE_MANIFEST.md` when the respective contracts actually change.

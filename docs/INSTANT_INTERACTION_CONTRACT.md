# LIFE OS Instant Interaction / No-Glitch Contract

This contract is a P0 release law for every LIFE OS client and every feature that reads or mutates shared user state.

## Prime rule

**A glitchy function is worse than an absent function.**

A feature is not complete if ordinary use can produce visible lag, flicker, stale data, a false empty state, a rollback to older user input, duplicate state, a frozen screen, or a requirement to navigate/refresh/relaunch before the latest state appears. If a new or changed function cannot satisfy this contract, disable/revert it rather than shipping degraded behavior.

## Instant interaction law

- Local user intent must be reflected visually in about **100 ms or less**, before network I/O.
- Connected remote state is **event-driven**. LIFE OS must add no periodic polling delay to domain-state propagation. As soon as the realtime event reaches a client, the already-open visible surface must project it immediately.
- A page that subscribed before auth/Brain readiness must remain live. Startup timing must never create a dead subscription that only recovers after navigation.
- Already loaded content must stay visible during background reconciliation. Never replace valid content with a blank/loading/empty flash.
- An online cold start must not render a successful empty state until an authoritative snapshot has actually established that the surface is empty. Use stable cached content when available; otherwise show the canonical loading state until the first snapshot resolves.
- A local timer may tick elapsed-time text, animations, or clocks, but **polling is forbidden as the mechanism that discovers shared domain-state changes**.

## Cross-client convergence law

The same account is one live state across web, Android, iOS, Windows/desktop, Wear OS where the domain is supported, and the browser companion.

- Create, update, rename, stop, delete, category/tag change, and other supported shared mutations must propagate to clients that are already open without navigation, manual refresh, or relaunch.
- PocketBase realtime is push-first. Reconnect must perform one coalesced authoritative catch-up because events missed during an SSE transport gap are not replayed.
- Resume/startup also performs catch-up where required; correctness must never depend on the user switching tabs/pages.
- Reconnect recovery must preserve the platform scope: lightweight clients such as Wear must not be forced to hydrate unrelated domains.
- No duplicate reconnect owner is allowed. One canonical recovery path owns transport-gap reconciliation.

## Latest-intent / edit stability law

- The newest user intent wins. An older save completion, stale realtime echo, delayed network response, cache hydrate, or background refresh must never overwrite a newer local edit on screen.
- Autosave must coalesce rapid input and must not mark a newer unsent revision clean when an older request completes.
- Per-entity writes that can overlap must be revision-aware, serialized, or otherwise guaranteed to converge to the newest revision.
- Text entry, rename, note editing, checklist editing, and category changes must not flicker, jump, reset, or rebuild the editor from stale server state.
- A server rejection may roll back only the mutation it actually rejects, and it must never roll back a later valid local revision.

## No false state law

The UI must distinguish **unknown/loading**, **known empty**, **offline cached**, and **known populated** state.

Forbidden examples:

- showing “no records” while the initial records snapshot is still loading;
- showing an old running record after a successful reconnect;
- briefly reverting a renamed record to its prior title;
- receiving a realtime mutation in Brain/cache while the open screen remains unchanged;
- requiring a page switch to make already-received data appear;
- clearing previously loaded cards during a background refetch.

## Mandatory acceptance gate for shared-state changes

Before a shared-state change is called complete, verify the applicable scenarios:

1. **Local optimistic:** mutation is visible immediately on the originating client without waiting for network.
2. **Open peer:** a second already-open client reflects the mutation without navigation/refresh.
3. **Reverse direction:** repeat from the second client back to the first.
4. **Rapid edit/rename:** several successive edits converge to the newest value with no flicker or stale rollback.
5. **Disconnect/reconnect:** disconnect one client, mutate from another, reconnect; the disconnected client converges automatically.
6. **Resume:** suspend/background and resume; no stale running state or manual refresh.
7. **Cold start:** cached data does not disappear; unknown state is not rendered as empty.
8. **Singleton/state invariants:** no duplicate active record or other domain invariant is introduced.
9. **Performance:** no application-imposed polling delay, hot-path network await, rebuild storm, or visible jank.
10. **Release path:** relevant automated tests/analyzers/builds pass on the exact merge candidate, and the production artifact/deployment is verified after merge.

For changes affecting cross-client state, source-string tests alone are insufficient evidence. Prefer deterministic state-machine/integration tests; when an automated two-client harness is unavailable, the release checklist must explicitly record the manual two-client acceptance scenario rather than silently treating compile/CI as end-to-end proof.

## Definition of done

A shared-state feature is **not done** merely because code was merged, CI passed, or a build was published. It is done only when the visible behavior satisfies this contract on the affected clients and the production artifact containing the change is confirmed.

This contract supplements `docs/ARCHITECTURE.md`, `docs/UX_CONTRACT.md`, and the repository agent/coding rules. In any conflict, the stricter latency/stability/correctness requirement wins.

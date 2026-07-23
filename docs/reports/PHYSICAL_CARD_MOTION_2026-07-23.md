# Physical card motion (2026-07-23)

## Scope

Physical drag and resize feedback is implemented for every current plan-card drag surface:

- scheduled cards moved in Planning Time View;
- scheduled cards resized from the top or bottom edge;
- unscheduled cards dragged onto the Time View hour grid;
- custom, category-grouped, and tag-grouped Planning reorder lists;
- post-reorder card settling.

## Canonical implementation

The executable motion source is `lib/core/widgets/life_card.dart`:

- `AppPhysicalDragSurface` — live spring lift/release wrapper;
- `AppPhysicalDragVisual` — drag proxy presentation;
- `kAppPhysicalCardSpring` — one shared, short, damped spring;
- velocity-to-tilt and drag/resize scale helpers.

Feature code must not recreate these values locally.

## Interaction contract

1. Card position remains one-to-one with the pointer. Visual physics must never alter drag geometry.
2. Time View never applies free momentum after release. The final position remains the exact existing snap/cascade result.
3. Drag lift uses restrained scale, shadow, and velocity tilt.
4. Resize anchors the opposite edge and uses restrained cross-axis compression.
5. Release/reorder settling uses the shared spring and ends exactly at the resolved position.
6. Only the active/proxy card receives the stronger shadow; no blur or content distortion is used.
7. `MediaQuery.disableAnimations` removes transform motion while preserving clear interaction state.
8. Horizontal date paging stays locked during Time View drag/resize and unscheduled-card transfer.

## Data and architecture

No PocketBase schema, Brain mutation, recurrence, snap, collision, cascade, or optimistic persistence logic changed. This is a UI/foundation-layer change only.

## Verification

Minimal automated coverage: `test/app_physical_drag_surface_test.dart` contains exactly three focused tests for bounded velocity tilt, uniform drag lift, and restrained resize geometry.

Manual acceptance should check desktop mouse and phone touch for:

- no jump at pickup;
- no card/pointer separation;
- exact time snap after release;
- smooth top/bottom resize;
- no horizontal day swipe during interaction;
- no frame jank with a representative busy day.

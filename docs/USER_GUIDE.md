# LIFE OS — User Guide

Human-readable instructions for LIFE OS. Technical implementation details are in `docs/FUNCTIONS.md`.

## Recurring plans

A recurring plan is one plan that LIFE OS automatically shows again according to its repeat rule — for example, a workout every Monday.

### Editing a recurring plan

When you change a recurring occurrence, LIFE OS asks where the change should apply:

- **Only this event** — changes only the occurrence you opened. The rest of the recurring plan stays unchanged.
- **This and all following events** — changes the occurrence you opened and every later occurrence. Earlier occurrences stay exactly as they were.

There is intentionally no “Entire series” option: LIFE OS does not rewrite earlier recurrence history when you change what should happen from now on.

**Example:** “Gym” repeats every Monday. You open September 28 and rename it to “Swimming”.

- **Only this event:** September 28 becomes “Swimming”; October 5 and later are still “Gym”.
- **This and all following events:** September 28, October 5, October 12 and later become “Swimming”; Mondays before September 28 remain “Gym”.

### Deleting a recurring plan

The same two choices apply:

- **Delete only this event** — skips only the selected occurrence.
- **Delete this and all following events** — removes the selected occurrence and stops the recurrence from that point onward. Earlier occurrences remain in history.

### Completing one occurrence

Marking one occurrence complete does not complete the whole recurrence. LIFE OS records that occurrence as completed and keeps generating later occurrences.

### Individually changed occurrences

An occurrence that you edited separately remains its own exception. It does not get silently overwritten by later recurrence changes that start after it unless it lies inside the selected future range, in which case it stays attached to that future recurrence as an exception.

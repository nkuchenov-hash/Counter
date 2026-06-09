# Life OS — Cursor AI Implementation Prompt

Use this prompt in Cursor to implement **Recursive Folders**, **Spatial Time-Grids**, **Manual Entry**, and **Distinct Summary Analytics** in the existing Flutter Time Tracker app. Apply changes **incrementally** and **step-by-step** as defined below.

---

## 0. Strict Preservation (MANDATORY)

**DO NOT** change the following; treat them as read-only contracts:

- **SharedPreferences storage keys**
  - Rules: `'category_rules_v1'` (constant `_rulesKey` in `_HomeShellState`).
  - Tasks: `'tasks_${year}_${month}_${day}'` via `_tasksKeyForDate(DateTime date)` (e.g. `tasks_2025_02_22`).
- **TableCalendar state flow**
  - Keep `_selectedDate`, `_focusedDay` in `_HomeShellState`.
  - Keep `CalendarPage` receiving `selectedDate`, `focusedDay`, `onSelectDate`, `onJumpToTimeline`.
  - `onSelectDate(selectedDay, focused)` must continue to: (1) `setState` with `_selectedDate = _dateOnly(d)`, `_focusedDay = _dateOnly(f)`, (2) `await _loadTasksForDate(_selectedDate)`.
  - Do not rename or remove these state variables or callback signatures.

---

## 1. Incremental Build & Context

- **Base UI**: Use the existing `HomeShell` and `TimelinePage` in `lib/main.dart`. All new features must plug into this shell (tabs, FAB, callbacks).
- **Strict singleton task logic**: Ensure **only one task** can be active (running) at any time.
  - **Where**: In the same place(s) that start a task (Live or Manual), **before** adding or updating the new task, call the equivalent of `_stopTask` on **any** currently active entry.
  - **Implementation**: Introduce or use a single method (e.g. `_stopAnyActiveTask()`) that finds any `Task t` in `_tasks` where `t.isRunning` (or `t.isActive && t.endTime == null`) and calls `_stopTask(t)` (setting `t.endTime = DateTime.now()`, `t.isActive = false`) and then `_saveTasks()`. Call this method at the **start** of:
    - `_startTaskFromInput()`
    - The callback that creates a task from the **Voice** bottom sheet (e.g. `onCreate` in `_VoiceTaskSheet`)
    - The callback that creates a task from the **Manual Add** dialog (Step 1)
  - So: "Starting any task (Live or Manual) must first stop any active entry."

---

## 2. Step-by-Step Build (The 3 “Apply” Steps)

Implement in order. Each step assumes the previous steps are done.

---

### Step 1: The UI Pivot & Manual Entry Logic

**Navigation — 4 standalone destinations**

- Change the bottom navigation from 3 to **4** destinations, in this order:
  1. **Timeline**
  2. **Planning** (new; can be a placeholder page with a title and short description until Step 3)
  3. **Calendar**
  4. **Categories**
- Keep the same pattern: `pages[_tabIndex]` and `NavigationBar` / `NavigationDestination` (or equivalent). Add a fourth `Widget` for Planning (e.g. `PlanningPage`) so that index 1 = Planning, and shift Calendar to index 2, Categories to index 3.

**Mic FAB**

- Set `floatingActionButtonLocation` to **`FloatingActionButtonLocation.endDocked`**.
- Remove any other floating toolbars (if present); only the single Mic FAB remains.

**Manual Entry System**

- In the **Timeline** screen AppBar, add a button (e.g. icon or "Manual Add" text).
- On tap, open a **dialog** (`showDialog`) that includes:
  - **Category Picker**: Let the user pick one category (from the same list used for tags — e.g. from `_rules` or the folder hierarchy once Step 2 exists). For Step 1, a flat list of categories/tags is enough.
  - **Start time**: Use `showTimePicker` (or a time field that opens it) for the manual task start.
  - **End time**: Same for end time (required for manual entry).
  - **Title**: A text field for the task title.
- On confirm: create a **Task** with `startTime` and `endTime` set from the pickers, `isActive: false`, and tags from the selected category. **Before** adding this task, call the singleton stop logic (e.g. `_stopAnyActiveTask()`) in case a live timer is running. Then add the task to `_tasks`, sort by `startTime`, and `_saveTasks()`.

**Overlap logic**

- If the new manual entry’s time range **overlaps** with an **active live timer** (the one running task):
  - **Truncate** the active timer: set that task’s `endTime` to the **start time** of the manual entry (so the live task ends exactly when the manual one starts).
  - Then add the manual task as above. Implement this in the same place where you handle manual entry confirmation (and after the singleton stop if you stop then truncate; or implement truncation as part of ensuring only one active task and no overlapping segment).

---

### Step 2: The 4-Level “Color DNA” Folder Engine

**Data model — CategoryRule**

- Extend `CategoryRule` (in `lib/main.dart`) with:
  - `List<CategoryRule>? children`
  - `int? colorValue` (e.g. `Color.value` stored as int)
  - `IconData? icon` (store as int/code point or name; Flutter’s `IconData` can be serialized via `codePoint` and optionally `fontFamily`/`fontPackage`)
- Update `toJson` / `fromJson` so that:
  - `children` is saved/loaded recursively (list of CategoryRule maps).
  - `colorValue` and `icon` (or their serialized form) are persisted.
- **Storage key remains** `'category_rules_v1'`; only the **shape** of the JSON may change (new optional fields and nested `children`).

**User customization UI**

- **Root categories** (level 1): Allow the user to pick **Color** and **Icon** (e.g. color picker and icon picker or dropdown). Save into `colorValue` and `icon`.
- **Children (levels 2–4)**: Inherit color and icon from their parent (no separate pickers for child nodes, or show inherited values as read-only). You can optionally allow override at level 2+ later; for this step, inheritance is enough.

**Recursive folder UI**

- In **Categories** (or wherever category rules are edited), display the hierarchy with **recursive `ExpansionTile`** widgets.
  - **Cap depth at 4 levels** (Level 1 = root, Level 2–4 = children). Do not render children beyond level 4.
  - Use **16 dp indentation** per level for child tiles.
  - Draw **faint vertical guide lines** (e.g. a vertical line to the left of each nested group) to show hierarchy.
- Root-level items are level 1; each `ExpansionTile` can have children that are again `ExpansionTile`s until level 4.

**Color inheritance (for display)**

- When displaying a category/folder in the tree, apply opacity by level:
  - Level 1: **100%** opacity
  - Level 2: **80%**
  - Level 3: **60%**
  - Level 4: **40%**
- Use the same base color (from `colorValue` or inherited); only opacity changes.

**Task card tags — breadcrumb**

- On **Timeline** task cards (e.g. `_TaskCard`), show **one** colored breadcrumb tag for the category path, e.g.:
  - **"Root > Sub > Child"**
- Use the category’s (inherited) color for that chip/tag. If a task has multiple tags, show one primary breadcrumb (e.g. first tag or the one matching the folder hierarchy). Prefer the deepest level path that matches (e.g. from the recursive `CategoryRule` tree).

---

### Step 3: Spatial Grids & Pillar-Specific Summary Logic

**Spatial hourly grid — toggle**

- Add a **toggle** in the **Timeline** AppBar (and, if applicable, in Planning AppBar) to switch between:
  - **ListView** (current list of task cards)
  - **GridView** (spatial time grid; see below)
- Store the mode in state (e.g. `_isGridView` or similar) so the user can switch back and forth.

**Spatial logic — 24-hour vertical grid**

- **GridView** mode:
  - **Y-axis** = 24 hours (one day). Use the same `selectedDate` as the rest of the Timeline.
  - Each row (or segment) represents a fixed time slot (e.g. 1 hour or 30 minutes). Recommended: 24 rows for 24 hours.
  - **Tasks** are rendered as **blocks**: vertical position = start time, **height** = duration (proportional to the time slot height). For example, if each hour is 60 px tall, a 2-hour task is 120 px high.
  - Overlapping tasks can be shown side-by-side (e.g. narrow columns) or stacked; minimal overlap handling is fine as long as blocks are visible and roughly correct in time.
- **Interaction**: **Tapping an empty hour block** (or empty slot) must **open the “Add Task” flow** (Manual Add dialog or the existing start flow) with the **start time pre-filled** to that hour (and optionally end time = start + 1 hour).

**Timeline summary — time audit**

- **Aggregate total duration per folder hierarchy.**
  - For each root category (and optionally for each sub-folder), compute the **total duration** of all tasks whose tags/path match that folder or any of its descendants.
  - Example: If "Work" has two sub-folders "Meetings" and "Coding", the **Work** summary = sum of durations of all tasks tagged under Work, Meetings, or Coding.
  - Display this summary on the **Timeline** (e.g. a collapsible section or a bar above/below the list/grid) with labels like "Work: 2h 30m", "Life: 1h 15m", etc.
  - Use the **same** `_tasks` and `_selectedDate`; no new storage keys.

**Planning summary — execution audit**

- **Planning** section has its **own** summary, distinct from Timeline:
  - **Completion ratio**: e.g. "4 out of 10 tasks completed today".
  - **Progress bar**: visual (e.g. `LinearProgressIndicator`) showing completed / total.
  - **Definition of “tasks” for Planning**: Unique task **titles** that were added today via:
    - The **Valve** (see below), or
    - **Manual entry** (from the Manual Add dialog).
  - So you need a way to record “planned tasks” for the day (e.g. a list of task titles or IDs with a `completed` flag). Prefer storing this in SharedPreferences under a **new** key (e.g. `planning_YYYY_MM_DD` or `planning_tasks_...`) so it does not alter the existing tasks key. Completion is toggled by the user (e.g. checkboxes in the Planning grid).

**The Valve**

- **Rule**: Any task **started or added** in the **Timeline** (either via **Start** button / voice / or **Manual Add**) must **automatically** create a corresponding **checkbox entry** in the **Planning** grid for that day.
  - So: when you add or start a task on the Timeline, add an entry to the Planning list for `_selectedDate` (title = task title, completed = false by default). If the same title is added again, you can either add another checkbox or deduplicate by title for the day; specify behavior (e.g. "one checkbox per unique title per day" or "one per task instance").
- The Planning UI shows these checkboxes; toggling them updates the completion count and the progress bar.

---

## 3. Technical Reminders

- **Try/Catch**: For any code that saves or loads data (SharedPreferences, JSON), wrap in try/catch so the app does not crash on corrupt data or I/O errors.
- **Package imports**: Use package imports (e.g. `package:counter/...`) if the project is set up with a package name; otherwise keep existing import style.
- **No deletion of existing behavior**: Do not remove the existing Timeline list, Calendar, or Categories flows; only extend and add (and optionally refactor into feature folders if the rule says so).

---

## 4. Summary Checklist

- [ ] Preservation: same `_rulesKey`, same `_tasksKeyForDate`, same TableCalendar state/callbacks.
- [ ] Singleton: `_stopAnyActiveTask()` (or equivalent) called before every start (input, voice, manual).
- [ ] Step 1: 4 nav destinations (Timeline, Planning, Calendar, Categories); FAB `endDocked`; Manual Add dialog with category, start/end time, title; overlap truncation for active timer.
- [ ] Step 2: `CategoryRule` has `children`, `colorValue`, `icon`; recursive ExpansionTile (4 levels, 16 dp indent, guide lines); color opacity 100/80/60/40; task card breadcrumb "Root > Sub > Child".
- [ ] Step 3: ListView vs GridView toggle; spatial 24h grid with task blocks; tap empty slot → pre-fill hour; Timeline summary by folder hierarchy; Planning summary (ratio + progress bar); Valve: Timeline add/start → Planning checkbox.

Use this prompt in Cursor as a single instruction or break it into three separate prompts (one per step) and apply in order.

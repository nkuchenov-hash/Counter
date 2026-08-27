from pathlib import Path

app = Path('docs/APP_STRUCTURE.md')
text = app.read_text(encoding='utf-8')
old = "| `stats/` | `stats_view.dart`, `day_stats_dashboard.dart`, `stats_detail_tree.dart`, `plan_vs_fact_tab.dart` | Productivity stats (embedded in Timeline): switchable day dashboards, preserved detailed tree, plan vs fact |"
new = "| `stats/` | `stats_view.dart`, `stats_visual_overview.dart`, `stats_detail_tree.dart` | Productivity stats (embedded in Timeline): waking-day time tree plus top-level donut distribution and hourly category timeline |"
if old not in text:
    raise SystemExit('APP_STRUCTURE Stats row not found')
app.write_text(text.replace(old, new, 1), encoding='utf-8')

inv = Path('docs/website/PRODUCT_INVENTORY.md')
text = inv.read_text(encoding='utf-8')
old = '''## 6. Stats & Plan vs Fact

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | **Stats:** hierarchical category tree with durations for selected day (inside Timeline tab). **Plan vs Fact:** compares scheduled plans vs actual records for the wall day. |
| **Proof** | `lib/features/stats/stats_view.dart` — `StatsView`; `lib/features/stats/plan_vs_fact_tab.dart` — `PlanVsFactTab`; `lib/data/plan_service.dart` plan-vs-fact helpers |
| **User value** | Close the loop between intention and reality |
| **Status** | **public-ready** (basic plan vs fact; not enterprise analytics) |
| **Risks / caveats** | Stats respect profile timezone and day clamping; not a full reporting/export suite for end users (admin scripts exist separately). |
| **Website angle** | “See what you planned — and what you actually did.” |
'''
new = '''## 6. Stats

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Waking-day time statistics inside Timeline with two focused modes: an expandable project/category tree down to individual sessions, and a visual overview with a donut split by top-level category plus an hourly day timeline using only top-level category blocks. |
| **Proof** | `lib/features/stats/stats_view.dart` — `StatsView`; `lib/features/stats/stats_detail_tree.dart` — detailed hierarchy; `lib/features/stats/stats_visual_overview.dart` — donut + hourly category timeline |
| **User value** | See both where tracked time went and how the day was distributed across the biggest areas of life/work |
| **Status** | **public-ready** |
| **Risks / caveats** | Stats use the existing waking-day/profile-timezone boundaries and intentionally avoid plan/fact or secondary KPI dashboards for now. |
| **Website angle** | “See where your time went — by category and across the day.” |
'''
if old not in text:
    raise SystemExit('PRODUCT_INVENTORY Stats section not found')
inv.write_text(text.replace(old, new, 1), encoding='utf-8')

changelog = Path('CHANGELOG.md')
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-27 — Stats visual overview [product]\n\n- Replaced the experimental Overview / Day / Plan-Fact Stats surfaces with two focused modes: the original expandable time tree and a visual Charts view.\n- Added a donut distribution by top-level category and an hourly waking-day timeline using only top-level category colors, icons, and labels.\n- Removed the obsolete `day_stats_dashboard.dart` and `plan_vs_fact_tab.dart` modules; waking-day boundaries, timezone behavior, aggregation, and record semantics remain unchanged.\n\n'''
if not text.startswith('## 2026-08-27 — Stats visual overview [product]'):
    changelog.write_text(entry + text, encoding='utf-8')

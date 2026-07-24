// THE DNA. Pure data classes. No DB/UI imports.
//
// This file used to be a 2566-line monolith. Per ROADMAP Tier 4.2 (April 2026)
// it was split into part files under `data/models/` to lower edit-token cost.
// All public types are still imported via `package:counter/data/models.dart`
// or the top-level barrel `package:counter/data/models.dart` — call sites unchanged.
//
// Contents map (search by section):
//   _shared.dart    enums + private json/iso/id helpers
//   profile.dart    Profile, UserProfile, ProfileUpdate, UserSettings, TagCatalogScope
//   category.dart   Category, CategoryRule, tag-rule helpers
//   record.dart     Record, TimelineRecord, Task
//   planning.dart   PlanningTask, PlanningBulkPatch, SourcePlanLinkSuggestion, AiParsedTaskHint
//   tag.dart        Tag
//   stats.dart      BasicDayStats, StatsTreeNode, SessionGroup, StatsNode
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:math' show max;

import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:flutter/material.dart';

part 'models/_shared.dart';
part 'models/profile.dart';
part 'models/category.dart';
part 'models/record.dart';
part 'models/planning.dart';
part 'models/tag.dart';
part 'models/stats.dart';
part 'models/note_rich_types.dart';
part 'models/note_document.dart';

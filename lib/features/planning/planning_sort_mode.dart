enum PlanSortMode { category, time, tags, custom }

/// Order matches [SegmentedButton] segments (persisted as [DatabaseService.kPrefsPlanActiveTab]).
int planSortModeToPersistedIndex(PlanSortMode m) {
  switch (m) {
    case PlanSortMode.category:
      return 0;
    case PlanSortMode.time:
      return 1;
    case PlanSortMode.tags:
      return 2;
    case PlanSortMode.custom:
      return 3;
  }
}

PlanSortMode planSortModeFromPersistedIndex(int i) {
  switch (i) {
    case 0:
      return PlanSortMode.category;
    case 1:
      return PlanSortMode.time;
    case 2:
      return PlanSortMode.tags;
    default:
      return PlanSortMode.custom;
  }
}


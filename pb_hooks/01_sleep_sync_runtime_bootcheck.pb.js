/// <reference path="../pb_data/types.d.ts" />

// Fail PocketBase hook loading early if the canonical cloud sleep runtime
// cannot be parsed/required.
require(__hooks + "/google_health_sleep_runtime.js");

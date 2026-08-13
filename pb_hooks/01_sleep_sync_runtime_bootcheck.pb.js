/// <reference path="../pb_data/types.d.ts" />

// Fail PocketBase hook loading early if the shared Google Fit sleep module cannot be parsed/required.
require(__hooks + "/google_fit_sleep_runtime.js");

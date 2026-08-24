/// <reference path="../pb_data/types.d.ts" />

// Fail PocketBase hook loading early if the canonical Google Fit sleep runtime
// cannot be parsed/required. Touching this bootcheck also forces the complete
// PocketBase bundle deploy after the ETNIKA Path data correction is merged.
require(__hooks + "/google_fit_sleep_runtime.js");

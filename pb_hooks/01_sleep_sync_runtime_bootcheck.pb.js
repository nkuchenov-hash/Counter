/// <reference path="../pb_data/types.d.ts" />

// Fail PocketBase hook loading early if the shared sleep sync module cannot be parsed/required.
require(__hooks + "/sleep_sync_runtime.js");

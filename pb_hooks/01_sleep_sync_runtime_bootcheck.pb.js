/// <reference path="../pb_data/types.d.ts" />

// Fail PocketBase hook loading early if the active Xiaomi sleep runtime cannot
// be parsed/required. The production sleep pipeline is Xiaomi Cloud; keeping
// this guard pointed at the legacy Google Fit runtime can let a broken active
// runtime deploy successfully and leave the hourly scheduler dead.
// This file also acts as the explicit server-bundle trigger after sleep recovery changes.
require(__hooks + "/xiaomi_sleep_runtime.js");

/// <reference path="../pb_data/types.d.ts" />

// EMERGENCY DISABLED 2026-08-24.
// This former one-time ETNIKA Path correction registered PocketBase callbacks
// from inside a local IIFE and caused production startup to fail with
// `ReferenceError: run is not defined` during bootstrap.
//
// Keep this file intentionally inert so normal bundle deployment overwrites any
// previously deployed crashing copy. Production data and pb_data are untouched.

/// <reference path="../pb_data/types.d.ts" />

// Keep PocketBase from collapsing Google Fit connect hook failures into a generic 400.
// This middleware only affects the authenticated sleep connect endpoint.
routerUse(function(e) {
    var path = "";
    try { path = String((e.request && e.request.url && e.request.url.path) || ""); } catch (_) {}
    if (path !== "/api/sleep-sync/google-fit/connect") return e.next();

    try {
        return e.next();
    } catch (err) {
        var detail = String(err || "sleep connect failed");
        // Never echo values that could resemble credentials/tokens.
        detail = detail
            .replace(/(client_secret|refresh_token|access_token|authorization)\s*[=:]\s*[^\s,;}]+/ig, "$1=[redacted]")
            .replace(/Bearer\s+[A-Za-z0-9._~+\/-]+/g, "Bearer [redacted]");
        try {
            e.app.logger().error("google fit connect failed", "error", detail);
        } catch (_) {}
        return e.json(400, {
            code: "google_fit_connect_failed",
            error: detail
        });
    }
});

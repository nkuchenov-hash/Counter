/// <reference path="../pb_data/types.d.ts" />
// Safe password-reset lookup endpoint for the Flutter auth screen.
// Deploy: copy `pb_hooks/` next to the PocketBase executable and restart/reload PB hooks.

var __authResetLastAttemptByKey = {};

function __authResetEmail(raw) {
    return raw == null ? "" : String(raw).trim().toLowerCase();
}

function __authResetClientIp(e) {
    try {
        return e.realIP() || e.remoteIP() || "";
    } catch (_) {
        return "";
    }
}

function __authResetIsRateLimited(key) {
    const now = Date.now();
    const last = __authResetLastAttemptByKey[key] || 0;
    __authResetLastAttemptByKey[key] = now;
    return now - last < 30000;
}

routerAdd("POST", "/api/auth/request-password-reset", (e) => {
    const body = e.requestInfo().body || {};
    const email = __authResetEmail(body.email);
    if (!email || email.indexOf("@") <= 0 || email.length > 254) {
        return e.json(400, { "error": "invalid_email" });
    }

    const throttleKey = email + "|" + __authResetClientIp(e);
    if (__authResetIsRateLimited(throttleKey)) {
        return e.json(429, { "error": "rate_limited" });
    }

    // All valid requests have the same public response, including SMTP errors.
    // Legacy booleans are constant compatibility fields, not account existence.
    const accepted = { "accepted": true, "exists": true, "sent": true };
    let record = null;
    try {
        record = e.app.findAuthRecordByEmail("profiles", email);
    } catch (_) {
        return e.json(200, accepted);
    }

    if (!record) {
        return e.json(200, accepted);
    }

    try {
        $mails.sendRecordPasswordReset(e.app, record);
    } catch (err) {
        try {
            e.app.logger().error("auth.request_password_reset mail send failed", err);
        } catch (_) {}
        return e.json(200, accepted);
    }

    return e.json(200, accepted);
});

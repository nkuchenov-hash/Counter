/// <reference path="../pb_data/types.d.ts" />
// Server-owned read-only calendar synchronization.
// Provider events are materialized as externally-owned rows in `plans`, so the
// existing Planning and Calendar streams display them without a parallel UI.

var __calendarIntegrationCollection = "calendar_integrations";
var __calendarProviders = ["microsoft", "google"];
var __calendarDefaultPastDays = 30;
var __calendarDefaultFutureDays = 365;
var __calendarMsScopes = "openid profile offline_access User.Read Calendars.Read";
var __calendarGoogleScopes = "openid email profile https://www.googleapis.com/auth/calendar.readonly";

function __calendarEnv(name) {
    try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}

function __calendarPublicBaseUrl() {
    return __calendarEnv("CALENDAR_PUBLIC_BASE_URL") || "https://217-114-0-201.sslip.io";
}

function __calendarReturnUrl() {
    return __calendarEnv("CALENDAR_RETURN_URL") || "https://nkuchenov-hash.github.io/Counter/";
}

function __calendarTokenKey(app) {
    var key = __calendarEnv("CALENDAR_TOKEN_KEY");
    if (key.length === 32) return key;
    try {
        var encryptionEnv = String(app.encryptionEnv() || "").trim();
        var inherited = encryptionEnv ? __calendarEnv(encryptionEnv) : "";
        if (inherited.length === 32) return inherited;
    } catch (_) {}
    throw new Error("Calendar token encryption key is not configured");
}

function __calendarProviderValid(provider) {
    return __calendarProviders.indexOf(String(provider || "").toLowerCase()) >= 0;
}

function __calendarProviderConfig(app, provider) {
    provider = String(provider || "").toLowerCase();
    if (provider === "microsoft") {
        var msClientId = __calendarEnv("CALENDAR_MICROSOFT_CLIENT_ID");
        var msClientSecret = __calendarEnv("CALENDAR_MICROSOFT_CLIENT_SECRET");
        if (!msClientId || !msClientSecret) throw new Error("Microsoft calendar OAuth is not configured");
        var tenant = __calendarEnv("CALENDAR_MICROSOFT_TENANT") || "common";
        return {
            provider: provider,
            clientId: msClientId,
            clientSecret: msClientSecret,
            tenant: tenant,
            redirectUri: __calendarPublicBaseUrl() + "/api/calendar-integrations/microsoft/callback",
            authorizeUrl: "https://login.microsoftonline.com/" + encodeURIComponent(tenant) + "/oauth2/v2.0/authorize",
            tokenUrl: "https://login.microsoftonline.com/" + encodeURIComponent(tenant) + "/oauth2/v2.0/token",
            scopes: __calendarMsScopes,
        };
    }
    if (provider === "google") {
        var googleClientId = __calendarEnv("CALENDAR_GOOGLE_CLIENT_ID");
        var googleClientSecret = __calendarEnv("CALENDAR_GOOGLE_CLIENT_SECRET");
        if (!googleClientId || !googleClientSecret) {
            try {
                var profiles = app.findCollectionByNameOrId("profiles");
                var result = profiles.oauth2.getProviderConfig("google");
                var found = result[1];
                var config = result[0];
                if (found && config) {
                    googleClientId = googleClientId || String(config.clientId || "").trim();
                    googleClientSecret = googleClientSecret || String(config.clientSecret || "").trim();
                }
            } catch (_) {}
        }
        if (!googleClientId || !googleClientSecret) throw new Error("Google Calendar OAuth is not configured");
        return {
            provider: provider,
            clientId: googleClientId,
            clientSecret: googleClientSecret,
            redirectUri: __calendarPublicBaseUrl() + "/api/calendar-integrations/google/callback",
            authorizeUrl: "https://accounts.google.com/o/oauth2/v2/auth",
            tokenUrl: "https://oauth2.googleapis.com/token",
            scopes: __calendarGoogleScopes,
        };
    }
    throw new Error("Unsupported calendar provider");
}

function __calendarProviderConfigured(app, provider) {
    try {
        __calendarProviderConfig(app, provider);
        __calendarTokenKey(app);
        return true;
    } catch (_) {
        return false;
    }
}

function __calendarFormEncode(values) {
    var parts = [];
    for (var key in values) {
        if (!Object.prototype.hasOwnProperty.call(values, key)) continue;
        parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
    }
    return parts.join("&");
}

function __calendarDate(value) {
    if (!value) return null;
    var date = value instanceof Date ? value : new Date(value);
    return isNaN(date.getTime()) ? null : date;
}

function __calendarProviderDate(value) {
    var raw = String(value || "").trim();
    if (!raw) return null;
    if (!/[zZ]$/.test(raw) && !/[+-]\d\d:\d\d$/.test(raw)) raw += "Z";
    return __calendarDate(raw);
}

function __calendarUuid() {
    var raw = $security.randomStringWithAlphabet(32, "0123456789abcdef");
    return raw.slice(0, 8) + "-" + raw.slice(8, 12) + "-4" + raw.slice(13, 16) + "-a" + raw.slice(17, 20) + "-" + raw.slice(20, 32);
}

function __calendarJson(value, fallback) {
    if (value === null || value === undefined || value === "") return fallback;
    if (typeof value === "object") return value;
    try { return JSON.parse(String(value)); } catch (_) { return fallback; }
}

function __calendarHttpJson(options) {
    var response = $http.send(options);
    if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new Error((options.label || "Provider request") + " failed: HTTP " + response.statusCode);
    }
    return response.json || {};
}

function __calendarGetConnection(app, userId, provider, createIfMissing) {
    provider = String(provider || "").toLowerCase();
    try {
        return app.findFirstRecordByFilter(
            __calendarIntegrationCollection,
            "user_id = {:uid} && provider = {:provider}",
            { uid: userId, provider: provider }
        );
    } catch (_) {
        if (!createIfMissing) return null;
    }
    var collection = app.findCollectionByNameOrId(__calendarIntegrationCollection);
    var record = new Record(collection);
    record.set("user_id", userId);
    record.set("provider", provider);
    record.set("enabled", true);
    record.set("status", "disconnected");
    record.set("calendars_json", []);
    record.set("sync_past_days", __calendarDefaultPastDays);
    record.set("sync_future_days", __calendarDefaultFutureDays);
    app.save(record);
    return record;
}

function __calendarSanitizeCalendars(value) {
    var raw = __calendarJson(value, []);
    if (!Array.isArray(raw)) return [];
    var out = [];
    var seen = {};
    for (var i = 0; i < raw.length; i++) {
        var item = raw[i] || {};
        var id = String(item.id || "").trim();
        if (!id || seen[id]) continue;
        seen[id] = true;
        out.push({
            id: id,
            name: String(item.name || id).trim(),
            enabled: item.enabled === true,
            primary: item.primary === true,
            fallback_category_id: String(item.fallback_category_id || "").trim(),
        });
    }
    return out;
}

function __calendarConnectionPayload(app, connection, provider) {
    provider = String(provider || "").toLowerCase();
    if (!connection) {
        return {
            provider: provider,
            configured: false,
            enabled: false,
            server_configured: __calendarProviderConfigured(app, provider),
            status: "disconnected",
            account_label: null,
            last_sync_at: null,
            last_error: null,
            calendars: [],
        };
    }
    return {
        provider: provider,
        configured: String(connection.get("refresh_token_enc") || "").length > 0,
        enabled: connection.get("enabled") !== false,
        server_configured: __calendarProviderConfigured(app, provider),
        status: String(connection.get("status") || "disconnected"),
        account_label: connection.get("account_label") || null,
        last_sync_at: connection.get("last_sync_at") || null,
        last_error: connection.get("last_error") || null,
        calendars: __calendarSanitizeCalendars(connection.get("calendars_json")),
    };
}

function __calendarExchangeCode(app, provider, code) {
    var cfg = __calendarProviderConfig(app, provider);
    var body = {
        code: code,
        client_id: cfg.clientId,
        client_secret: cfg.clientSecret,
        redirect_uri: cfg.redirectUri,
        grant_type: "authorization_code",
    };
    if (provider === "microsoft") body.scope = cfg.scopes;
    return __calendarHttpJson({
        url: cfg.tokenUrl,
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __calendarFormEncode(body),
        timeout: 30,
        label: provider + " token exchange",
    });
}

function __calendarRefreshAccess(app, connection) {
    var key = __calendarTokenKey(app);
    var currentEnc = String(connection.get("access_token_enc") || "");
    var expires = __calendarDate(connection.get("access_token_expires_at"));
    if (currentEnc && expires && expires.getTime() > Date.now() + 120000) {
        return String($security.decrypt(currentEnc, key));
    }
    var refreshEnc = String(connection.get("refresh_token_enc") || "");
    if (!refreshEnc) throw new Error("Calendar refresh token is missing");
    var provider = String(connection.get("provider") || "");
    var cfg = __calendarProviderConfig(app, provider);
    var body = {
        refresh_token: String($security.decrypt(refreshEnc, key)),
        client_id: cfg.clientId,
        client_secret: cfg.clientSecret,
        grant_type: "refresh_token",
    };
    if (provider === "microsoft") body.scope = cfg.scopes;
    var token = __calendarHttpJson({
        url: cfg.tokenUrl,
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __calendarFormEncode(body),
        timeout: 30,
        label: provider + " token refresh",
    });
    if (!token.access_token) throw new Error("Calendar access token is missing");
    var expiresIn = Number(token.expires_in || 3600);
    connection.set("access_token_enc", $security.encrypt(String(token.access_token), key));
    connection.set("access_token_expires_at", new Date(Date.now() + expiresIn * 1000).toISOString());
    if (token.refresh_token) {
        connection.set("refresh_token_enc", $security.encrypt(String(token.refresh_token), key));
    }
    app.save(connection);
    return String(token.access_token);
}

function __calendarProviderIdentity(provider, accessToken) {
    if (provider === "microsoft") {
        var ms = __calendarHttpJson({
            url: "https://graph.microsoft.com/v1.0/me?$select=id,displayName,mail,userPrincipalName",
            method: "GET",
            headers: { authorization: "Bearer " + accessToken, accept: "application/json" },
            timeout: 30,
            label: "Microsoft profile",
        });
        return {
            id: String(ms.id || ""),
            label: String(ms.mail || ms.userPrincipalName || ms.displayName || "Microsoft account"),
        };
    }
    var google = __calendarHttpJson({
        url: "https://www.googleapis.com/oauth2/v2/userinfo",
        method: "GET",
        headers: { authorization: "Bearer " + accessToken, accept: "application/json" },
        timeout: 30,
        label: "Google profile",
    });
    return {
        id: String(google.id || ""),
        label: String(google.email || google.name || "Google account"),
    };
}

function __calendarMicrosoftCalendars(accessToken) {
    var rows = [];
    var next = "https://graph.microsoft.com/v1.0/me/calendars?$top=200&$select=id,name,isDefaultCalendar,canEdit";
    while (next) {
        var page = __calendarHttpJson({
            url: next,
            method: "GET",
            headers: { authorization: "Bearer " + accessToken, accept: "application/json" },
            timeout: 45,
            label: "Microsoft calendars",
        });
        var values = page.value || [];
        for (var i = 0; i < values.length; i++) {
            rows.push({
                id: String(values[i].id || ""),
                name: String(values[i].name || "Calendar"),
                primary: values[i].isDefaultCalendar === true,
            });
        }
        next = String(page["@odata.nextLink"] || "");
    }
    return rows;
}

function __calendarGoogleCalendars(accessToken) {
    var rows = [];
    var pageToken = "";
    do {
        var url = "https://www.googleapis.com/calendar/v3/users/me/calendarList?maxResults=250";
        if (pageToken) url += "&pageToken=" + encodeURIComponent(pageToken);
        var page = __calendarHttpJson({
            url: url,
            method: "GET",
            headers: { authorization: "Bearer " + accessToken, accept: "application/json" },
            timeout: 45,
            label: "Google calendars",
        });
        var values = page.items || [];
        for (var i = 0; i < values.length; i++) {
            rows.push({
                id: String(values[i].id || ""),
                name: String(values[i].summaryOverride || values[i].summary || "Calendar"),
                primary: values[i].primary === true,
            });
        }
        pageToken = String(page.nextPageToken || "");
    } while (pageToken);
    return rows;
}

function __calendarMergeCalendarSettings(discovered, existing) {
    var oldById = {};
    for (var i = 0; i < existing.length; i++) oldById[existing[i].id] = existing[i];
    var out = [];
    for (var j = 0; j < discovered.length; j++) {
        var row = discovered[j];
        if (!row.id) continue;
        var old = oldById[row.id];
        out.push({
            id: row.id,
            name: row.name,
            primary: row.primary === true,
            enabled: old ? old.enabled === true : row.primary === true,
            fallback_category_id: old ? String(old.fallback_category_id || "") : "",
        });
    }
    return out;
}

function __calendarRefreshCalendars(app, connection, accessToken) {
    var provider = String(connection.get("provider") || "");
    var discovered = provider === "microsoft"
        ? __calendarMicrosoftCalendars(accessToken)
        : __calendarGoogleCalendars(accessToken);
    var merged = __calendarMergeCalendarSettings(
        discovered,
        __calendarSanitizeCalendars(connection.get("calendars_json"))
    );
    connection.set("calendars_json", merged);
    app.save(connection);
    return merged;
}

function __calendarNormalize(raw) {
    return String(raw || "")
        .toLowerCase()
        .replace(/[^\p{L}\p{N}]+/gu, " ")
        .replace(/\s+/g, " ")
        .trim();
}

var __calendarNoise = {
    "call": true, "meeting": true, "meet": true, "teams": true,
    "microsoft": true, "google": true, "calendar": true, "video": true,
    "online": true, "services": true, "service": true, "appointment": true,
};
var __calendarAliases = { "ts": "technical", "pr": "price", "mtg": "meeting" };

function __calendarTokens(raw) {
    var normalized = __calendarNormalize(raw);
    if (!normalized) return [];
    var parts = normalized.split(" ");
    var out = [];
    for (var i = 0; i < parts.length; i++) {
        var token = __calendarAliases[parts[i]] || parts[i];
        if (!token || __calendarNoise[token]) continue;
        out.push(token);
    }
    return out;
}

function __calendarCollectStrings(value, out) {
    if (value === null || value === undefined) return;
    if (typeof value === "string") {
        if (value.trim()) out.push(value.trim());
        return;
    }
    if (Array.isArray(value)) {
        for (var i = 0; i < value.length; i++) __calendarCollectStrings(value[i], out);
        return;
    }
    if (typeof value === "object") {
        for (var key in value) {
            if (Object.prototype.hasOwnProperty.call(value, key)) {
                __calendarCollectStrings(value[key], out);
            }
        }
    }
}

function __calendarCategoryDepth(record, byId, memo) {
    if (!record) return 0;
    if (memo[record.id] !== undefined) return memo[record.id];
    var parentId = String(record.get("parent_id") || "");
    if (!parentId || !byId[parentId]) return memo[record.id] = 0;
    return memo[record.id] = Math.min(8, 1 + __calendarCategoryDepth(byId[parentId], byId, memo));
}

function __calendarCategoryFragments(record) {
    var out = [];
    __calendarCollectStrings(record.get("name"), out);
    __calendarCollectStrings(record.get("normalized_id"), out);
    __calendarCollectStrings(record.get("category_id"), out);
    __calendarCollectStrings(__calendarJson(record.get("keywords"), {}), out);
    __calendarCollectStrings(__calendarJson(record.get("localized_names"), {}), out);
    return out;
}

function __calendarCategoryScore(title, titleTokens, record) {
    var titleNorm = __calendarNormalize(title);
    var fragments = __calendarCategoryFragments(record);
    var best = 0;
    for (var i = 0; i < fragments.length; i++) {
        var fragmentNorm = __calendarNormalize(fragments[i]);
        if (!fragmentNorm) continue;
        if ((" " + titleNorm + " ").indexOf(" " + fragmentNorm + " ") >= 0) {
            best = Math.max(best, 10000 + fragmentNorm.length);
        }
        var catTokens = __calendarTokens(fragmentNorm);
        if (!catTokens.length) continue;
        var overlap = 0;
        var consecutive = 0;
        for (var c = 0; c < catTokens.length; c++) {
            if (titleTokens.indexOf(catTokens[c]) >= 0) overlap++;
        }
        for (var start = 0; start <= titleTokens.length - catTokens.length; start++) {
            var matched = true;
            for (var k = 0; k < catTokens.length; k++) {
                if (titleTokens[start + k] !== catTokens[k]) { matched = false; break; }
            }
            if (matched) consecutive = catTokens.length;
        }
        if (consecutive > 0) best = Math.max(best, 6000 + consecutive * 100);
        if (overlap >= 2) best = Math.max(best, 2500 + overlap * 100);
        if (overlap === 1) {
            for (var x = 0; x < catTokens.length; x++) {
                if (titleTokens.indexOf(catTokens[x]) >= 0 && catTokens[x].length >= 5) {
                    best = Math.max(best, 1200 + catTokens[x].length);
                }
            }
        }
    }
    return best;
}

function __calendarCategories(app, userId) {
    try {
        return app.findRecordsByFilter(
            "categories",
            "user_id = {:uid} && is_archived = false",
            "order",
            1000,
            0,
            { uid: userId }
        );
    } catch (_) {
        return [];
    }
}

function __calendarResolveAutoCategory(app, userId, title, fallbackId) {
    var categories = __calendarCategories(app, userId);
    var byId = {};
    for (var i = 0; i < categories.length; i++) byId[categories[i].id] = categories[i];
    var memo = {};
    var titleTokens = __calendarTokens(title);
    var best = null;
    var bestScore = 0;
    var bestDepth = -1;
    for (var j = 0; j < categories.length; j++) {
        var score = __calendarCategoryScore(title, titleTokens, categories[j]);
        if (score <= 0) continue;
        var depth = __calendarCategoryDepth(categories[j], byId, memo);
        // A confident child-category match must outrank a matching parent path.
        // Apply the depth bonus only to phrase/multi-token-grade matches.
        var effectiveScore = score + (score >= 2500 ? depth * 5000 : 0);
        if (!best || effectiveScore > bestScore || (effectiveScore === bestScore && depth > bestDepth)) {
            best = categories[j];
            bestScore = effectiveScore;
            bestDepth = depth;
        }
    }
    if (best) return best.id;
    fallbackId = String(fallbackId || "").trim();
    if (fallbackId && byId[fallbackId]) return fallbackId;
    return categories.length ? categories[0].id : "";
}

function __calendarWallDay(profile, date) {
    var offset = Number(profile.get("timezone_offset") || 0);
    var wall = new Date(date.getTime() + offset * 3600000);
    return wall.getUTCFullYear() + "-" +
        String(wall.getUTCMonth() + 1).padStart(2, "0") + "-" +
        String(wall.getUTCDate()).padStart(2, "0");
}

function __calendarFindExistingPlan(app, userId, provider, accountId, calendarId, eventId, occurrenceKey) {
    try {
        return app.findFirstRecordByFilter(
            "plans",
            "user_id = {:uid} && external_provider = {:provider} && external_account_id = {:account} && external_calendar_id = {:calendar} && external_event_id = {:event} && external_occurrence_key = {:occurrence}",
            {
                uid: userId,
                provider: provider,
                account: accountId,
                calendar: calendarId,
                event: eventId,
                occurrence: occurrenceKey,
            }
        );
    } catch (_) {
        return null;
    }
}

function __calendarDeleteEventPlans(app, userId, provider, accountId, calendarId, eventId) {
    var rows = [];
    try {
        rows = app.findRecordsByFilter(
            "plans",
            "user_id = {:uid} && external_provider = {:provider} && external_account_id = {:account} && external_calendar_id = {:calendar} && external_event_id = {:event}",
            "created",
            100,
            0,
            { uid: userId, provider: provider, account: accountId, calendar: calendarId, event: eventId }
        );
    } catch (_) {}
    for (var i = 0; i < rows.length; i++) app.delete(rows[i]);
}

function __calendarUpsertPlan(app, context, event) {
    if (!event.id) return { imported: 0, updated: 0, seenKey: "" };
    var occurrenceKey = String(event.occurrenceKey || event.id);
    var seenKey = event.id + "|" + occurrenceKey;
    if (event.cancelled) {
        __calendarDeleteEventPlans(
            app,
            context.userId,
            context.provider,
            context.accountId,
            context.calendar.id,
            event.id
        );
        return { imported: 0, updated: 0, seenKey: seenKey };
    }
    if (!event.start || !event.end || event.end.getTime() <= event.start.getTime()) {
        return { imported: 0, updated: 0, seenKey: seenKey };
    }
    var existing = __calendarFindExistingPlan(
        app,
        context.userId,
        context.provider,
        context.accountId,
        context.calendar.id,
        event.id,
        occurrenceKey
    );
    var currentCategoryId = existing ? String(existing.get("category_id") || "") : "";
    var previousAutoId = existing ? String(existing.get("external_auto_category_id") || "") : "";
    var manualCategory = !!(existing && currentCategoryId && previousAutoId && currentCategoryId !== previousAutoId);
    var autoCategoryId = __calendarResolveAutoCategory(
        app,
        context.userId,
        event.title,
        context.calendar.fallback_category_id
    );
    var categoryId = manualCategory ? currentCategoryId : autoCategoryId;
    if (!categoryId) return { imported: 0, updated: 0, seenKey: seenKey };

    var plan = existing || new Record(app.findCollectionByNameOrId("plans"));
    plan.set("user_id", context.userId);
    plan.set("plan_id", existing ? plan.get("plan_id") : __calendarUuid());
    plan.set("title", event.title || "Calendar event");
    plan.set("category_id", categoryId);
    plan.set("is_done", false);
    plan.set("order", Number(existing ? plan.get("order") : 0) || 0);
    plan.set("start_time", event.start.toISOString());
    plan.set("end_time", event.end.toISOString());
    plan.set("checklist", existing ? (plan.get("checklist") || "[]") : "[]");
    plan.set("initial_date_key", existing ? (plan.get("initial_date_key") || __calendarWallDay(context.profile, event.start)) : __calendarWallDay(context.profile, event.start));
    plan.set("is_postponed", false);
    plan.set("external_provider", context.provider);
    plan.set("external_account_id", context.accountId);
    plan.set("external_calendar_id", context.calendar.id);
    plan.set("external_event_id", event.id);
    plan.set("external_occurrence_key", occurrenceKey);
    plan.set("external_web_url", event.webUrl || "");
    plan.set("external_join_url", event.joinUrl || "");
    plan.set("external_read_only", true);
    plan.set("external_cancelled", false);
    plan.set("external_updated_at", event.updatedAt ? event.updatedAt.toISOString() : new Date().toISOString());
    if (!manualCategory) plan.set("external_auto_category_id", autoCategoryId);
    app.save(plan);
    return { imported: existing ? 0 : 1, updated: existing ? 1 : 0, seenKey: seenKey };
}

function __calendarCleanupStale(app, context, start, end, seen) {
    var rows = [];
    try {
        rows = app.findRecordsByFilter(
            "plans",
            "user_id = {:uid} && external_provider = {:provider} && external_account_id = {:account} && external_calendar_id = {:calendar} && start_time >= {:start} && start_time < {:end}",
            "start_time",
            5000,
            0,
            {
                uid: context.userId,
                provider: context.provider,
                account: context.accountId,
                calendar: context.calendar.id,
                start: start.toISOString(),
                end: end.toISOString(),
            }
        );
    } catch (_) {}
    var removed = 0;
    for (var i = 0; i < rows.length; i++) {
        var key = String(rows[i].get("external_event_id") || "") + "|" +
            String(rows[i].get("external_occurrence_key") || "");
        if (seen[key]) continue;
        app.delete(rows[i]);
        removed++;
    }
    return removed;
}

function __calendarMicrosoftEvents(accessToken, calendarId, start, end) {
    var rows = [];
    var url = "https://graph.microsoft.com/v1.0/me/calendars/" + encodeURIComponent(calendarId) +
        "/calendarView?startDateTime=" + encodeURIComponent(start.toISOString()) +
        "&endDateTime=" + encodeURIComponent(end.toISOString()) +
        "&$top=1000&$select=id,subject,start,end,isCancelled,webLink,onlineMeeting,location,organizer,attendees,lastModifiedDateTime,type,seriesMasterId";
    while (url) {
        var page = __calendarHttpJson({
            url: url,
            method: "GET",
            headers: {
                authorization: "Bearer " + accessToken,
                accept: "application/json",
                Prefer: 'outlook.timezone="UTC"',
            },
            timeout: 60,
            label: "Microsoft events",
        });
        var values = page.value || [];
        for (var i = 0; i < values.length; i++) {
            var item = values[i] || {};
            var startDate = __calendarProviderDate(item.start && item.start.dateTime);
            var endDate = __calendarProviderDate(item.end && item.end.dateTime);
            rows.push({
                id: String(item.id || ""),
                occurrenceKey: String(item.id || ""),
                title: String(item.subject || "Calendar event"),
                start: startDate,
                end: endDate,
                cancelled: item.isCancelled === true,
                webUrl: String(item.webLink || ""),
                joinUrl: String((item.onlineMeeting && item.onlineMeeting.joinUrl) || ""),
                updatedAt: __calendarDate(item.lastModifiedDateTime),
            });
        }
        url = String(page["@odata.nextLink"] || "");
    }
    return rows;
}

function __calendarGoogleEventDate(value, allDay) {
    if (!value) return null;
    if (allDay) return __calendarDate(String(value) + "T00:00:00Z");
    return __calendarDate(value);
}

function __calendarGoogleEvents(accessToken, calendarId, start, end) {
    var rows = [];
    var pageToken = "";
    do {
        var url = "https://www.googleapis.com/calendar/v3/calendars/" + encodeURIComponent(calendarId) +
            "/events?singleEvents=true&showDeleted=true&maxResults=2500" +
            "&timeMin=" + encodeURIComponent(start.toISOString()) +
            "&timeMax=" + encodeURIComponent(end.toISOString());
        if (pageToken) url += "&pageToken=" + encodeURIComponent(pageToken);
        var page = __calendarHttpJson({
            url: url,
            method: "GET",
            headers: { authorization: "Bearer " + accessToken, accept: "application/json" },
            timeout: 60,
            label: "Google events",
        });
        var values = page.items || [];
        for (var i = 0; i < values.length; i++) {
            var item = values[i] || {};
            var allDay = !!(item.start && item.start.date && !item.start.dateTime);
            var startDate = __calendarGoogleEventDate(
                item.start && (item.start.dateTime || item.start.date),
                allDay
            );
            var endDate = __calendarGoogleEventDate(
                item.end && (item.end.dateTime || item.end.date),
                allDay
            );
            var occurrence = String(
                (item.originalStartTime && (item.originalStartTime.dateTime || item.originalStartTime.date)) ||
                (item.start && (item.start.dateTime || item.start.date)) ||
                item.id || ""
            );
            var joinUrl = String(item.hangoutLink || "");
            var entryPoints = item.conferenceData && item.conferenceData.entryPoints;
            if (!joinUrl && Array.isArray(entryPoints)) {
                for (var e = 0; e < entryPoints.length; e++) {
                    if (entryPoints[e].entryPointType === "video" && entryPoints[e].uri) {
                        joinUrl = String(entryPoints[e].uri);
                        break;
                    }
                }
            }
            rows.push({
                id: String(item.id || ""),
                occurrenceKey: occurrence,
                title: String(item.summary || "Calendar event"),
                start: startDate,
                end: endDate,
                cancelled: String(item.status || "") === "cancelled",
                webUrl: String(item.htmlLink || ""),
                joinUrl: joinUrl,
                updatedAt: __calendarDate(item.updated),
            });
        }
        pageToken = String(page.nextPageToken || "");
    } while (pageToken);
    return rows;
}

function __calendarSyncOne(app, connection) {
    var provider = String(connection.get("provider") || "");
    var userId = String(connection.get("user_id") || "");
    if (!provider || !userId) throw new Error("Calendar connection is invalid");
    var profile = app.findRecordById("profiles", userId);
    var accessToken = __calendarRefreshAccess(app, connection);
    var accountId = String(connection.get("account_id") || "");
    if (!accountId) {
        var identity = __calendarProviderIdentity(provider, accessToken);
        accountId = identity.id;
        connection.set("account_id", identity.id);
        connection.set("account_label", identity.label);
        app.save(connection);
    }
    var calendars = __calendarSanitizeCalendars(connection.get("calendars_json"));
    if (!calendars.length) calendars = __calendarRefreshCalendars(app, connection, accessToken);
    var pastDays = Math.max(0, Math.min(3650, Number(connection.get("sync_past_days") || __calendarDefaultPastDays)));
    var futureDays = Math.max(1, Math.min(3650, Number(connection.get("sync_future_days") || __calendarDefaultFutureDays)));
    var now = new Date();
    var start = new Date(now.getTime() - pastDays * 86400000);
    var end = new Date(now.getTime() + futureDays * 86400000);
    var imported = 0;
    var updated = 0;
    var removed = 0;
    var eventCount = 0;
    for (var i = 0; i < calendars.length; i++) {
        var calendar = calendars[i];
        if (!calendar.enabled) continue;
        var events = provider === "microsoft"
            ? __calendarMicrosoftEvents(accessToken, calendar.id, start, end)
            : __calendarGoogleEvents(accessToken, calendar.id, start, end);
        var seen = {};
        var context = {
            userId: userId,
            provider: provider,
            accountId: accountId,
            profile: profile,
            calendar: calendar,
        };
        for (var j = 0; j < events.length; j++) {
            var result = __calendarUpsertPlan(app, context, events[j]);
            if (result.seenKey) seen[result.seenKey] = true;
            imported += result.imported;
            updated += result.updated;
        }
        removed += __calendarCleanupStale(app, context, start, end, seen);
        eventCount += events.length;
    }
    connection.set("status", "connected");
    connection.set("last_sync_at", new Date().toISOString());
    connection.set("last_error", "");
    app.save(connection);
    return { events: eventCount, imported: imported, updated: updated, removed: removed };
}

function __calendarSyncSafe(app, connection) {
    try {
        connection.set("status", "syncing");
        connection.set("last_error", "");
        app.save(connection);
        return __calendarSyncOne(app, connection);
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        app.save(connection);
        try { app.logger().error("calendar sync failed", "connection", connection.id, "error", err); } catch (_) {}
        throw err;
    }
}

function __calendarDeleteImported(app, userId, provider, accountId, calendarId) {
    var filter = "user_id = {:uid} && external_provider = {:provider}";
    var params = { uid: userId, provider: provider };
    if (accountId) {
        filter += " && external_account_id = {:account}";
        params.account = accountId;
    }
    if (calendarId) {
        filter += " && external_calendar_id = {:calendar}";
        params.calendar = calendarId;
    }
    var rows = [];
    try { rows = app.findRecordsByFilter("plans", filter, "created", 10000, 0, params); } catch (_) {}
    for (var i = 0; i < rows.length; i++) app.delete(rows[i]);
    return rows.length;
}

function __calendarFallbackBelongsToUser(app, userId, categoryId) {
    categoryId = String(categoryId || "").trim();
    if (!categoryId) return "";
    try {
        var category = app.findRecordById("categories", categoryId);
        return String(category.get("user_id") || "") === userId && category.get("is_archived") !== true
            ? categoryId
            : "";
    } catch (_) {
        return "";
    }
}

function __calendarOAuthBegin(e, provider) {
    var cfg;
    try {
        cfg = __calendarProviderConfig(e.app, provider);
        __calendarTokenKey(e.app);
    } catch (err) {
        return e.json(503, { error: "server_not_configured" });
    }
    var connection = __calendarGetConnection(e.app, e.auth.id, provider, true);
    var state = $security.randomStringWithAlphabet(48, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
    connection.set("oauth_state", state);
    connection.set("oauth_state_expires_at", new Date(Date.now() + 10 * 60000).toISOString());
    connection.set("status", "connecting");
    connection.set("last_error", "");
    e.app.save(connection);
    var values = {
        client_id: cfg.clientId,
        redirect_uri: cfg.redirectUri,
        response_type: "code",
        scope: cfg.scopes,
        state: state,
    };
    if (provider === "microsoft") {
        values.response_mode = "query";
        values.prompt = "select_account";
    } else {
        values.access_type = "offline";
        values.prompt = "consent";
        values.include_granted_scopes = "true";
    }
    return e.json(200, { authorization_url: cfg.authorizeUrl + "?" + __calendarFormEncode(values) });
}

function __calendarOAuthCallback(e, provider) {
    var query = e.requestInfo().query || {};
    var state = String(query.state || "");
    var code = String(query.code || "");
    var providerError = String(query.error || "");
    if (providerError) return e.html(400, "<h1>Calendar connection cancelled</h1><p>The provider did not grant access.</p>");
    if (!state || !code) return e.html(400, "<h1>Calendar connection failed</h1><p>Missing OAuth response.</p>");
    var connection = null;
    try { connection = e.app.findFirstRecordByData(__calendarIntegrationCollection, "oauth_state", state); } catch (_) {}
    if (!connection || String(connection.get("provider") || "") !== provider) {
        return e.html(400, "<h1>Calendar connection failed</h1><p>Invalid authorization state.</p>");
    }
    var expires = __calendarDate(connection.get("oauth_state_expires_at"));
    if (!expires || expires.getTime() < Date.now()) {
        return e.html(400, "<h1>Calendar connection failed</h1><p>Authorization expired.</p>");
    }
    try {
        var token = __calendarExchangeCode(e.app, provider, code);
        if (!token.access_token) throw new Error("Provider returned no access token");
        var key = __calendarTokenKey(e.app);
        var previousRefresh = String(connection.get("refresh_token_enc") || "");
        if (token.refresh_token) {
            connection.set("refresh_token_enc", $security.encrypt(String(token.refresh_token), key));
        } else if (!previousRefresh) {
            throw new Error("Provider returned no refresh token");
        }
        connection.set("access_token_enc", $security.encrypt(String(token.access_token), key));
        connection.set("access_token_expires_at", new Date(Date.now() + Number(token.expires_in || 3600) * 1000).toISOString());
        var identity = __calendarProviderIdentity(provider, String(token.access_token));
        connection.set("account_id", identity.id);
        connection.set("account_label", identity.label);
        connection.set("enabled", true);
        connection.set("status", "connected");
        connection.set("oauth_state", "");
        connection.set("oauth_state_expires_at", "");
        connection.set("last_error", "");
        e.app.save(connection);
        __calendarRefreshCalendars(e.app, connection, String(token.access_token));
        try { __calendarSyncSafe(e.app, connection); } catch (_) {}
        var returnUrl = __calendarReturnUrl();
        return e.html(200, "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='2;url=" + returnUrl + "'><title>Life OS</title><h1>Calendar connected</h1><p>Your meetings will appear with normal Life OS plans. You can return to the app.</p>");
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        e.app.save(connection);
        return e.html(500, "<h1>Calendar connection failed</h1><p>Return to Life OS and try again.</p>");
    }
}

routerAdd("GET", "/api/calendar-integrations/status", function(e) {
    var integrations = [];
    for (var i = 0; i < __calendarProviders.length; i++) {
        var provider = __calendarProviders[i];
        integrations.push(__calendarConnectionPayload(
            e.app,
            __calendarGetConnection(e.app, e.auth.id, provider, false),
            provider
        ));
    }
    return e.json(200, { integrations: integrations });
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/calendar-integrations/microsoft/connect", function(e) {
    return __calendarOAuthBegin(e, "microsoft");
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/calendar-integrations/google/connect", function(e) {
    return __calendarOAuthBegin(e, "google");
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/calendar-integrations/microsoft/callback", function(e) {
    return __calendarOAuthCallback(e, "microsoft");
});

routerAdd("GET", "/api/calendar-integrations/google/callback", function(e) {
    return __calendarOAuthCallback(e, "google");
});

routerAdd("POST", "/api/calendar-integrations/settings", function(e) {
    var body = e.requestInfo().body || {};
    var provider = String(body.provider || "").toLowerCase();
    if (!__calendarProviderValid(provider)) return e.json(400, { error: "invalid_provider" });
    var connection = __calendarGetConnection(e.app, e.auth.id, provider, false);
    if (!connection) return e.json(404, { error: "not_connected" });
    var incoming = __calendarSanitizeCalendars(body.calendars || []);
    var existing = __calendarSanitizeCalendars(connection.get("calendars_json"));
    var existingById = {};
    for (var i = 0; i < existing.length; i++) existingById[existing[i].id] = existing[i];
    var next = [];
    for (var j = 0; j < incoming.length; j++) {
        var item = incoming[j];
        if (!existingById[item.id]) continue;
        var fallback = __calendarFallbackBelongsToUser(e.app, e.auth.id, item.fallback_category_id);
        next.push({
            id: item.id,
            name: existingById[item.id].name,
            primary: existingById[item.id].primary === true,
            enabled: item.enabled === true,
            fallback_category_id: fallback,
        });
        if (!item.enabled) {
            __calendarDeleteImported(
                e.app,
                e.auth.id,
                provider,
                String(connection.get("account_id") || ""),
                item.id
            );
        }
    }
    connection.set("calendars_json", next);
    e.app.save(connection);
    return e.json(200, __calendarConnectionPayload(e.app, connection, provider));
}, $apis.requireAuth("profiles"));

function __calendarSyncRoute(e, provider) {
    var connection = __calendarGetConnection(e.app, e.auth.id, provider, false);
    if (!connection || !String(connection.get("refresh_token_enc") || "")) {
        return e.json(409, { error: "not_connected" });
    }
    try {
        var result = __calendarSyncSafe(e.app, connection);
        return e.json(200, { ok: true, result: result });
    } catch (_) {
        return e.json(502, { ok: false, error: "provider_sync_failed" });
    }
}

routerAdd("POST", "/api/calendar-integrations/microsoft/sync", function(e) {
    return __calendarSyncRoute(e, "microsoft");
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/calendar-integrations/google/sync", function(e) {
    return __calendarSyncRoute(e, "google");
}, $apis.requireAuth("profiles"));

function __calendarDisconnectRoute(e, provider) {
    var connection = __calendarGetConnection(e.app, e.auth.id, provider, false);
    if (!connection) return e.json(200, { ok: true, removed: 0 });
    var removed = __calendarDeleteImported(
        e.app,
        e.auth.id,
        provider,
        String(connection.get("account_id") || ""),
        ""
    );
    e.app.delete(connection);
    return e.json(200, { ok: true, removed: removed });
}

routerAdd("DELETE", "/api/calendar-integrations/microsoft", function(e) {
    return __calendarDisconnectRoute(e, "microsoft");
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/calendar-integrations/google", function(e) {
    return __calendarDisconnectRoute(e, "google");
}, $apis.requireAuth("profiles"));

cronAdd("lifeos_calendar_integrations", "*/15 * * * *", function() {
    var connections = [];
    try {
        connections = $app.findRecordsByFilter(
            __calendarIntegrationCollection,
            "enabled = true && refresh_token_enc != ''",
            "updated",
            500,
            0
        );
    } catch (_) {
        return;
    }
    for (var i = 0; i < connections.length; i++) {
        try { __calendarSyncSafe($app, connections[i]); } catch (_) {}
    }
});

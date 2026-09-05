/// <reference path="../pb_data/types.d.ts" />
// Server-owned People source adapters. Source rows are never promoted to visible
// People here: this hook only refreshes people_source_contacts. Promotion is an
// explicit client action so spam/random provider contacts cannot enter People.

var __peopleIntegrationCollection = "people_integrations";
var __peopleSourceCollection = "people_source_contacts";
var __peopleProviders = ["google_contacts", "microsoft", "vk", "facebook"];

function __peopleEnv(name) {
    try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}

function __peoplePublicBaseUrl() {
    return __peopleEnv("PEOPLE_PUBLIC_BASE_URL") || __peopleEnv("CALENDAR_PUBLIC_BASE_URL") || "https://217-114-0-201.sslip.io";
}

function __peopleReturnUrl() {
    return __peopleEnv("PEOPLE_RETURN_URL") || __peopleEnv("CALENDAR_RETURN_URL") || "https://nkuchenov-hash.github.io/Counter/";
}

function __peopleTokenKey(app) {
    var key = __peopleEnv("PEOPLE_TOKEN_KEY") || __peopleEnv("CALENDAR_TOKEN_KEY");
    if (key.length === 32) return key;
    try {
        var encryptionEnv = String(app.encryptionEnv() || "").trim();
        var inherited = encryptionEnv ? __peopleEnv(encryptionEnv) : "";
        if (inherited.length === 32) return inherited;
    } catch (_) {}
    throw new Error("People token encryption key is not configured");
}

function __peopleProviderValid(provider) {
    return __peopleProviders.indexOf(String(provider || "").toLowerCase()) >= 0;
}

function __peopleGoogleCredentials(app) {
    var clientId = __peopleEnv("PEOPLE_GOOGLE_CLIENT_ID") || __peopleEnv("CALENDAR_GOOGLE_CLIENT_ID");
    var clientSecret = __peopleEnv("PEOPLE_GOOGLE_CLIENT_SECRET") || __peopleEnv("CALENDAR_GOOGLE_CLIENT_SECRET");
    if (!clientId || !clientSecret) {
        try {
            var profiles = app.findCollectionByNameOrId("profiles");
            var result = profiles.oauth2.getProviderConfig("google");
            var found = result[1];
            var config = result[0];
            if (found && config) {
                clientId = clientId || String(config.clientId || "").trim();
                clientSecret = clientSecret || String(config.clientSecret || "").trim();
            }
        } catch (_) {}
    }
    return { clientId: clientId, clientSecret: clientSecret };
}

function __peopleProviderConfig(app, provider) {
    provider = String(provider || "").toLowerCase();
    if (provider === "google_contacts") {
        var google = __peopleGoogleCredentials(app);
        if (!google.clientId || !google.clientSecret) throw new Error("Google People OAuth is not configured");
        return {
            provider: provider,
            clientId: google.clientId,
            clientSecret: google.clientSecret,
            redirectUri: __peoplePublicBaseUrl() + "/api/people-integrations/google_contacts/callback",
            authorizeUrl: "https://accounts.google.com/o/oauth2/v2/auth",
            tokenUrl: "https://oauth2.googleapis.com/token",
            scopes: "openid email profile https://www.googleapis.com/auth/contacts.readonly",
            refreshable: true,
        };
    }
    if (provider === "microsoft") {
        var clientId = __peopleEnv("PEOPLE_MICROSOFT_CLIENT_ID") || __peopleEnv("CALENDAR_MICROSOFT_CLIENT_ID");
        var clientSecret = __peopleEnv("PEOPLE_MICROSOFT_CLIENT_SECRET") || __peopleEnv("CALENDAR_MICROSOFT_CLIENT_SECRET");
        if (!clientId || !clientSecret) throw new Error("Microsoft People OAuth is not configured");
        var tenant = __peopleEnv("PEOPLE_MICROSOFT_TENANT") || __peopleEnv("CALENDAR_MICROSOFT_TENANT") || "common";
        return {
            provider: provider,
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUri: __peoplePublicBaseUrl() + "/api/people-integrations/microsoft/callback",
            authorizeUrl: "https://login.microsoftonline.com/" + encodeURIComponent(tenant) + "/oauth2/v2.0/authorize",
            tokenUrl: "https://login.microsoftonline.com/" + encodeURIComponent(tenant) + "/oauth2/v2.0/token",
            scopes: "openid profile offline_access User.Read Contacts.Read",
            refreshable: true,
        };
    }
    if (provider === "vk") {
        var vkClientId = __peopleEnv("PEOPLE_VK_CLIENT_ID");
        var vkClientSecret = __peopleEnv("PEOPLE_VK_CLIENT_SECRET");
        if (!vkClientId || !vkClientSecret) throw new Error("VK People OAuth is not configured");
        return {
            provider: provider,
            clientId: vkClientId,
            clientSecret: vkClientSecret,
            redirectUri: __peoplePublicBaseUrl() + "/api/people-integrations/vk/callback",
            authorizeUrl: __peopleEnv("PEOPLE_VK_AUTHORIZE_URL") || "https://oauth.vk.com/authorize",
            tokenUrl: __peopleEnv("PEOPLE_VK_TOKEN_URL") || "https://oauth.vk.com/access_token",
            scopes: "friends,offline",
            refreshable: false,
        };
    }
    if (provider === "facebook") {
        var fbClientId = __peopleEnv("PEOPLE_FACEBOOK_CLIENT_ID");
        var fbClientSecret = __peopleEnv("PEOPLE_FACEBOOK_CLIENT_SECRET");
        if (!fbClientId || !fbClientSecret) throw new Error("Facebook People OAuth is not configured");
        var version = __peopleEnv("PEOPLE_FACEBOOK_GRAPH_VERSION") || "v24.0";
        return {
            provider: provider,
            clientId: fbClientId,
            clientSecret: fbClientSecret,
            redirectUri: __peoplePublicBaseUrl() + "/api/people-integrations/facebook/callback",
            authorizeUrl: "https://www.facebook.com/" + version + "/dialog/oauth",
            tokenUrl: "https://graph.facebook.com/" + version + "/oauth/access_token",
            graphVersion: version,
            scopes: "public_profile,user_friends",
            refreshable: false,
        };
    }
    throw new Error("Unsupported People provider");
}

function __peopleProviderConfigured(app, provider) {
    try {
        __peopleProviderConfig(app, provider);
        __peopleTokenKey(app);
        return true;
    } catch (_) {
        return false;
    }
}

function __peopleFormEncode(values) {
    var parts = [];
    for (var key in values) {
        if (!Object.prototype.hasOwnProperty.call(values, key)) continue;
        if (values[key] === null || values[key] === undefined || values[key] === "") continue;
        parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
    }
    return parts.join("&");
}

function __peopleDate(value) {
    if (!value) return null;
    var date = value instanceof Date ? value : new Date(value);
    return isNaN(date.getTime()) ? null : date;
}

function __peopleHttpJson(options) {
    var response = $http.send(options);
    if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new Error((options.label || "Provider request") + " failed: HTTP " + response.statusCode);
    }
    if (response.json && typeof response.json === "object") return response.json;
    var body = String(response.body || "").trim();
    if (!body) return {};
    try { return JSON.parse(body); } catch (_) {
        var out = {};
        var parts = body.split("&");
        for (var i = 0; i < parts.length; i++) {
            var pair = parts[i].split("=");
            if (pair.length >= 2) out[decodeURIComponent(pair[0])] = decodeURIComponent(pair.slice(1).join("="));
        }
        return out;
    }
}

function __peopleGetConnection(app, userId, provider, createIfMissing) {
    provider = String(provider || "").toLowerCase();
    try {
        return app.findFirstRecordByFilter(
            __peopleIntegrationCollection,
            "user_id = {:uid} && provider = {:provider}",
            { uid: userId, provider: provider }
        );
    } catch (_) {
        if (!createIfMissing) return null;
    }
    var collection = app.findCollectionByNameOrId(__peopleIntegrationCollection);
    var record = new Record(collection);
    record.set("user_id", userId);
    record.set("provider", provider);
    record.set("enabled", true);
    record.set("status", "disconnected");
    app.save(record);
    return record;
}

function __peopleConnectionPayload(app, connection, provider) {
    provider = String(provider || "").toLowerCase();
    if (!connection) {
        return {
            provider: provider,
            configured: false,
            server_configured: __peopleProviderConfigured(app, provider),
            status: "disconnected",
            account_label: null,
            last_sync_at: null,
            last_error: null,
        };
    }
    return {
        provider: provider,
        configured: String(connection.get("access_token_enc") || "").length > 0 || String(connection.get("refresh_token_enc") || "").length > 0,
        server_configured: __peopleProviderConfigured(app, provider),
        status: String(connection.get("status") || "disconnected"),
        account_label: connection.get("account_label") || null,
        last_sync_at: connection.get("last_sync_at") || null,
        last_error: connection.get("last_error") || null,
    };
}

function __peopleExchangeCode(app, provider, code) {
    var cfg = __peopleProviderConfig(app, provider);
    var body = {
        code: code,
        client_id: cfg.clientId,
        client_secret: cfg.clientSecret,
        redirect_uri: cfg.redirectUri,
    };
    if (provider === "google_contacts" || provider === "microsoft") body.grant_type = "authorization_code";
    if (provider === "microsoft") body.scope = cfg.scopes;
    if (provider === "vk") body.v = __peopleEnv("PEOPLE_VK_API_VERSION") || "5.199";
    return __peopleHttpJson({
        url: cfg.tokenUrl,
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/json" },
        body: __peopleFormEncode(body),
        timeout: 30,
        label: provider + " token exchange",
    });
}

function __peopleRefreshAccess(app, connection) {
    var key = __peopleTokenKey(app);
    var currentEnc = String(connection.get("access_token_enc") || "");
    var expires = __peopleDate(connection.get("access_token_expires_at"));
    if (currentEnc && (!expires || expires.getTime() > Date.now() + 120000)) {
        return String($security.decrypt(currentEnc, key));
    }
    var provider = String(connection.get("provider") || "");
    var cfg = __peopleProviderConfig(app, provider);
    var refreshEnc = String(connection.get("refresh_token_enc") || "");
    if (!cfg.refreshable || !refreshEnc) {
        throw new Error("People provider session expired; reconnect required");
    }
    var body = {
        refresh_token: String($security.decrypt(refreshEnc, key)),
        client_id: cfg.clientId,
        client_secret: cfg.clientSecret,
        grant_type: "refresh_token",
    };
    if (provider === "microsoft") body.scope = cfg.scopes;
    var token = __peopleHttpJson({
        url: cfg.tokenUrl,
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/json" },
        body: __peopleFormEncode(body),
        timeout: 30,
        label: provider + " token refresh",
    });
    if (!token.access_token) throw new Error("People access token is missing");
    connection.set("access_token_enc", $security.encrypt(String(token.access_token), key));
    connection.set("access_token_expires_at", new Date(Date.now() + Number(token.expires_in || 3600) * 1000).toISOString());
    if (token.refresh_token) connection.set("refresh_token_enc", $security.encrypt(String(token.refresh_token), key));
    app.save(connection);
    return String(token.access_token);
}

function __peopleProviderIdentity(provider, accessToken, cfg) {
    if (provider === "google_contacts") {
        var google = __peopleHttpJson({
            url: "https://openidconnect.googleapis.com/v1/userinfo",
            method: "GET",
            headers: { authorization: "Bearer " + accessToken, accept: "application/json" },
            timeout: 30,
            label: "Google identity",
        });
        return { id: String(google.sub || google.email || ""), label: String(google.email || google.name || "Google") };
    }
    if (provider === "microsoft") {
        var ms = __peopleHttpJson({
            url: "https://graph.microsoft.com/v1.0/me?$select=id,displayName,mail,userPrincipalName",
            method: "GET",
            headers: { authorization: "Bearer " + accessToken, accept: "application/json" },
            timeout: 30,
            label: "Microsoft identity",
        });
        return { id: String(ms.id || ""), label: String(ms.mail || ms.userPrincipalName || ms.displayName || "Microsoft") };
    }
    if (provider === "vk") {
        var vk = __peopleHttpJson({
            url: "https://api.vk.com/method/users.get?access_token=" + encodeURIComponent(accessToken) + "&v=" + encodeURIComponent(__peopleEnv("PEOPLE_VK_API_VERSION") || "5.199"),
            method: "GET",
            headers: { accept: "application/json" },
            timeout: 30,
            label: "VK identity",
        });
        var user = vk.response && vk.response[0] ? vk.response[0] : {};
        return { id: String(user.id || ""), label: String((user.first_name || "") + " " + (user.last_name || "")).trim() || "VK" };
    }
    if (provider === "facebook") {
        var fb = __peopleHttpJson({
            url: "https://graph.facebook.com/" + cfg.graphVersion + "/me?fields=id,name&access_token=" + encodeURIComponent(accessToken),
            method: "GET",
            headers: { accept: "application/json" },
            timeout: 30,
            label: "Facebook identity",
        });
        return { id: String(fb.id || ""), label: String(fb.name || "Facebook") };
    }
    return { id: "", label: provider };
}

function __peopleBirthdayFromGoogle(item) {
    var values = item && item.birthdays;
    if (!Array.isArray(values)) return {};
    for (var i = 0; i < values.length; i++) {
        var date = values[i] && values[i].date;
        if (!date || !date.month || !date.day) continue;
        return { month: Number(date.month), day: Number(date.day), year: date.year ? Number(date.year) : null };
    }
    return {};
}

function __peopleBirthdayFromString(raw) {
    raw = String(raw || "").trim();
    if (!raw) return {};
    var dot = /^(\d{1,2})\.(\d{1,2})(?:\.(\d{4}))?$/.exec(raw);
    if (dot) return { month: Number(dot[2]), day: Number(dot[1]), year: dot[3] ? Number(dot[3]) : null };
    var iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw);
    if (iso) return { month: Number(iso[2]), day: Number(iso[3]), year: Number(iso[1]) };
    return {};
}

function __peopleFirstArrayValue(values, extractor) {
    if (!Array.isArray(values)) return "";
    for (var i = 0; i < values.length; i++) {
        var value = extractor(values[i] || {});
        if (value) return String(value);
    }
    return "";
}

function __peopleGoogleContacts(accessToken) {
    var rows = [];
    var pageToken = "";
    do {
        var url = "https://people.googleapis.com/v1/people/me/connections?pageSize=1000&personFields=" +
            encodeURIComponent("names,birthdays,photos,emailAddresses,phoneNumbers,memberships");
        if (pageToken) url += "&pageToken=" + encodeURIComponent(pageToken);
        var page = __peopleHttpJson({
            url: url,
            method: "GET",
            headers: { authorization: "Bearer " + accessToken, accept: "application/json" },
            timeout: 60,
            label: "Google contacts",
        });
        var values = page.connections || [];
        for (var i = 0; i < values.length; i++) {
            var item = values[i] || {};
            var name = __peopleFirstArrayValue(item.names, function(v) { return v.displayName || ""; });
            if (!name) continue;
            var birthday = __peopleBirthdayFromGoogle(item);
            var photo = __peopleFirstArrayValue(item.photos, function(v) { return v.default === true ? "" : (v.url || ""); });
            if (!photo) photo = __peopleFirstArrayValue(item.photos, function(v) { return v.url || ""; });
            var group = __peopleFirstArrayValue(item.memberships, function(v) {
                return v.contactGroupMembership && (v.contactGroupMembership.contactGroupResourceName || "");
            });
            rows.push({
                external_id: String(item.resourceName || ""),
                display_name: name,
                avatar_url: photo,
                primary_email: __peopleFirstArrayValue(item.emailAddresses, function(v) { return v.value || ""; }),
                primary_phone: __peopleFirstArrayValue(item.phoneNumbers, function(v) { return v.value || ""; }),
                birthday_month: birthday.month || null,
                birthday_day: birthday.day || null,
                birthday_year: birthday.year || null,
                source_group: group,
                raw_meta: { resource_name: item.resourceName || "", provider: "google_contacts" },
            });
        }
        pageToken = String(page.nextPageToken || "");
    } while (pageToken);
    return rows;
}

function __peopleMicrosoftContacts(accessToken) {
    var rows = [];
    var url = "https://graph.microsoft.com/v1.0/me/contacts?$top=999&$select=id,displayName,birthday,emailAddresses,mobilePhone,homePhones,businessPhones,categories";
    while (url) {
        var page = __peopleHttpJson({
            url: url,
            method: "GET",
            headers: { authorization: "Bearer " + accessToken, accept: "application/json" },
            timeout: 60,
            label: "Microsoft contacts",
        });
        var values = page.value || [];
        for (var i = 0; i < values.length; i++) {
            var item = values[i] || {};
            var name = String(item.displayName || "").trim();
            if (!name) continue;
            var birthday = __peopleBirthdayFromString(item.birthday);
            var phone = String(item.mobilePhone || "").trim();
            if (!phone && Array.isArray(item.homePhones) && item.homePhones.length) phone = String(item.homePhones[0] || "");
            if (!phone && Array.isArray(item.businessPhones) && item.businessPhones.length) phone = String(item.businessPhones[0] || "");
            rows.push({
                external_id: String(item.id || ""),
                display_name: name,
                avatar_url: "",
                primary_email: __peopleFirstArrayValue(item.emailAddresses, function(v) { return v.address || ""; }),
                primary_phone: phone,
                birthday_month: birthday.month || null,
                birthday_day: birthday.day || null,
                birthday_year: birthday.year || null,
                source_group: Array.isArray(item.categories) ? item.categories.join(", ") : "",
                raw_meta: { provider: "microsoft", categories: item.categories || [] },
            });
        }
        url = String(page["@odata.nextLink"] || "");
    }
    return rows;
}

function __peopleVkContacts(accessToken) {
    var version = __peopleEnv("PEOPLE_VK_API_VERSION") || "5.199";
    var page = __peopleHttpJson({
        url: "https://api.vk.com/method/friends.get?count=5000&fields=bdate,photo_200,lists&access_token=" + encodeURIComponent(accessToken) + "&v=" + encodeURIComponent(version),
        method: "GET",
        headers: { accept: "application/json" },
        timeout: 60,
        label: "VK friends",
    });
    if (page.error) throw new Error("VK API error: " + String(page.error.error_msg || page.error.error_code || "unknown"));
    var values = page.response && page.response.items ? page.response.items : [];
    var rows = [];
    for (var i = 0; i < values.length; i++) {
        var item = values[i] || {};
        var name = String((item.first_name || "") + " " + (item.last_name || "")).trim();
        if (!name) continue;
        var birthday = __peopleBirthdayFromString(item.bdate);
        rows.push({
            external_id: String(item.id || ""),
            display_name: name,
            avatar_url: String(item.photo_200 || ""),
            primary_email: "",
            primary_phone: "",
            birthday_month: birthday.month || null,
            birthday_day: birthday.day || null,
            birthday_year: birthday.year || null,
            source_group: Array.isArray(item.lists) ? item.lists.join(",") : "",
            raw_meta: { provider: "vk", lists: item.lists || [] },
        });
    }
    return rows;
}

function __peopleFacebookContacts(accessToken, cfg) {
    var rows = [];
    var url = "https://graph.facebook.com/" + cfg.graphVersion + "/me/friends?limit=5000&fields=id,name,picture.type(large)&access_token=" + encodeURIComponent(accessToken);
    while (url) {
        var page = __peopleHttpJson({
            url: url,
            method: "GET",
            headers: { accept: "application/json" },
            timeout: 60,
            label: "Facebook friends",
        });
        var values = page.data || [];
        for (var i = 0; i < values.length; i++) {
            var item = values[i] || {};
            var picture = item.picture && item.picture.data ? item.picture.data.url : "";
            rows.push({
                external_id: String(item.id || ""),
                display_name: String(item.name || ""),
                avatar_url: String(picture || ""),
                primary_email: "",
                primary_phone: "",
                birthday_month: null,
                birthday_day: null,
                birthday_year: null,
                source_group: "",
                raw_meta: { provider: "facebook", api_limited_to_app_using_friends: true },
            });
        }
        url = page.paging && page.paging.next ? String(page.paging.next) : "";
    }
    return rows;
}

function __peopleFindSource(app, userId, provider, externalId) {
    try {
        return app.findFirstRecordByFilter(
            __peopleSourceCollection,
            "user_id = {:uid} && provider = {:provider} && external_id = {:external}",
            { uid: userId, provider: provider, external: externalId }
        );
    } catch (_) {
        return null;
    }
}

function __peopleUpsertSourceRows(app, userId, provider, rows) {
    var collection = app.findCollectionByNameOrId(__peopleSourceCollection);
    var seen = {};
    var created = 0;
    var updated = 0;
    var now = new Date().toISOString();
    for (var i = 0; i < rows.length; i++) {
        var item = rows[i] || {};
        var externalId = String(item.external_id || "").trim();
        if (!externalId) continue;
        seen[externalId] = true;
        var record = __peopleFindSource(app, userId, provider, externalId);
        var isNew = !record;
        if (!record) record = new Record(collection);
        var previousState = String(record.get("import_state") || "unknown");
        record.set("user_id", userId);
        record.set("provider", provider);
        record.set("external_id", externalId);
        record.set("display_name", String(item.display_name || "").trim());
        record.set("avatar_url", String(item.avatar_url || "").trim());
        record.set("avatar_data_uri", "");
        record.set("primary_email", String(item.primary_email || "").trim());
        record.set("primary_phone", String(item.primary_phone || "").trim());
        record.set("birthday_month", item.birthday_month || null);
        record.set("birthday_day", item.birthday_day || null);
        record.set("birthday_year", item.birthday_year || null);
        record.set("source_group", String(item.source_group || "").trim());
        record.set("raw_meta", item.raw_meta || {});
        record.set("last_seen_at", now);
        record.set("archived", false);
        if (isNew || previousState === "unknown") record.set("import_state", "candidate");
        app.save(record);
        if (isNew) created++; else updated++;
    }

    var stale = [];
    try {
        stale = app.findRecordsByFilter(
            __peopleSourceCollection,
            "user_id = {:uid} && provider = {:provider} && archived = false",
            "created",
            10000,
            0,
            { uid: userId, provider: provider }
        );
    } catch (_) {}
    var archived = 0;
    for (var j = 0; j < stale.length; j++) {
        var row = stale[j];
        var external = String(row.get("external_id") || "");
        if (seen[external] || String(row.get("import_state") || "") === "linked") continue;
        row.set("archived", true);
        app.save(row);
        archived++;
    }
    return { total: rows.length, created: created, updated: updated, archived: archived };
}

function __peopleSyncOne(app, connection) {
    var provider = String(connection.get("provider") || "");
    var userId = String(connection.get("user_id") || "");
    if (!provider || !userId) throw new Error("People connection is invalid");
    var cfg = __peopleProviderConfig(app, provider);
    var accessToken = __peopleRefreshAccess(app, connection);
    var identity = __peopleProviderIdentity(provider, accessToken, cfg);
    if (identity.id) connection.set("account_id", identity.id);
    if (identity.label) connection.set("account_label", identity.label);
    var rows;
    if (provider === "google_contacts") rows = __peopleGoogleContacts(accessToken);
    else if (provider === "microsoft") rows = __peopleMicrosoftContacts(accessToken);
    else if (provider === "vk") rows = __peopleVkContacts(accessToken);
    else if (provider === "facebook") rows = __peopleFacebookContacts(accessToken, cfg);
    else throw new Error("Unsupported People provider");
    var result = __peopleUpsertSourceRows(app, userId, provider, rows);
    connection.set("status", "connected");
    connection.set("last_sync_at", new Date().toISOString());
    connection.set("last_error", "");
    app.save(connection);
    return result;
}

function __peopleSyncSafe(app, connection) {
    try {
        connection.set("status", "syncing");
        connection.set("last_error", "");
        app.save(connection);
        return __peopleSyncOne(app, connection);
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        app.save(connection);
        try { app.logger().error("People sync failed", "connection", connection.id, "error", err); } catch (_) {}
        throw err;
    }
}

function __peopleOAuthBegin(e, provider) {
    var cfg;
    try {
        cfg = __peopleProviderConfig(e.app, provider);
        __peopleTokenKey(e.app);
    } catch (_) {
        return e.json(503, { error: "server_not_configured" });
    }
    var connection = __peopleGetConnection(e.app, e.auth.id, provider, true);
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
    if (provider === "google_contacts") {
        values.access_type = "offline";
        values.prompt = "consent";
        values.include_granted_scopes = "true";
    } else if (provider === "microsoft") {
        values.response_mode = "query";
        values.prompt = "select_account";
    } else if (provider === "facebook") {
        values.auth_type = "rerequest";
    } else if (provider === "vk") {
        values.display = "page";
        values.v = __peopleEnv("PEOPLE_VK_API_VERSION") || "5.199";
    }
    return e.json(200, { authorization_url: cfg.authorizeUrl + "?" + __peopleFormEncode(values) });
}

function __peopleOAuthCallback(e, provider) {
    var query = e.requestInfo().query || {};
    var state = String(query.state || "");
    var code = String(query.code || "");
    var providerError = String(query.error || "");
    if (providerError) return e.html(400, "<h1>People connection cancelled</h1><p>The provider did not grant access.</p>");
    if (!state || !code) return e.html(400, "<h1>People connection failed</h1><p>Missing OAuth response.</p>");
    var connection = null;
    try { connection = e.app.findFirstRecordByData(__peopleIntegrationCollection, "oauth_state", state); } catch (_) {}
    if (!connection || String(connection.get("provider") || "") !== provider) {
        return e.html(400, "<h1>People connection failed</h1><p>Invalid authorization state.</p>");
    }
    var expires = __peopleDate(connection.get("oauth_state_expires_at"));
    if (!expires || expires.getTime() < Date.now()) {
        return e.html(400, "<h1>People connection failed</h1><p>Authorization expired.</p>");
    }
    try {
        var cfg = __peopleProviderConfig(e.app, provider);
        var token = __peopleExchangeCode(e.app, provider, code);
        if (!token.access_token) throw new Error("Provider returned no access token");
        var key = __peopleTokenKey(e.app);
        connection.set("access_token_enc", $security.encrypt(String(token.access_token), key));
        var expiresIn = Number(token.expires_in || (cfg.refreshable ? 3600 : 86400 * 30));
        connection.set("access_token_expires_at", new Date(Date.now() + expiresIn * 1000).toISOString());
        if (token.refresh_token) connection.set("refresh_token_enc", $security.encrypt(String(token.refresh_token), key));
        if (cfg.refreshable && !token.refresh_token && !String(connection.get("refresh_token_enc") || "")) {
            throw new Error("Provider returned no refresh token");
        }
        var identity = __peopleProviderIdentity(provider, String(token.access_token), cfg);
        connection.set("account_id", identity.id || "");
        connection.set("account_label", identity.label || provider);
        connection.set("enabled", true);
        connection.set("status", "connected");
        connection.set("oauth_state", "");
        connection.set("oauth_state_expires_at", "");
        connection.set("last_error", "");
        e.app.save(connection);
        try { __peopleSyncSafe(e.app, connection); } catch (_) {}
        var returnUrl = __peopleReturnUrl();
        return e.html(200, "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='2;url=" + returnUrl + "'><title>Life OS</title><h1>People connected</h1><p>Your contacts were indexed for review. Nothing was added to People automatically. You can return to the app.</p>");
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        e.app.save(connection);
        return e.html(500, "<h1>People connection failed</h1><p>Return to Life OS and try again.</p>");
    }
}

routerAdd("GET", "/api/people-integrations/status", function(e) {
    var integrations = [];
    for (var i = 0; i < __peopleProviders.length; i++) {
        var provider = __peopleProviders[i];
        integrations.push(__peopleConnectionPayload(
            e.app,
            __peopleGetConnection(e.app, e.auth.id, provider, false),
            provider
        ));
    }
    return e.json(200, { integrations: integrations });
}, $apis.requireAuth("profiles"));

for (var __peopleRouteIndex = 0; __peopleRouteIndex < __peopleProviders.length; __peopleRouteIndex++) {
    (function(provider) {
        routerAdd("POST", "/api/people-integrations/" + provider + "/connect", function(e) {
            return __peopleOAuthBegin(e, provider);
        }, $apis.requireAuth("profiles"));

        routerAdd("GET", "/api/people-integrations/" + provider + "/callback", function(e) {
            return __peopleOAuthCallback(e, provider);
        });

        routerAdd("POST", "/api/people-integrations/" + provider + "/sync", function(e) {
            var connection = __peopleGetConnection(e.app, e.auth.id, provider, false);
            if (!connection || !String(connection.get("access_token_enc") || "")) {
                return e.json(409, { error: "not_connected" });
            }
            try {
                return e.json(200, { ok: true, result: __peopleSyncSafe(e.app, connection) });
            } catch (_) {
                return e.json(502, { ok: false, error: "provider_sync_failed" });
            }
        }, $apis.requireAuth("profiles"));

        routerAdd("DELETE", "/api/people-integrations/" + provider, function(e) {
            var connection = __peopleGetConnection(e.app, e.auth.id, provider, false);
            if (connection) e.app.delete(connection);
            return e.json(200, { ok: true });
        }, $apis.requireAuth("profiles"));
    })(__peopleProviders[__peopleRouteIndex]);
}

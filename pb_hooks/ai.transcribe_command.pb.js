/// <reference path="../pb_data/types.d.ts" />
// Secure command-mode transcription for Desktop Voice.
// Provider secrets live in server env only — never in Flutter.
//
// Env: OPENAI_API_KEY (optional) — when set, uses OpenAI audio transcription API.
// Deploy: copy pb_hooks/ next to PocketBase executable and restart.

routerAdd("POST", "/api/ai/transcribe-command", (e) => {
    const info = e.requestInfo();
    const auth = info.auth;
    if (!auth || !auth.id) {
        return e.json(401, { "error": "auth_required" });
    }

    const body = info.body || {};
    const audioB64 = body.audio_base64 == null ? "" : String(body.audio_base64);
    if (!audioB64 || audioB64.length < 32) {
        return e.json(400, { "error": "audio_required" });
    }

    const apiKey = $os.getenv("OPENAI_API_KEY");
    if (!apiKey || String(apiKey).trim().length < 8) {
        return e.json(503, { "error": "best_quality_unavailable" });
    }

    const languageHint = body.language_hint == null ? "en" : String(body.language_hint);
    const glossaryTerms = Array.isArray(body.glossary_terms) ? body.glossary_terms : [];
    const glossaryPrompt = body.glossary_prompt == null ? "" : String(body.glossary_prompt);

    let prompt = glossaryPrompt;
    if (!prompt && glossaryTerms.length > 0) {
        prompt = "Command vocabulary: " + glossaryTerms.slice(0, 64).join(", ");
    }
    if (!prompt) {
        prompt = "Price Reporter, Southern Computer Warehouse, DEL MOD, ADD MOD, ADD SIN, Submit, BLINK, Planning.";
    }

    const t0 = Date.now();
    try {
        const res = $http.send({
            url: "https://api.openai.com/v1/audio/transcriptions",
            method: "POST",
            headers: {
                "Authorization": "Bearer " + apiKey,
            },
            body: {
                model: "gpt-4o-mini-transcribe",
                file: $filesystem.fileFromBytes($security.base64Decode(audioB64), "command.wav"),
                language: languageHint.indexOf("-") > 0 ? languageHint.split("-")[0] : languageHint,
                prompt: prompt,
            },
            timeout: 25,
        });

        const latencyMs = Date.now() - t0;
        if (res.statusCode < 200 || res.statusCode >= 300) {
            return e.json(503, {
                "error": "provider_error",
                "status": res.statusCode,
                "latency_ms": latencyMs,
            });
        }

        const rawBody = res.raw;
        let parsed = {};
        try {
            parsed = JSON.parse(rawBody);
        } catch (_) {
            return e.json(502, { "error": "invalid_provider_response", "latency_ms": latencyMs });
        }

        const rawTranscript = parsed.text == null ? "" : String(parsed.text).trim();
        if (!rawTranscript) {
            return e.json(502, { "error": "empty_transcript", "latency_ms": latencyMs });
        }

        return e.json(200, {
            "raw_transcript": rawTranscript,
            "transcript": rawTranscript,
            "model": "gpt-4o-mini-transcribe",
            "provider": "openai",
            "latency_ms": latencyMs,
        });
    } catch (err) {
        return e.json(503, {
            "error": "best_quality_unavailable",
            "detail": String(err),
            "latency_ms": Date.now() - t0,
        });
    }
});

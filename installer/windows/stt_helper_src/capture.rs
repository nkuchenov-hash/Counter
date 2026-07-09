//! CPAL/WASAPI microphone capture for Counter Desktop Voice.
//! Handy/GOLOS parity: device-native F32 (preferred) via cpal default host (WASAPI on Windows).

#[cfg(windows)]
#[path = "win_audio_endpoint.rs"]
mod win_audio_endpoint;

#[cfg(not(windows))]
mod win_audio_endpoint {
    use serde::Serialize;
    #[derive(Clone, Debug, Serialize)]
    pub struct EndpointDiag {
        pub device_id: String,
        pub friendly_name: String,
        pub role: String,
        pub volume_scalar: Option<f32>,
        pub muted: bool,
    }
    #[derive(Clone, Debug, Serialize)]
    pub struct CaptureEndpointReport {
        pub console_default: Option<EndpointDiag>,
        pub communications_default: Option<EndpointDiag>,
        pub selected_role: String,
        pub selected_device_id: String,
        pub selected_device_name: String,
        pub endpoint_volume: Option<f32>,
        pub endpoint_muted: bool,
        pub session_volume: Option<f32>,
        pub mic_boost_db: Option<f32>,
        pub enhancements_enabled: Option<bool>,
        pub enhancements_notes: String,
        pub raw_capture_likely_bypasses_enhancements: bool,
        pub mix_sample_rate: Option<u32>,
        pub mix_channels: Option<u16>,
        pub mix_sample_format: Option<String>,
        pub cpal_device_name: String,
        pub cpal_host_id: String,
    }
    pub fn build_endpoint_report(
        _: &str,
        cpal_device_name: &str,
        cpal_host_id: &str,
        mix_rate: Option<u32>,
        mix_channels: Option<u16>,
        mix_format: Option<&str>,
    ) -> CaptureEndpointReport {
        CaptureEndpointReport {
            console_default: None,
            communications_default: None,
            selected_role: "console".into(),
            selected_device_id: String::new(),
            selected_device_name: cpal_device_name.to_string(),
            endpoint_volume: None,
            endpoint_muted: false,
            session_volume: None,
            mic_boost_db: None,
            enhancements_enabled: None,
            enhancements_notes: "non_windows_stub".into(),
            raw_capture_likely_bypasses_enhancements: false,
            mix_sample_rate: mix_rate,
            mix_channels: mix_channels,
            mix_sample_format: mix_format.map(|s| s.to_string()),
            cpal_device_name: cpal_device_name.to_string(),
            cpal_host_id: cpal_host_id.to_string(),
        }
    }
    pub async fn device_diag_http() -> actix_web::HttpResponse {
        actix_web::HttpResponse::Ok().json(serde_json::json!({"ok": false, "error": "non_windows"}))
    }
}

use actix_web::{web, HttpResponse};
use base64::{engine::general_purpose::STANDARD, Engine as _};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{BufferSize, SampleFormat, StreamConfig};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

const MANUAL_STOP_POST_ROLL_MS: u64 = 180;
const STREAM_DRAIN_MS: u64 = 30;

struct ActiveCapture {
    raw_f32: Arc<Mutex<Vec<f32>>>,
    running: Arc<AtomicBool>,
    level: Arc<Mutex<f32>>,
    level_rms: Arc<Mutex<f32>>,
    sample_rate: u32,
    channels: u16,
    sample_format: String,
    device_name: String,
    host_id: String,
    endpoint_report: win_audio_endpoint::CaptureEndpointReport,
    _stream: cpal::Stream,
}

#[derive(Clone, Debug, Serialize)]
struct CaptureGainDiag {
    capture_gain_mode: String,
    capture_gain_db: f32,
    agc_enabled: bool,
    limiter_enabled: bool,
    raw_rms: f32,
    raw_peak: f32,
    processed_rms: f32,
    processed_peak: f32,
    clipped_samples: u32,
    selected_gain_reason: String,
}

impl CaptureGainDiag {
    fn disabled(raw_rms: f32, raw_peak: f32, processed_rms: f32, processed_peak: f32) -> Self {
        Self {
            capture_gain_mode: "off".into(),
            capture_gain_db: 0.0,
            agc_enabled: false,
            limiter_enabled: false,
            raw_rms,
            raw_peak,
            processed_rms,
            processed_peak,
            clipped_samples: 0,
            selected_gain_reason: "capture_gain_experiment_disabled".into(),
        }
    }
}

#[derive(Deserialize)]
struct CaptureStartRequest {
    endpoint_role: Option<String>,
}

fn open_input_device(host: &cpal::Host, preferred_name: &str) -> Result<cpal::Device, String> {
    if !preferred_name.is_empty() {
        if let Ok(devices) = host.input_devices() {
            for device in devices {
                if let Ok(name) = device.name() {
                    if name == preferred_name {
                        eprintln!("[capture] DESKTOP_VOICE_CAPTURE_ENDPOINT_SELECTED device={name}");
                        return Ok(device);
                    }
                }
            }
            eprintln!(
                "[capture] DESKTOP_VOICE_CAPTURE_ENDPOINT_FALLBACK_READY preferred={preferred_name} not in cpal list"
            );
        }
    }
    host.default_input_device()
        .ok_or_else(|| "no default input device".to_string())
}

fn apply_capture_gain_stt(stt: &mut [f32], raw_rms: f32, raw_peak: f32) -> CaptureGainDiag {
    let (stt_rms, stt_peak) = float_rms_peak(stt);
    let enabled = std::env::var("COUNTER_CAPTURE_GAIN_EXPERIMENT")
        .ok()
        .as_deref()
        == Some("1");
    if !enabled || stt.is_empty() {
        return CaptureGainDiag::disabled(raw_rms, raw_peak, stt_rms, stt_peak);
    }
    const TARGET_RMS: f32 = 0.058;
    const PEAK_CEILING: f32 = 0.90;
    if stt_rms <= 0.0001 {
        return CaptureGainDiag::disabled(raw_rms, raw_peak, stt_rms, stt_peak);
    }
    let mut gain = TARGET_RMS / stt_rms;
    if stt_peak * gain > PEAK_CEILING {
        gain = PEAK_CEILING / stt_peak.max(0.0001);
    }
    let gain_db = 20.0 * (gain.max(0.0001)).log10();
    let mut clipped = 0u32;
    for s in stt.iter_mut() {
        let v = (*s * gain).clamp(-PEAK_CEILING, PEAK_CEILING);
        if v.abs() >= PEAK_CEILING - 0.0001 {
            clipped += 1;
        }
        *s = v;
    }
    let (processed_rms, processed_peak) = float_rms_peak(stt);
    eprintln!(
        "[capture] DESKTOP_VOICE_CAPTURE_GAIN_EXPERIMENT_READY \
         DESKTOP_VOICE_CAPTURE_GAIN_NOT_COUNTED_AS_RAW_CAPTURE_PARITY \
         DESKTOP_VOICE_RAW_WAV_UNCHANGED gain_db={gain_db:.2}"
    );
    CaptureGainDiag {
        capture_gain_mode: "stt_copy_rms_target_058".into(),
        capture_gain_db: gain_db,
        agc_enabled: false,
        limiter_enabled: true,
        raw_rms,
        raw_peak,
        processed_rms,
        processed_peak,
        clipped_samples: clipped,
        selected_gain_reason: "handy_baseline_rms_experiment_new_capture_only".into(),
    }
}

// SAFETY: cpal::Stream on Windows WASAPI is Send+Sync for our use.
unsafe impl Send for ActiveCapture {}
unsafe impl Sync for ActiveCapture {}

impl Drop for ActiveCapture {
    fn drop(&mut self) {
        self.running.store(false, Ordering::SeqCst);
    }
}

fn capture_slot() -> &'static Mutex<Option<ActiveCapture>> {
    static SLOT: std::sync::OnceLock<Mutex<Option<ActiveCapture>>> = std::sync::OnceLock::new();
    SLOT.get_or_init(|| Mutex::new(None))
}

fn float_rms_peak(samples: &[f32]) -> (f32, f32) {
    if samples.is_empty() {
        return (0.0, 0.0);
    }
    let mut sum = 0.0f32;
    let mut peak = 0.0f32;
    for &s in samples {
        let a = s.abs();
        if a > peak {
            peak = a;
        }
        sum += s * s;
    }
    ((sum / samples.len() as f32).sqrt(), peak)
}

fn downmix_interleaved_avg(input: &[f32], channels: u16) -> Vec<f32> {
    if channels <= 1 {
        return input.to_vec();
    }
    let ch = channels as usize;
    let frames = input.len() / ch;
    let mut out = Vec::with_capacity(frames);
    for f in 0..frames {
        let mut sum = 0.0f32;
        for c in 0..ch {
            sum += input[f * ch + c];
        }
        out.push((sum / ch as f32).clamp(-1.0, 1.0));
    }
    out
}

/// Windowed-sinc-ish quality is handled in Dart for parity tests; helper uses
/// linear resample for the STT buffer (same as GOLOS live path). Raw buffer
/// stays at native rate for diagnostics.
fn resample_linear(mono: &[f32], from_rate: u32, to_rate: u32) -> Vec<f32> {
    if from_rate == to_rate || mono.is_empty() {
        return mono.to_vec();
    }
    let ratio = from_rate as f64 / to_rate as f64;
    let out_len = ((mono.len() as f64) / ratio).floor() as usize;
    let mut out = Vec::with_capacity(out_len);
    for i in 0..out_len {
        let src = i as f64 * ratio;
        let si = src as usize;
        let sf = (src - si as f64) as f32;
        let a = mono.get(si).copied().unwrap_or(0.0);
        let b = mono.get(si + 1).copied().unwrap_or(0.0);
        out.push((a + (b - a) * sf).clamp(-1.0, 1.0));
    }
    out
}

fn float_to_pcm16_bytes(samples: &[f32]) -> Vec<u8> {
    let mut out = Vec::with_capacity(samples.len() * 2);
    for &s in samples {
        let v = (s.clamp(-1.0, 1.0) * 32767.0).round() as i16;
        out.extend_from_slice(&v.to_le_bytes());
    }
    out
}

fn write_wav_pcm16(path: &std::path::Path, pcm: &[u8], sample_rate: u32, channels: u16) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let spec = hound::WavSpec {
        channels,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut writer = hound::WavWriter::create(path, spec).map_err(|e| e.to_string())?;
    for chunk in pcm.chunks_exact(2) {
        let s = i16::from_le_bytes([chunk[0], chunk[1]]);
        writer.write_sample(s).map_err(|e| e.to_string())?;
    }
    writer.finalize().map_err(|e| e.to_string())?;
    Ok(())
}

fn default_voice_samples_dir() -> std::path::PathBuf {
    let base = std::env::var("LOCALAPPDATA").unwrap_or_else(|_| std::env::temp_dir().display().to_string());
    std::path::PathBuf::from(base).join("Counter").join("voice_samples")
}

fn append_converted(
    raw: &Arc<Mutex<Vec<f32>>>,
    level_peak: &Arc<Mutex<f32>>,
    level_rms: &Arc<Mutex<f32>>,
    converted: &[f32],
) {
    if converted.is_empty() {
        return;
    }
    let (rms, peak) = float_rms_peak(converted);
    if let Ok(mut v) = level_peak.lock() {
        *v = peak.clamp(0.0, 1.0);
    }
    if let Ok(mut v) = level_rms.lock() {
        *v = rms.clamp(0.0, 1.0);
    }
    if let Ok(mut buf) = raw.lock() {
        buf.extend_from_slice(converted);
    }
}

fn start_cpal_capture(endpoint_role: &str) -> Result<ActiveCapture, String> {
    let host = cpal::default_host();
    let host_id = format!("{:?}", host.id());
    let probe = win_audio_endpoint::build_endpoint_report(
        endpoint_role,
        "",
        &host_id,
        None,
        None,
        None,
    );
    let preferred_name = probe.selected_device_name.clone();
    let device = open_input_device(&host, &preferred_name)?;
    let device_name = device
        .name()
        .unwrap_or_else(|_| "default".to_string());
    let def = device
        .default_input_config()
        .map_err(|e| format!("default_input_config: {e}"))?;
    let native_rate = def.sample_rate().0;
    let channels = def.channels();
    let sample_format = def.sample_format();
    let format_name = format!("{sample_format:?}");
    let endpoint_report = win_audio_endpoint::build_endpoint_report(
        endpoint_role,
        &device_name,
        &host_id,
        Some(native_rate),
        Some(channels),
        Some(&format_name),
    );
    eprintln!(
        "[capture] DESKTOP_VOICE_CAPTURE_ENDPOINT_ROLE_SELECTED role={}",
        endpoint_report.selected_role,
    );
    let config = StreamConfig {
        channels,
        sample_rate: def.sample_rate(),
        buffer_size: BufferSize::Default,
    };

    let raw_f32 = Arc::new(Mutex::new(Vec::<f32>::with_capacity(
        (native_rate as usize) * (channels as usize) * 30,
    )));
    let running = Arc::new(AtomicBool::new(true));
    let level = Arc::new(Mutex::new(0.0f32));
    let level_rms = Arc::new(Mutex::new(0.0f32));

    let stream = match sample_format {
        SampleFormat::F32 => {
            let buf = Arc::clone(&raw_f32);
            let lvl = Arc::clone(&level);
            let lvl_rms = Arc::clone(&level_rms);
            device.build_input_stream(
                &config,
                move |input: &[f32], _| {
                    append_converted(&buf, &lvl, &lvl_rms, input);
                },
                |err| eprintln!("[cpal] stream error: {err}"),
                None,
            )
        }
        SampleFormat::I16 => {
            let buf = Arc::clone(&raw_f32);
            let lvl = Arc::clone(&level);
            let lvl_rms = Arc::clone(&level_rms);
            device.build_input_stream(
                &config,
                move |input: &[i16], _| {
                    let converted: Vec<f32> = input
                        .iter()
                        .map(|s| (*s as f32 / i16::MAX as f32).clamp(-1.0, 1.0))
                        .collect();
                    append_converted(&buf, &lvl, &lvl_rms, &converted);
                },
                |err| eprintln!("[cpal] stream error: {err}"),
                None,
            )
        }
        SampleFormat::U16 => {
            let buf = Arc::clone(&raw_f32);
            let lvl = Arc::clone(&level);
            let lvl_rms = Arc::clone(&level_rms);
            device.build_input_stream(
                &config,
                move |input: &[u16], _| {
                    let converted: Vec<f32> = input
                        .iter()
                        .map(|s| ((*s as f32 / u16::MAX as f32) * 2.0 - 1.0).clamp(-1.0, 1.0))
                        .collect();
                    append_converted(&buf, &lvl, &lvl_rms, &converted);
                },
                |err| eprintln!("[cpal] stream error: {err}"),
                None,
            )
        }
        other => return Err(format!("unsupported sample format: {other:?}")),
    }
    .map_err(|e| format!("build_input_stream: {e}"))?;

    stream.play().map_err(|e| format!("stream.play: {e}"))?;
    eprintln!(
        "[capture] cpal host={host_id} device={device_name} rate={native_rate} ch={channels} fmt={format_name}"
    );

    Ok(ActiveCapture {
        raw_f32,
        running,
        level,
        level_rms,
        sample_rate: native_rate,
        channels,
        sample_format: format_name,
        device_name,
        host_id,
        endpoint_report,
        _stream: stream,
    })
}

#[derive(Serialize)]
struct CaptureStopResponse {
    ok: bool,
    capture_backend: String,
    capture_api: String,
    raw_capture_format: String,
    raw_capture_sample_rate: u32,
    raw_capture_channels: u16,
    raw_capture_rms: f32,
    raw_capture_peak: f32,
    processed_wav_rms: f32,
    processed_wav_peak: f32,
    device_name: String,
    session_volume: Option<f32>,
    endpoint_volume: Option<f32>,
    endpoint_id: Option<String>,
    endpoint_role: Option<String>,
    endpoint_muted: Option<bool>,
    console_default_device: Option<String>,
    communications_default_device: Option<String>,
    mic_boost_db: Option<f32>,
    enhancements_notes: Option<String>,
    capture_gain_mode: String,
    capture_gain_db: f32,
    agc_enabled: bool,
    limiter_enabled: bool,
    clipped_samples: u32,
    selected_gain_reason: String,
    endpoint_report: win_audio_endpoint::CaptureEndpointReport,
    raw_wav_path: String,
    stt_wav_path: String,
    /// Small STT PCM16 payload (16 kHz mono) for in-process transcribe without re-read.
    stt_pcm16_base64: String,
    stt_sample_rate: u32,
    stt_channels: u16,
    duration_ms: u32,
    audio_level_seen: bool,
}

pub async fn capture_start(body: Option<web::Json<CaptureStartRequest>>) -> HttpResponse {
    // Drop any previous session.
    {
        let mut slot = capture_slot().lock().unwrap_or_else(|e| e.into_inner());
        if let Some(prev) = slot.take() {
            prev.running.store(false, Ordering::SeqCst);
            drop(prev);
        }
    }

    let role = body
        .and_then(|b| b.endpoint_role.clone())
        .unwrap_or_else(|| "auto".to_string());

    match start_cpal_capture(&role) {
        Ok(session) => {
            let ep = &session.endpoint_report;
            let body = json!({
                "ok": true,
                "capture_backend": "cpal_wasapi",
                "capture_api": session.host_id,
                "raw_capture_format": session.sample_format,
                "raw_capture_sample_rate": session.sample_rate,
                "raw_capture_channels": session.channels,
                "device_name": session.device_name,
                "f32_available": session.sample_format.contains("F32"),
                "endpoint_id": ep.selected_device_id,
                "endpoint_role": ep.selected_role,
                "endpoint_volume": ep.endpoint_volume,
                "endpoint_muted": ep.endpoint_muted,
                "session_volume": ep.session_volume,
                "console_default_device": ep.console_default.as_ref().map(|c| &c.friendly_name),
                "communications_default_device": ep.communications_default.as_ref().map(|c| &c.friendly_name),
                "mix_sample_rate": ep.mix_sample_rate,
                "mix_channels": ep.mix_channels,
                "mix_sample_format": ep.mix_sample_format,
                "enhancements_notes": ep.enhancements_notes,
                "raw_capture_likely_bypasses_enhancements": ep.raw_capture_likely_bypasses_enhancements,
                "endpoint_report": ep,
            });
            *capture_slot().lock().unwrap_or_else(|e| e.into_inner()) = Some(session);
            HttpResponse::Ok().json(body)
        }
        Err(e) => HttpResponse::InternalServerError().json(json!({
            "ok": false,
            "error": e,
            "capture_backend": "cpal_wasapi",
        })),
    }
}

pub async fn capture_level() -> HttpResponse {
    let slot = capture_slot().lock().unwrap_or_else(|e| e.into_inner());
    match slot.as_ref() {
        Some(s) => {
            let level = s.level.lock().map(|v| *v).unwrap_or(0.0);
            let rms = s.level_rms.lock().map(|v| *v).unwrap_or(0.0);
            HttpResponse::Ok().json(json!({
                "ok": true,
                "level": level,
                "peak": level,
                "rms": rms,
                "capturing": s.running.load(Ordering::Relaxed),
            }))
        }
        None => HttpResponse::Ok().json(json!({
            "ok": false,
            "level": 0.0,
            "peak": 0.0,
            "rms": 0.0,
            "capturing": false,
        })),
    }
}

/// Snapshot of current capture → 16 kHz mono PCM16 for mid-listen partial STT.
/// Used so whisper-tiny can produce an early candidate before stop.
pub async fn capture_partial_pcm() -> HttpResponse {
    let slot = capture_slot().lock().unwrap_or_else(|e| e.into_inner());
    let Some(s) = slot.as_ref() else {
        return HttpResponse::Ok().json(json!({
            "ok": false,
            "pcm16_base64": "",
            "samples": 0,
        }));
    };
    let raw = s
        .raw_f32
        .lock()
        .map(|v| v.clone())
        .unwrap_or_default();
    let sample_rate = s.sample_rate;
    let channels = s.channels;
    drop(slot);
    if raw.is_empty() || sample_rate == 0 || channels == 0 {
        return HttpResponse::Ok().json(json!({
            "ok": true,
            "pcm16_base64": "",
            "samples": 0,
        }));
    }
    let mono = downmix_interleaved_avg(&raw, channels);
    let stt = resample_linear(&mono, sample_rate, 16_000);
    // Cap to last ~4.5s so mid-listen partial stays command-sized.
    let max_samples = 16_000 * 45 / 10;
    let trimmed = if stt.len() > max_samples {
        stt[stt.len() - max_samples..].to_vec()
    } else {
        stt
    };
    let pcm = float_to_pcm16_bytes(&trimmed);
    HttpResponse::Ok().json(json!({
        "ok": true,
        "pcm16_base64": STANDARD.encode(&pcm),
        "samples": trimmed.len(),
        "sample_rate": 16000,
    }))
}

pub async fn capture_stop() -> HttpResponse {
    let session = {
        let mut slot = capture_slot().lock().unwrap_or_else(|e| e.into_inner());
        slot.take()
    };
    let Some(session) = session else {
        return HttpResponse::BadRequest().json(json!({
            "ok": false,
            "error": "no active capture",
        }));
    };

    // GOLOS/Handy post-roll so trailing phonemes are not clipped.
    tokio::time::sleep(Duration::from_millis(MANUAL_STOP_POST_ROLL_MS)).await;
    tokio::time::sleep(Duration::from_millis(STREAM_DRAIN_MS)).await;
    session.running.store(false, Ordering::SeqCst);

    let sample_rate = session.sample_rate;
    let channels = session.channels;
    let sample_format = session.sample_format.clone();
    let device_name = session.device_name.clone();
    let host_id = session.host_id.clone();
    let endpoint_report = session.endpoint_report.clone();
    let raw = session
        .raw_f32
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .clone();
    drop(session); // drops WASAPI stream

    let (raw_rms, raw_peak) = float_rms_peak(&raw);
    let mono = downmix_interleaved_avg(&raw, channels);
    let mut stt = resample_linear(&mono, sample_rate, 16_000);
    let gain_diag = apply_capture_gain_stt(&mut stt, raw_rms, raw_peak);
    let (stt_rms, stt_peak) = float_rms_peak(&stt);
    let duration_ms = if sample_rate > 0 && channels > 0 {
        ((raw.len() as u64) * 1000) / ((sample_rate as u64) * (channels as u64))
    } else {
        0
    } as u32;

    let raw_pcm16 = float_to_pcm16_bytes(&raw);
    let stt_pcm16 = float_to_pcm16_bytes(&stt);
    let dir = default_voice_samples_dir();
    let raw_path = dir.join("latest_command_raw.wav");
    let stt_path = dir.join("latest_command.wav");
    if let Err(e) = write_wav_pcm16(&raw_path, &raw_pcm16, sample_rate, channels) {
        return HttpResponse::InternalServerError().json(json!({
            "ok": false,
            "error": format!("write raw wav: {e}"),
        }));
    }
    if let Err(e) = write_wav_pcm16(&stt_path, &stt_pcm16, 16_000, 1) {
        return HttpResponse::InternalServerError().json(json!({
            "ok": false,
            "error": format!("write stt wav: {e}"),
        }));
    }

    let resp = CaptureStopResponse {
        ok: true,
        capture_backend: "cpal_wasapi".into(),
        capture_api: host_id,
        raw_capture_format: sample_format,
        raw_capture_sample_rate: sample_rate,
        raw_capture_channels: channels,
        raw_capture_rms: raw_rms,
        raw_capture_peak: raw_peak,
        processed_wav_rms: stt_rms,
        processed_wav_peak: stt_peak,
        device_name,
        session_volume: endpoint_report.session_volume,
        endpoint_volume: endpoint_report.endpoint_volume,
        endpoint_id: Some(endpoint_report.selected_device_id.clone()),
        endpoint_role: Some(endpoint_report.selected_role.clone()),
        endpoint_muted: Some(endpoint_report.endpoint_muted),
        console_default_device: endpoint_report
            .console_default
            .as_ref()
            .map(|c| c.friendly_name.clone()),
        communications_default_device: endpoint_report
            .communications_default
            .as_ref()
            .map(|c| c.friendly_name.clone()),
        mic_boost_db: endpoint_report.mic_boost_db,
        enhancements_notes: Some(endpoint_report.enhancements_notes.clone()),
        capture_gain_mode: gain_diag.capture_gain_mode,
        capture_gain_db: gain_diag.capture_gain_db,
        agc_enabled: gain_diag.agc_enabled,
        limiter_enabled: gain_diag.limiter_enabled,
        clipped_samples: gain_diag.clipped_samples,
        selected_gain_reason: gain_diag.selected_gain_reason,
        endpoint_report,
        raw_wav_path: raw_path.display().to_string(),
        stt_wav_path: stt_path.display().to_string(),
        stt_pcm16_base64: STANDARD.encode(&stt_pcm16),
        stt_sample_rate: 16_000,
        stt_channels: 1,
        duration_ms,
        audio_level_seen: raw_peak >= 0.008 || raw_rms >= 0.008,
    };
    HttpResponse::Ok().json(resp)
}

pub async fn capture_cancel() -> HttpResponse {
    let mut slot = capture_slot().lock().unwrap_or_else(|e| e.into_inner());
    if let Some(prev) = slot.take() {
        prev.running.store(false, Ordering::SeqCst);
        drop(prev);
    }
    HttpResponse::Ok().json(json!({ "ok": true }))
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.route("/capture/start", web::post().to(capture_start))
        .route("/capture/stop", web::post().to(capture_stop))
        .route("/capture/level", web::get().to(capture_level))
        .route("/capture/partial_pcm", web::get().to(capture_partial_pcm))
        .route("/capture/cancel", web::post().to(capture_cancel))
        .route("/capture/device_diag", web::get().to(win_audio_endpoint::device_diag_http));
}

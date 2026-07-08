//! CPAL/WASAPI microphone capture for Counter Desktop Voice.
//! Handy/GOLOS parity: device-native F32 (preferred) via cpal default host (WASAPI on Windows).

use actix_web::{web, HttpResponse};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{BufferSize, SampleFormat, StreamConfig};
use serde::Serialize;
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
    _stream: cpal::Stream,
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

fn start_cpal_capture() -> Result<ActiveCapture, String> {
    let host = cpal::default_host();
    let host_id = format!("{:?}", host.id());
    let device = host
        .default_input_device()
        .ok_or_else(|| "no default input device".to_string())?;
    let device_name = device
        .name()
        .unwrap_or_else(|_| "default".to_string());
    let def = device
        .default_input_config()
        .map_err(|e| format!("default_input_config: {e}"))?;
    let native_rate = def.sample_rate().0;
    let channels = def.channels();
    let sample_format = def.sample_format();
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
    let format_name = format!("{sample_format:?}");

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
    raw_wav_path: String,
    stt_wav_path: String,
    /// Small STT PCM16 payload (16 kHz mono) for in-process transcribe without re-read.
    stt_pcm16_base64: String,
    stt_sample_rate: u32,
    stt_channels: u16,
    duration_ms: u32,
    audio_level_seen: bool,
}

pub async fn capture_start() -> HttpResponse {
    // Drop any previous session.
    {
        let mut slot = capture_slot().lock().unwrap_or_else(|e| e.into_inner());
        if let Some(prev) = slot.take() {
            prev.running.store(false, Ordering::SeqCst);
            drop(prev);
        }
    }

    match start_cpal_capture() {
        Ok(session) => {
            let body = json!({
                "ok": true,
                "capture_backend": "cpal_wasapi",
                "capture_api": session.host_id,
                "raw_capture_format": session.sample_format,
                "raw_capture_sample_rate": session.sample_rate,
                "raw_capture_channels": session.channels,
                "device_name": session.device_name,
                "f32_available": session.sample_format.contains("F32"),
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
    let raw = session
        .raw_f32
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .clone();
    drop(session); // drops WASAPI stream

    let (raw_rms, raw_peak) = float_rms_peak(&raw);
    let mono = downmix_interleaved_avg(&raw, channels);
    let stt = resample_linear(&mono, sample_rate, 16_000);
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
        session_volume: None,
        endpoint_volume: None,
        raw_wav_path: raw_path.display().to_string(),
        stt_wav_path: stt_path.display().to_string(),
        stt_pcm16_base64: String::new(),
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
        .route("/capture/cancel", web::post().to(capture_cancel));
}

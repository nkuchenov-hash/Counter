//! Same-WAV STT replay — GOLOS-equivalent vs Counter-equivalent pipelines (raw Parakeet only).
use hound::WavReader;
use serde::Serialize;
use std::env;
use std::path::PathBuf;
use std::time::Instant;
use transcribe_rs::onnx::parakeet::{ParakeetModel, ParakeetParams};
use transcribe_rs::onnx::Quantization;

const VAD_SAMPLE_RATE: usize = 16_000;
const VAD_WINDOW_MS: usize = 30;
const VAD_RMS_THRESHOLD: f32 = 0.01;

#[derive(Clone, Copy)]
enum VadMode {
    Golos,
    CounterLegacy,
    None,
}

struct VadConfig {
    pad_ms: usize,
    tail_keep_ms: usize,
}

fn vad_config(mode: VadMode) -> Option<VadConfig> {
    match mode {
        VadMode::Golos => Some(VadConfig {
            pad_ms: 350,
            tail_keep_ms: 700,
        }),
        VadMode::CounterLegacy => Some(VadConfig {
            pad_ms: 200,
            tail_keep_ms: 0,
        }),
        VadMode::None => None,
    }
}

fn vad_find_speech(audio: &[f32]) -> Option<(usize, usize)> {
    let win = VAD_WINDOW_MS * VAD_SAMPLE_RATE / 1000;
    if audio.len() < win {
        return None;
    }
    let n_windows = (audio.len() - win) / win + 1;
    let mut first: Option<usize> = None;
    let mut last: Option<usize> = None;
    for wi in 0..n_windows {
        let s = wi * win;
        let e = (s + win).min(audio.len());
        let rms = (audio[s..e].iter().map(|x| x * x).sum::<f32>() / (e - s) as f32).sqrt();
        if rms > VAD_RMS_THRESHOLD {
            if first.is_none() {
                first = Some(s);
            }
            last = Some(e);
        }
    }
    Some((first?, last?))
}

fn trim_silence(audio: &[f32], cfg: &VadConfig) -> Vec<f32> {
    let pad = cfg.pad_ms * VAD_SAMPLE_RATE / 1000;
    let tail_keep = cfg.tail_keep_ms * VAD_SAMPLE_RATE / 1000;
    match vad_find_speech(audio) {
        None => audio.to_vec(),
        Some((start, end)) => {
            let s = start.saturating_sub(pad);
            let preserve_from = audio.len().saturating_sub(tail_keep);
            let e = (end + pad).max(preserve_from).min(audio.len());
            audio[s..e].to_vec()
        }
    }
}

fn read_wav_f32(path: &str) -> Result<(Vec<f32>, u32), String> {
    let mut reader = WavReader::open(path).map_err(|e| format!("wav open: {e}"))?;
    let spec = reader.spec();
    if spec.channels != 1 {
        return Err(format!("expected mono wav, got {} channels", spec.channels));
    }
    let rate = spec.sample_rate;
    let samples: Vec<f32> = match spec.sample_format {
        hound::SampleFormat::Int => reader
            .samples::<i32>()
            .map(|s| s.map_err(|e| format!("sample: {e}")))
            .collect::<Result<Vec<_>, _>>()?
            .into_iter()
            .map(|s| {
                let denom = 2f32.powi(spec.bits_per_sample as i32 - 1);
                s as f32 / denom
            })
            .collect(),
        hound::SampleFormat::Float => reader
            .samples::<f32>()
            .map(|s| s.map_err(|e| format!("sample: {e}")))
            .collect::<Result<Vec<_>, _>>()?,
    };
    Ok((samples, rate))
}

fn resample_linear(input: &[f32], from_rate: u32, to_rate: u32) -> Vec<f32> {
    if from_rate == to_rate || input.is_empty() {
        return input.to_vec();
    }
    let out_len = ((input.len() as f64) * (to_rate as f64) / (from_rate as f64)).ceil() as usize;
    let mut out = Vec::with_capacity(out_len);
    for i in 0..out_len {
        let src_pos = (i as f64) * (from_rate as f64) / (to_rate as f64);
        let idx = src_pos.floor() as usize;
        let frac = (src_pos - idx as f64) as f32;
        let a = input[idx.min(input.len() - 1)];
        let b = input[(idx + 1).min(input.len() - 1)];
        out.push(a + (b - a) * frac);
    }
    out
}

fn peak_level(samples: &[f32]) -> f32 {
    samples.iter().fold(0.0f32, |m, s| m.max(s.abs()))
}

fn rms_level(samples: &[f32]) -> f32 {
    if samples.is_empty() {
        return 0.0;
    }
    (samples.iter().map(|x| x * x).sum::<f32>() / samples.len() as f32).sqrt()
}

fn normalize_peak(samples: &[f32], target: f32) -> Vec<f32> {
    let peak = peak_level(samples);
    if peak < 0.05 || peak >= target {
        return samples.to_vec();
    }
    let gain = target / peak;
    samples.iter().map(|s| (s * gain).clamp(-1.0, 1.0)).collect()
}

#[derive(Serialize)]
struct ReplayResult {
    pipeline: String,
    wav_path: String,
    model_dir: String,
    duration_ms: u64,
    sample_rate: u32,
    rms: f32,
    peak: f32,
    vad_mode: String,
    peak_normalized: bool,
    trimmed_duration_ms: u64,
    raw_transcript: String,
    latency_ms: u64,
}

fn run_pipeline(
    model: &mut ParakeetModel,
    audio: &[f32],
    vad_mode: VadMode,
    peak_norm: bool,
    pipeline_name: &str,
    wav_path: &str,
    model_dir: &str,
    sample_rate: u32,
) -> Result<ReplayResult, String> {
    let mut working = audio.to_vec();
    let peak_normalized = if peak_norm {
        let normed = normalize_peak(&working, 0.85);
        let applied = peak_level(&normed) > peak_level(&working) + 0.001;
        working = normed;
        applied
    } else {
        false
    };

    let trimmed = match vad_config(vad_mode) {
        Some(cfg) => trim_silence(&working, &cfg),
        None => working,
    };

    let t0 = Instant::now();
    let text = model
        .transcribe_with(&trimmed, &ParakeetParams::default())
        .map_err(|e| format!("parakeet: {e}"))?
        .text;
    let latency_ms = t0.elapsed().as_millis() as u64;

    Ok(ReplayResult {
        pipeline: pipeline_name.to_string(),
        wav_path: wav_path.to_string(),
        model_dir: model_dir.to_string(),
        duration_ms: (audio.len() as u64) * 1000 / VAD_SAMPLE_RATE as u64,
        sample_rate,
        rms: rms_level(audio),
        peak: peak_level(audio),
        vad_mode: match vad_mode {
            VadMode::Golos => "golos_350pad_700tail",
            VadMode::CounterLegacy => "counter_legacy_200pad",
            VadMode::None => "none",
        }
        .to_string(),
        peak_normalized,
        trimmed_duration_ms: (trimmed.len() as u64) * 1000 / VAD_SAMPLE_RATE as u64,
        raw_transcript: text.trim().to_string(),
        latency_ms,
    })
}

fn default_model_dir() -> PathBuf {
    PathBuf::from(r"C:\Users\nkuch\Development\Apps\golos_flutter\Release\models\parakeet")
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let wav_path = args
        .iter()
        .position(|a| a == "--wav")
        .and_then(|i| args.get(i + 1))
        .cloned()
        .unwrap_or_else(|| {
            "test/fixtures/desktop_voice_wav/scw_delmod_submit_real_2026_07_07.wav".to_string()
        });
    let model_dir = args
        .iter()
        .position(|a| a == "--model-dir")
        .and_then(|i| args.get(i + 1))
        .cloned()
        .map(PathBuf::from)
        .unwrap_or_else(default_model_dir);

    let (mut audio, rate) = read_wav_f32(&wav_path).unwrap_or_else(|e| {
        eprintln!("{e}");
        std::process::exit(1);
    });
    if rate != 16_000 {
        audio = resample_linear(&audio, rate, 16_000);
    }

    let mut model = ParakeetModel::load(&model_dir, &Quantization::Int8)
        .unwrap_or_else(|e| {
            eprintln!("model load failed: {e}");
            std::process::exit(2);
        });

    let pipelines = [
        ("golos_equivalent", VadMode::Golos, false),
        ("golos_equivalent_peak_norm", VadMode::Golos, true),
        ("counter_legacy_vad", VadMode::CounterLegacy, false),
        ("counter_helper_current", VadMode::Golos, true), // current counter: golos vad + peak norm
        ("no_vad", VadMode::None, false),
    ];

    let mut results = Vec::new();
    for (name, vad, peak) in pipelines {
        match run_pipeline(
            &mut model,
            &audio,
            vad,
            peak,
            name,
            &wav_path,
            model_dir.to_string_lossy().as_ref(),
            16_000,
        ) {
            Ok(r) => {
                eprintln!(
                    "MARKER DESKTOP_VOICE_{}_RAW_TRANSCRIPT: {}",
                    if name.contains("golos") && !name.contains("counter") {
                        "GOLOS_EQUIVALENT"
                    } else if name.contains("counter") {
                        "COUNTER"
                    } else {
                        "PIPELINE"
                    },
                    r.raw_transcript
                );
                results.push(r);
            }
            Err(e) => eprintln!("pipeline {name} failed: {e}"),
        }
    }

    println!("{}", serde_json::to_string_pretty(&results).unwrap_or_default());
}

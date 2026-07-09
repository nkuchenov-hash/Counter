//! Windows Core Audio capture endpoint diagnostics (native MMDevice COM).
#![cfg(windows)]

use serde::{Deserialize, Serialize};
use windows::core::PWSTR;
use windows::Win32::Devices::FunctionDiscovery::PKEY_Device_FriendlyName;
use windows::Win32::Media::Audio::Endpoints::IAudioEndpointVolume;
use windows::Win32::Media::Audio::{
    eCapture, eCommunications, eConsole, eMultimedia, ERole, IAudioClient, IMMDevice,
    IMMDeviceEnumerator, MMDeviceEnumerator, WAVEFORMATEX,
};
use windows::Win32::System::Com::{
    CoCreateInstance, CoInitializeEx, CoTaskMemFree, CLSCTX_ALL, COINIT_MULTITHREADED, STGM_READ,
};
use windows::Win32::System::Com::StructuredStorage::PropVariantToStringAlloc;
use windows::Win32::UI::Shell::PropertiesSystem::IPropertyStore;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EndpointDiag {
    pub device_id: String,
    pub friendly_name: String,
    pub role: String,
    pub volume_scalar: Option<f32>,
    pub muted: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
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

fn ensure_com() {
    unsafe {
        let _ = CoInitializeEx(None, COINIT_MULTITHREADED);
    }
}

fn role_to_erole(role: &str) -> ERole {
    match role {
        "communications" => eCommunications,
        "multimedia" => eMultimedia,
        _ => eConsole,
    }
}

fn erole_to_str(role: ERole) -> &'static str {
    if role == eCommunications {
        "communications"
    } else if role == eMultimedia {
        "multimedia"
    } else {
        "console"
    }
}

unsafe fn pwstr_to_string(pw: PWSTR) -> Option<String> {
    if pw.is_null() {
        return None;
    }
    pw.to_string().ok()
}

unsafe fn read_friendly_name(device: &IMMDevice) -> String {
    let Ok(store) = device.OpenPropertyStore(STGM_READ) else {
        return String::new();
    };
    read_prop_string(&store, &PKEY_Device_FriendlyName).unwrap_or_default()
}

unsafe fn read_prop_string(store: &IPropertyStore, key: &windows::Win32::UI::Shell::PropertiesSystem::PROPERTYKEY) -> Option<String> {
    let pv = store.GetValue(key).ok()?;
    let pw = PropVariantToStringAlloc(&pv).ok()?;
    let s = pwstr_to_string(pw)?;
    let _ = CoTaskMemFree(Some(pw.0 as _));
    Some(s)
}

unsafe fn read_mix_format(device: &IMMDevice) -> (Option<u32>, Option<u16>, Option<String>) {
    let Ok(client) = device.Activate::<IAudioClient>(CLSCTX_ALL, None) else {
        return (None, None, None);
    };
    let Ok(mix) = client.GetMixFormat() else {
        return (None, None, None);
    };
    if mix.is_null() {
        return (None, None, None);
    }
    let wf = &*mix;
    let rate = wf.nSamplesPerSec;
    let channels = wf.nChannels;
    let fmt = match wf.wFormatTag {
        1 => "pcm",
        3 => "ieee_float",
        0xFFFE => "extensible",
        other => {
            return (
                Some(rate),
                Some(channels),
                Some(format!("wFormatTag={other}")),
            );
        }
    };
    (Some(rate), Some(channels), Some(fmt.to_string()))
}

unsafe fn query_endpoint(erole: ERole) -> Option<EndpointDiag> {
    ensure_com();
    let enumerator: IMMDeviceEnumerator =
        CoCreateInstance::<_, IMMDeviceEnumerator>(&MMDeviceEnumerator, None, CLSCTX_ALL).ok()?;
    let device = enumerator
        .GetDefaultAudioEndpoint(eCapture, erole)
        .ok()?;
    let id_ptr = device.GetId().ok()?;
    let device_id = pwstr_to_string(id_ptr).unwrap_or_default();
    let friendly_name = read_friendly_name(&device);
    let volume_iface = device
        .Activate::<IAudioEndpointVolume>(CLSCTX_ALL, None)
        .ok()?;
    let vol = volume_iface.GetMasterVolumeLevelScalar().ok()?;
    let muted = volume_iface.GetMute().ok()?.as_bool();
    Some(EndpointDiag {
        device_id,
        friendly_name,
        role: erole_to_str(erole).to_string(),
        volume_scalar: Some(vol),
        muted,
    })
}

fn query_endpoints_native(requested_role: &str) -> (Option<EndpointDiag>, Option<EndpointDiag>) {
    unsafe {
        let console = query_endpoint(eConsole);
        let communications = query_endpoint(eCommunications);
        if console.is_none() && communications.is_none() {
            eprintln!(
                "[endpoint] DESKTOP_VOICE_CORE_AUDIO_QUERY_FAILED requested={requested_role}"
            );
        }
        (console, communications)
    }
}

fn select_role(
    console: &Option<EndpointDiag>,
    communications: &Option<EndpointDiag>,
    requested: &str,
) -> String {
    match requested {
        "communications" => return "communications".to_string(),
        "console" => return "console".to_string(),
        "multimedia" => return "multimedia".to_string(),
        _ => {}
    }
    if let (Some(c), Some(m)) = (console, communications) {
        if c.device_id != m.device_id && !m.muted {
            let cv = c.volume_scalar.unwrap_or(0.0);
            let mv = m.volume_scalar.unwrap_or(0.0);
            if mv > cv {
                return "communications".to_string();
            }
        }
    }
    "console".to_string()
}

fn active_endpoint<'a>(
    role: &str,
    console: &'a Option<EndpointDiag>,
    communications: &'a Option<EndpointDiag>,
) -> Option<&'a EndpointDiag> {
    match role {
        "communications" => communications.as_ref().or(console.as_ref()),
        _ => console.as_ref().or(communications.as_ref()),
    }
}

pub fn build_endpoint_report(
    requested_role: &str,
    cpal_device_name: &str,
    cpal_host_id: &str,
    mix_rate: Option<u32>,
    mix_channels: Option<u16>,
    mix_format: Option<&str>,
) -> CaptureEndpointReport {
    let (console_default, communications_default) = query_endpoints_native(requested_role);
    let selected_role = select_role(&console_default, &communications_default, requested_role);
    let active = active_endpoint(&selected_role, &console_default, &communications_default);
    let (selected_device_id, selected_device_name, endpoint_volume, endpoint_muted) =
        if let Some(a) = active {
            (
                a.device_id.clone(),
                a.friendly_name.clone(),
                a.volume_scalar,
                a.muted,
            )
        } else {
            (
                String::new(),
                cpal_device_name.to_string(),
                None,
                false,
            )
        };
    let session_volume = communications_default
        .as_ref()
        .and_then(|c| c.volume_scalar)
        .or(console_default.as_ref().and_then(|c| c.volume_scalar));

    let (mix_sample_rate, mix_channels, mix_sample_format) = if mix_rate.is_some() {
        (mix_rate, mix_channels, mix_format.map(|s| s.to_string()))
    } else {
        unsafe {
            ensure_com();
            if let Ok(enumerator) =
                CoCreateInstance::<_, IMMDeviceEnumerator>(&MMDeviceEnumerator, None, CLSCTX_ALL)
            {
                if let Ok(device) =
                    enumerator.GetDefaultAudioEndpoint(eCapture, role_to_erole(&selected_role))
                {
                    read_mix_format(&device)
                } else {
                    (None, None, None)
                }
            } else {
                (None, None, None)
            }
        }
    };

    eprintln!(
        "[endpoint] DESKTOP_VOICE_CORE_AUDIO_DEVICE_DIAGNOSTICS \
         DESKTOP_VOICE_ENDPOINT_ID_LOGGED \
         DESKTOP_VOICE_ENDPOINT_VOLUME_LOGGED \
         DESKTOP_VOICE_DEFAULT_CONSOLE_DEVICE_LOGGED \
         DESKTOP_VOICE_DEFAULT_COMMUNICATIONS_DEVICE_LOGGED \
         DESKTOP_VOICE_CAPTURE_MIX_FORMAT_LOGGED \
         DESKTOP_VOICE_MIC_BOOST_OR_EFFECTS_CHECKED \
         role={selected_role} vol={endpoint_volume:?} id={selected_device_id} cpal={cpal_device_name}"
    );
    CaptureEndpointReport {
        console_default,
        communications_default,
        selected_role: selected_role.clone(),
        selected_device_id,
        selected_device_name,
        endpoint_volume,
        endpoint_muted,
        session_volume,
        mic_boost_db: None,
        enhancements_enabled: None,
        enhancements_notes:
            "cpal_wasapi_raw_stream_likely_pre_os_agc; driver_mic_boost_not_readable_via_mmdevice"
                .into(),
        raw_capture_likely_bypasses_enhancements: true,
        mix_sample_rate,
        mix_channels,
        mix_sample_format,
        cpal_device_name: cpal_device_name.to_string(),
        cpal_host_id: cpal_host_id.to_string(),
    }
}

pub async fn device_diag_http() -> actix_web::HttpResponse {
    let report = build_endpoint_report("auto", "", "", None, None, None);
    actix_web::HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "markers": [
            "DESKTOP_VOICE_CORE_AUDIO_DEVICE_DIAGNOSTICS",
            "DESKTOP_VOICE_ENDPOINT_ID_LOGGED",
            "DESKTOP_VOICE_ENDPOINT_VOLUME_LOGGED",
            "DESKTOP_VOICE_DEFAULT_CONSOLE_DEVICE_LOGGED",
            "DESKTOP_VOICE_DEFAULT_COMMUNICATIONS_DEVICE_LOGGED",
            "DESKTOP_VOICE_MIC_BOOST_OR_EFFECTS_CHECKED",
            "DESKTOP_VOICE_CAPTURE_MIX_FORMAT_LOGGED",
        ],
        "report": report,
    }))
}

#[allow(dead_code)]
const _WAVEFORMATEX_CHECK: fn() = || {
    let _ = std::mem::size_of::<WAVEFORMATEX>();
};

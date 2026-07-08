#include "desktop_voice_native_overlay.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <memory>
#include <string>

namespace {

constexpr wchar_t kOverlayClassName[] = L"CounterDesktopVoiceOverlay";
// Handy-style compact dark pill (listening): ~180x40.
constexpr int kPillWidth = 180;
constexpr int kPillHeight = 40;
// Slightly taller for processing / error / pending (still compact).
constexpr int kPillHeightExpanded = 44;
constexpr int kBottomMargin = 28;
constexpr int kCloseButtonSize = 18;
constexpr int kCloseButtonMargin = 10;

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_overlay_channel;

bool PointInCloseButton(int x, int y, const RECT& rect) {
  const int left = rect.right - kCloseButtonMargin - kCloseButtonSize;
  const int top = (rect.bottom - rect.top - kCloseButtonSize) / 2;
  const int right = left + kCloseButtonSize;
  const int bottom = top + kCloseButtonSize;
  return x >= left && x <= right && y >= top && y <= bottom;
}

void NotifyDartClose(const char* source) {
  if (!g_overlay_channel) {
    return;
  }
  g_overlay_channel->InvokeMethod(
      source,
      std::make_unique<flutter::EncodableValue>());
}

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring wide(size - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), size);
  return wide;
}

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return std::string();
  }
  const int size =
      WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }
  std::string utf8(size - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, utf8.data(), size, nullptr, nullptr);
  return utf8;
}

int OverlayHeightForState(const std::string& state) {
  if (state == "listening") return kPillHeight;
  return kPillHeightExpanded;
}

int OverlayWidthForState(const std::string& state) {
  if (state == "listening") return kPillWidth;
  // Slightly wider when showing a short status line.
  return 220;
}

}  // namespace

HWND DesktopVoiceNativeOverlay::main_hwnd_ = nullptr;
HWND DesktopVoiceNativeOverlay::overlay_hwnd_ = nullptr;
bool DesktopVoiceNativeOverlay::class_registered_ = false;
std::wstring DesktopVoiceNativeOverlay::primary_;
std::wstring DesktopVoiceNativeOverlay::secondary_;
std::string DesktopVoiceNativeOverlay::state_;
double DesktopVoiceNativeOverlay::level_ = 0.0;
double DesktopVoiceNativeOverlay::target_level_ = 0.0;
UINT_PTR DesktopVoiceNativeOverlay::anim_timer_id_ = 0;
std::wstring DesktopVoiceNativeOverlay::timer_text_;
double DesktopVoiceNativeOverlay::progress_ = 0.0;

constexpr UINT_PTR kAnimTimerId = 0x534F;  // 'SO'
constexpr UINT kAnimTimerIntervalMs = 33;  // ~30fps

void DesktopVoiceNativeOverlay::StartAnimationTimer() {
  if (anim_timer_id_ != 0) return;
  if (overlay_hwnd_ == nullptr) return;
  anim_timer_id_ = SetTimer(overlay_hwnd_, kAnimTimerId,
                            kAnimTimerIntervalMs, nullptr);
}

void DesktopVoiceNativeOverlay::StopAnimationTimer() {
  if (anim_timer_id_ == 0) return;
  if (overlay_hwnd_ != nullptr) {
    KillTimer(overlay_hwnd_, anim_timer_id_);
  }
  anim_timer_id_ = 0;
}

void DesktopVoiceNativeOverlay::TickAnimation() {
  constexpr double kAttack = 0.55;
  constexpr double kRelease = 0.18;
  constexpr double kEpsilon = 0.001;
  const double diff = target_level_ - level_;
  if (std::abs(diff) < kEpsilon && level_ < kEpsilon) {
    return;
  }
  const double k = diff > 0 ? kAttack : kRelease;
  level_ += diff * k;
  if (overlay_hwnd_ != nullptr) {
    InvalidateRect(overlay_hwnd_, nullptr, FALSE);
  }
}

void DesktopVoiceNativeOverlay::EnsureClassRegistered() {
  if (class_registered_) {
    return;
  }
  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(wc);
  wc.lpfnWndProc = OverlayWndProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  wc.lpszClassName = kOverlayClassName;
  RegisterClassExW(&wc);
  class_registered_ = true;
}

void DesktopVoiceNativeOverlay::PositionOverlay() {
  RECT work = {};
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
  const int height = OverlayHeightForState(state_);
  const int width = OverlayWidthForState(state_);
  const int x = work.left + ((work.right - work.left) - width) / 2;
  const int y = work.bottom - height - kBottomMargin;
  SetWindowPos(overlay_hwnd_, HWND_TOPMOST, x, y, width, height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void DesktopVoiceNativeOverlay::PaintOverlay(HDC hdc, const RECT& rect) {
  // Handy-style compact dark pill. No light gray square panel.
  const COLORREF bg_color = RGB(28, 28, 30);
  const COLORREF accent = RGB(236, 236, 240);
  const COLORREF muted = RGB(160, 160, 168);
  const COLORREF error_color = RGB(255, 120, 120);

  HBRUSH bg = CreateSolidBrush(bg_color);
  // Soft round pill with fill + subtle border.
  HPEN border = CreatePen(PS_SOLID, 1, RGB(55, 55, 60));
  HGDIOBJ old_pen = SelectObject(hdc, border);
  HGDIOBJ old_brush = SelectObject(hdc, bg);
  const int radius = (rect.bottom - rect.top);
  RoundRect(hdc, rect.left, rect.top, rect.right, rect.bottom, radius, radius);
  SelectObject(hdc, old_pen);
  SelectObject(hdc, old_brush);
  DeleteObject(border);
  DeleteObject(bg);

  SetBkMode(hdc, TRANSPARENT);

  const int h = rect.bottom - rect.top;
  const int cy = rect.top + h / 2;

  // Left mic / status icon (listening = filled circle accent; error = X-ish).
  const int icon_cx = rect.left + 18;
  if (state_ == "error") {
    HPEN err_pen = CreatePen(PS_SOLID, 2, error_color);
    HGDIOBJ old_err = SelectObject(hdc, err_pen);
    const int d = 5;
    MoveToEx(hdc, icon_cx - d, cy - d, nullptr);
    LineTo(hdc, icon_cx + d, cy + d);
    MoveToEx(hdc, icon_cx + d, cy - d, nullptr);
    LineTo(hdc, icon_cx - d, cy + d);
    SelectObject(hdc, old_err);
    DeleteObject(err_pen);
  } else if (state_ == "processing" || state_ == "started" || state_ == "stopped" ||
             state_ == "pending") {
    // Spinner-ish small arcs: filled accent dot.
    HBRUSH dot = CreateSolidBrush(accent);
    RECT dr = {icon_cx - 4, cy - 4, icon_cx + 4, cy + 4};
    FillRect(hdc, &dr, dot);
    DeleteObject(dot);
  } else {
    // Mic capsule: small rounded vertical bar + base.
    HBRUSH mic = CreateSolidBrush(accent);
    RECT mic_body = {icon_cx - 3, cy - 7, icon_cx + 3, cy + 3};
    FillRect(hdc, &mic_body, mic);
    DeleteObject(mic);
    HPEN mic_pen = CreatePen(PS_SOLID, 1, accent);
    HGDIOBJ old_mic = SelectObject(hdc, mic_pen);
    MoveToEx(hdc, icon_cx - 5, cy + 3, nullptr);
    LineTo(hdc, icon_cx + 5, cy + 3);
    MoveToEx(hdc, icon_cx, cy + 3, nullptr);
    LineTo(hdc, icon_cx, cy + 7);
    SelectObject(hdc, old_mic);
    DeleteObject(mic_pen);
  }

  // Center: listening = mic level bars only (no debug / status text).
  // Other states: short primary line (compact).
  if (state_ == "listening") {
    const int bar_count = 5;
    const int bar_w = 3;
    const int gap = 4;
    const int max_h = 14;
    const double gain = std::sqrt(std::max(level_, 0.0));
    const double min_visible = 0.08;
    const double effective_level = std::max(gain, min_visible);
    const double phase = static_cast<double>(GetTickCount64()) / 220.0;
    const int total_w = bar_count * bar_w + (bar_count - 1) * gap;
    int x = (rect.left + rect.right - total_w) / 2;
    for (int i = 0; i < bar_count; ++i) {
      const double shape = 0.45 + 0.55 * std::sin(phase + (i + 1) * 0.9);
      const double leveled = effective_level * shape + min_visible * 0.35;
      const int bh = static_cast<int>(
          std::clamp(leveled * max_h, 3.0, static_cast<double>(max_h)));
      HBRUSH bar = CreateSolidBrush(accent);
      RECT bar_rect = {x, cy - bh / 2, x + bar_w, cy + bh / 2};
      FillRect(hdc, &bar_rect, bar);
      DeleteObject(bar);
      x += bar_w + gap;
    }
  } else {
    HFONT font =
        CreateFontW(13, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                    CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
    HGDIOBJ old_font = SelectObject(hdc, font);
    SetTextColor(hdc, state_ == "error" ? error_color : accent);
    RECT text_rect = {rect.left + 34, rect.top + 2, rect.right - 36, rect.bottom - 2};
    DrawTextW(hdc, primary_.c_str(), -1, &text_rect,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    SelectObject(hdc, old_font);
    DeleteObject(font);

    if (state_ == "pending" && progress_ > 0.0) {
      const int bar_h = 2;
      const int filled_w = static_cast<int>(
          static_cast<double>(rect.right - rect.left) *
          std::clamp(progress_, 0.0, 1.0));
      HBRUSH track = CreateSolidBrush(RGB(50, 50, 54));
      RECT track_rect = {0, rect.bottom - bar_h, rect.right, rect.bottom};
      FillRect(hdc, &track_rect, track);
      DeleteObject(track);
      if (filled_w > 0) {
        HBRUSH fill = CreateSolidBrush(RGB(90, 150, 255));
        RECT fill_rect = {0, rect.bottom - bar_h, filled_w, rect.bottom};
        FillRect(hdc, &fill_rect, fill);
        DeleteObject(fill);
      }
    }
  }

  // Right close (X) — always.
  const int close_left = rect.right - kCloseButtonMargin - kCloseButtonSize;
  const int close_top = (h - kCloseButtonSize) / 2;
  HPEN close_pen = CreatePen(PS_SOLID, 2, muted);
  HGDIOBJ old_close_pen = SelectObject(hdc, close_pen);
  const int cx = close_left + kCloseButtonSize / 2;
  const int cyy = close_top + kCloseButtonSize / 2;
  const int d = 4;
  MoveToEx(hdc, cx - d, cyy - d, nullptr);
  LineTo(hdc, cx + d, cyy + d);
  MoveToEx(hdc, cx + d, cyy - d, nullptr);
  LineTo(hdc, cx - d, cyy + d);
  SelectObject(hdc, old_close_pen);
  DeleteObject(close_pen);

  // Silence unused secondary / timer for listening (no debug text).
  (void)secondary_;
  (void)timer_text_;
}

LRESULT CALLBACK DesktopVoiceNativeOverlay::OverlayWndProc(
    HWND hwnd,
    UINT message,
    WPARAM wparam,
    LPARAM lparam) noexcept {
  switch (message) {
    case WM_PAINT: {
      PAINTSTRUCT ps;
      HDC hdc = BeginPaint(hwnd, &ps);
      RECT rect;
      GetClientRect(hwnd, &rect);
      PaintOverlay(hdc, rect);
      EndPaint(hwnd, &ps);
      return 0;
    }
    case WM_LBUTTONDOWN: {
      RECT rect;
      GetClientRect(hwnd, &rect);
      const int x = LOWORD(lparam);
      const int y = HIWORD(lparam);
      if (PointInCloseButton(x, y, rect)) {
        NotifyDartClose("overlayCloseClicked");
        return 0;
      }
      NotifyDartClose("overlayBodyClicked");
      return 0;
    }
    case WM_KEYDOWN:
      if (wparam == VK_ESCAPE) {
        NotifyDartClose("overlayEscapePressed");
        return 0;
      }
      return DefWindowProcW(hwnd, message, wparam, lparam);
    case WM_TIMER: {
      if (wparam == kAnimTimerId) {
        TickAnimation();
        return 0;
      }
      return DefWindowProcW(hwnd, message, wparam, lparam);
    }
    case WM_ERASEBKGND:
      return 1;
    case WM_DESTROY:
      overlay_hwnd_ = nullptr;
      return 0;
    default:
      return DefWindowProcW(hwnd, message, wparam, lparam);
  }
}

bool DesktopVoiceNativeOverlay::Show(const std::string& primary,
                                   const std::string& secondary,
                                   const std::string& state,
                                   double level,
                                   const std::string& timer_text,
                                   double progress) {
  if (main_hwnd_ == nullptr) {
    return false;
  }

  primary_ = Utf8ToWide(primary);
  secondary_ = Utf8ToWide(secondary);
  state_ = state;
  progress_ = progress;
  target_level_ = level;
  if (anim_timer_id_ == 0) {
    level_ = level;
  }
  timer_text_ = Utf8ToWide(timer_text);

  EnsureClassRegistered();

  if (overlay_hwnd_ == nullptr || !IsWindow(overlay_hwnd_)) {
    overlay_hwnd_ = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, kOverlayClassName,
        L"", WS_POPUP, 0, 0, kPillWidth, kPillHeight, nullptr, nullptr,
        GetModuleHandle(nullptr), nullptr);
    if (overlay_hwnd_ == nullptr) {
      return false;
    }
  }

  PositionOverlay();
  ShowWindow(overlay_hwnd_, SW_SHOWNOACTIVATE);
  StartAnimationTimer();
  InvalidateRect(overlay_hwnd_, nullptr, TRUE);
  UpdateWindow(overlay_hwnd_);
  return true;
}

void DesktopVoiceNativeOverlay::Hide() {
  StopAnimationTimer();
  target_level_ = 0.0;
  level_ = 0.0;
  if (overlay_hwnd_ != nullptr && IsWindow(overlay_hwnd_)) {
    ShowWindow(overlay_hwnd_, SW_HIDE);
  }
}

bool DesktopVoiceNativeOverlay::IsVisible() {
  return overlay_hwnd_ != nullptr && IsWindowVisible(overlay_hwnd_);
}

void DesktopVoiceNativeOverlay::Register(flutter::FlutterEngine* engine,
                                         HWND main_hwnd) {
  main_hwnd_ = main_hwnd;

  g_overlay_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "counter/desktop_voice_native_overlay",
      &flutter::StandardMethodCodec::GetInstance());

  g_overlay_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();
        if (method == "show") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("invalid_args", "Expected map");
            return;
          }
          auto read_string = [&](const char* key) -> std::string {
            const auto it = args->find(flutter::EncodableValue(key));
            if (it == args->end()) {
              return std::string();
            }
            if (const auto* s = std::get_if<std::string>(&it->second)) {
              return *s;
            }
            return std::string();
          };
          double level = 0.0;
          const auto level_it = args->find(flutter::EncodableValue("level"));
          if (level_it != args->end()) {
            if (const auto* d = std::get_if<double>(&level_it->second)) {
              level = *d;
            } else if (const auto* i = std::get_if<int32_t>(&level_it->second)) {
              level = static_cast<double>(*i);
            }
          }
          double progress = 0.0;
          const auto progress_it = args->find(flutter::EncodableValue("progress"));
          if (progress_it != args->end()) {
            if (const auto* d = std::get_if<double>(&progress_it->second)) {
              progress = *d;
            } else if (const auto* i = std::get_if<int32_t>(&progress_it->second)) {
              progress = static_cast<double>(*i);
            }
          }
          const bool ok = Show(read_string("primary"), read_string("secondary"),
                               read_string("state"), level,
                               read_string("timer"), progress);
          result->Success(flutter::EncodableValue(ok));
          return;
        }
        if (method == "hide") {
          Hide();
          result->Success();
          return;
        }
        if (method == "isMainWindowVisible") {
          if (main_hwnd_ == nullptr) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          const bool visible = IsWindowVisible(main_hwnd_) != FALSE;
          result->Success(flutter::EncodableValue(visible));
          return;
        }
        result->NotImplemented();
      });
}

#include "desktop_voice_native_overlay.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <memory>
#include <string>

namespace {

constexpr wchar_t kOverlayClassName[] = L"CounterDesktopVoiceOverlay";
constexpr int kOverlayWidth = 460;
constexpr int kOverlayHeight = 112;
constexpr int kBottomMargin = 28;
constexpr int kCloseButtonSize = 28;
constexpr int kCloseButtonMargin = 12;

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_overlay_channel;

bool PointInCloseButton(int x, int y, const RECT& rect) {
  const int left = rect.right - kCloseButtonMargin - kCloseButtonSize;
  const int top = kCloseButtonMargin;
  const int right = rect.right - kCloseButtonMargin;
  const int bottom = kCloseButtonMargin + kCloseButtonSize;
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

// Smoothly step [level_] toward [target_level_] and force a repaint. Called on
// every 33ms tick. Asymmetric: rises fast (audible reaction), decays slower
// (organic settling), so quiet rooms still produce gentle motion rather than
// a dead flat row of bars.
void DesktopVoiceNativeOverlay::TickAnimation() {
  constexpr double kAttack = 0.55;   // fraction of remaining gap per tick (up)
  constexpr double kRelease = 0.18;  // fraction per tick (down)
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
  const int x = work.left + ((work.right - work.left) - kOverlayWidth) / 2;
  const int y = work.bottom - kOverlayHeight - kBottomMargin;
  SetWindowPos(overlay_hwnd_, HWND_TOPMOST, x, y, kOverlayWidth, kOverlayHeight,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void DesktopVoiceNativeOverlay::PaintOverlay(HDC hdc, const RECT& rect) {
  HBRUSH bg = CreateSolidBrush(RGB(250, 250, 248));
  FillRect(hdc, &rect, bg);
  DeleteObject(bg);

  HPEN border = CreatePen(PS_SOLID, 1, RGB(230, 226, 220));
  HGDIOBJ old_pen = SelectObject(hdc, border);
  HGDIOBJ old_brush = SelectObject(hdc, GetStockObject(NULL_BRUSH));
  RoundRect(hdc, rect.left, rect.top, rect.right, rect.bottom, 24, 24);
  SelectObject(hdc, old_pen);
  SelectObject(hdc, old_brush);
  DeleteObject(border);

  SetBkMode(hdc, TRANSPARENT);
  HFONT primary_font =
      CreateFontW(18, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                  OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                  DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
  HFONT secondary_font =
      CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                  OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                  DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
  HGDIOBJ old_font = SelectObject(hdc, primary_font);
  SetTextColor(hdc, RGB(20, 20, 20));

  RECT primary_rect = {20, 16, rect.right - 20, 48};
  DrawTextW(hdc, primary_.c_str(), -1, &primary_rect,
            DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);

  if (!secondary_.empty()) {
    SelectObject(hdc, secondary_font);
    SetTextColor(hdc, RGB(90, 90, 90));
    RECT secondary_rect = {20, 48, rect.right - 20, 72};
    DrawTextW(hdc, secondary_.c_str(), -1, &secondary_rect,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
  }

  if (!timer_text_.empty()) {
    SelectObject(hdc, primary_font);
    SetTextColor(hdc, RGB(20, 20, 20));
    RECT timer_rect = {rect.right - 90, 16, rect.right - 56, 48};
    DrawTextW(hdc, timer_text_.c_str(), -1, &timer_rect,
              DT_RIGHT | DT_VCENTER | DT_SINGLELINE);
  }

  // Close (X) button — top-right; always dismissible.
  const int close_left = rect.right - kCloseButtonMargin - kCloseButtonSize;
  const int close_top = kCloseButtonMargin;
  HPEN close_pen = CreatePen(PS_SOLID, 2, RGB(120, 120, 120));
  HGDIOBJ old_close_pen = SelectObject(hdc, close_pen);
  const int cx = close_left + kCloseButtonSize / 2;
  const int cy = close_top + kCloseButtonSize / 2;
  const int d = 6;
  MoveToEx(hdc, cx - d, cy - d, nullptr);
  LineTo(hdc, cx + d, cy + d);
  MoveToEx(hdc, cx + d, cy - d, nullptr);
  LineTo(hdc, cx - d, cy + d);
  SelectObject(hdc, old_close_pen);
  DeleteObject(close_pen);

  if (state_ == "listening") {
    const int bar_count = 8;
    const int bar_w = 6;
    const int gap = 4;
    const int base_y = 82;
    const int max_h = 18;
    // Sqrt gain curve: a real-voice peak of ~0.1 maps to ~0.32 visible level so
    // bars reach ~10px (out of 18) — visibly reactive. Quiet rooms still get a
    // minimum floor so bars aren't dead-flat between speech bursts.
    const double gain = std::sqrt(std::max(level_, 0.0));
    const double min_visible = 0.06;  // ambient floor — bars gently pulse
    const double effective_level = std::max(gain, min_visible);
    // Phase offset so bars don't look like a static sine wave; combined with
    // the 33ms animation timer it produces gentle continuous motion.
    const double phase =
        static_cast<double>(GetTickCount64()) / 220.0;
    int x = 20;
    for (int i = 0; i < bar_count; ++i) {
      // Per-bar shape: 0.45 base + 0.55 sinusoidal modulation, scaled by level.
      const double shape = 0.45 + 0.55 * std::sin(phase + (i + 1) * 0.9);
      const double leveled = effective_level * shape + min_visible * 0.35;
      const int h = static_cast<int>(
          std::clamp(leveled * max_h, 3.0, static_cast<double>(max_h)));
      HBRUSH bar = CreateSolidBrush(RGB(30, 30, 30));
      RECT bar_rect = {x, base_y - h, x + bar_w, base_y};
      FillRect(hdc, &bar_rect, bar);
      DeleteObject(bar);
      x += bar_w + gap;
    }
  }

  SelectObject(hdc, old_font);
  DeleteObject(primary_font);
  DeleteObject(secondary_font);
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
                                   const std::string& timer_text) {
  if (main_hwnd_ == nullptr) {
    return false;
  }

  primary_ = Utf8ToWide(primary);
  secondary_ = Utf8ToWide(secondary);
  state_ = state;
  // Drive the smoothed [level_] via [target_level_]; the animation timer
  // interpolates between them so bars settle smoothly rather than snapping.
  target_level_ = level;
  // First-ever show: seed [level_] from the incoming value so we don't ramp
  // up from 0 on every fresh overlay.
  if (anim_timer_id_ == 0) {
    level_ = level;
  }
  timer_text_ = Utf8ToWide(timer_text);

  EnsureClassRegistered();

  if (overlay_hwnd_ == nullptr || !IsWindow(overlay_hwnd_)) {
    overlay_hwnd_ = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, kOverlayClassName,
        L"", WS_POPUP, 0, 0, kOverlayWidth, kOverlayHeight, nullptr, nullptr,
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
          const bool ok = Show(read_string("primary"), read_string("secondary"),
                               read_string("state"), level,
                               read_string("timer"));
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

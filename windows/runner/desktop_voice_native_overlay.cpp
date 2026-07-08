#include "desktop_voice_native_overlay.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <memory>
#include <string>

#ifndef USER_DEFAULT_SCREEN_DPI
#define USER_DEFAULT_SCREEN_DPI 96
#endif

namespace {

constexpr wchar_t kOverlayClassName[] = L"CounterDesktopVoiceOverlay";

// Logical sizes (100% / 96 DPI). Scaled at paint/position by monitor DPI.
// Listening/processing: readable compact pill (not Handy-tiny).
constexpr int kListeningWidth = 340;
constexpr int kListeningHeight = 68;
constexpr int kStatusWidth = 340;
constexpr int kStatusHeight = 68;

// Pending confirmation — large readable card.
constexpr int kPendingWidth = 480;
constexpr int kPendingHeight = 124;

// Error — large readable card (never tiny red text).
constexpr int kErrorWidth = 480;
constexpr int kErrorHeight = 136;

constexpr int kBottomMargin = 28;
constexpr int kCloseButtonSize = 32;
constexpr int kCloseButtonMargin = 12;

// Hard rule: no overlay font below 16pt. Title 18–20pt. Detail ≥16pt.
constexpr int kTitleFontPt = 19;
constexpr int kBodyFontPt = 16;
constexpr int kMinFontPt = 16;

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_overlay_channel;

int DpiForHwnd(HWND hwnd) {
  if (hwnd == nullptr) {
    return USER_DEFAULT_SCREEN_DPI;
  }
  const UINT dpi = GetDpiForWindow(hwnd);
  return dpi == 0 ? USER_DEFAULT_SCREEN_DPI : static_cast<int>(dpi);
}

int ScalePx(int logical_px, int dpi) {
  return MulDiv(logical_px, dpi, USER_DEFAULT_SCREEN_DPI);
}

int PtToPx(int pt, int dpi) {
  // Negative lfHeight = character height in device pixels for CreateFont.
  const int px = MulDiv(std::max(pt, kMinFontPt), dpi, 72);
  return -std::max(px, ScalePx(kMinFontPt, dpi));
}

bool PointInCloseButton(int x, int y, const RECT& rect, int dpi) {
  const int close = ScalePx(kCloseButtonSize, dpi);
  const int margin = ScalePx(kCloseButtonMargin, dpi);
  const int left = rect.right - margin - close;
  const int top = margin;
  const int right = left + close;
  const int bottom = top + close;
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

int OverlayHeightForState(const std::string& state) {
  if (state == "error") return kErrorHeight;
  if (state == "pending") return kPendingHeight;
  if (state == "listening") return kListeningHeight;
  return kStatusHeight;
}

int OverlayWidthForState(const std::string& state) {
  if (state == "error") return kErrorWidth;
  if (state == "pending") return kPendingWidth;
  if (state == "listening") return kListeningWidth;
  return kStatusWidth;
}

int CornerRadiusForState(const std::string& state, int dpi) {
  if (state == "error" || state == "pending") {
    return ScalePx(20, dpi);
  }
  return OverlayHeightForState(state);  // stadium before DPI (scaled by caller)
}

HFONT MakePtFont(int pt, int weight, int dpi) {
  return CreateFontW(PtToPx(pt, dpi), 0, 0, 0, weight, FALSE, FALSE, FALSE,
                     DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                     CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
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
  constexpr double kRelease = 0.22;
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
  const int dpi = DpiForHwnd(overlay_hwnd_ != nullptr ? overlay_hwnd_ : main_hwnd_);
  const int height = ScalePx(OverlayHeightForState(state_), dpi);
  const int width = ScalePx(OverlayWidthForState(state_), dpi);
  const int margin = ScalePx(kBottomMargin, dpi);
  const int x = work.left + ((work.right - work.left) - width) / 2;
  const int y = work.bottom - height - margin;
  SetWindowPos(overlay_hwnd_, HWND_TOPMOST, x, y, width, height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void DesktopVoiceNativeOverlay::PaintOverlay(HDC hdc, const RECT& rect) {
  const int dpi = DpiForHwnd(overlay_hwnd_);
  const COLORREF bg_color = RGB(28, 28, 30);
  const COLORREF accent = RGB(236, 236, 240);
  const COLORREF muted = RGB(170, 170, 178);
  const COLORREF error_accent = RGB(255, 140, 140);
  const COLORREF title_on_error = RGB(255, 220, 220);

  HBRUSH bg = CreateSolidBrush(bg_color);
  HPEN border = CreatePen(PS_SOLID, 1, RGB(55, 55, 60));
  HGDIOBJ old_pen = SelectObject(hdc, border);
  HGDIOBJ old_brush = SelectObject(hdc, bg);
  int radius = CornerRadiusForState(state_, dpi);
  if (state_ != "error" && state_ != "pending") {
    radius = ScalePx(OverlayHeightForState(state_), dpi);
  }
  RoundRect(hdc, rect.left, rect.top, rect.right, rect.bottom, radius, radius);
  SelectObject(hdc, old_pen);
  SelectObject(hdc, old_brush);
  DeleteObject(border);
  DeleteObject(bg);

  SetBkMode(hdc, TRANSPARENT);

  const int h = rect.bottom - rect.top;
  const int cy = rect.top + h / 2;
  const int close = ScalePx(kCloseButtonSize, dpi);
  const int close_margin = ScalePx(kCloseButtonMargin, dpi);
  const int content_right = rect.right - close_margin - close - ScalePx(8, dpi);
  const int icon_cx = rect.left + ScalePx(28, dpi);

  if (state_ == "error") {
    HPEN err_pen = CreatePen(PS_SOLID, 2, error_accent);
    HGDIOBJ old_err = SelectObject(hdc, err_pen);
    const int d = ScalePx(7, dpi);
    MoveToEx(hdc, icon_cx - d, cy - d, nullptr);
    LineTo(hdc, icon_cx + d, cy + d);
    MoveToEx(hdc, icon_cx + d, cy - d, nullptr);
    LineTo(hdc, icon_cx - d, cy + d);
    SelectObject(hdc, old_err);
    DeleteObject(err_pen);
  } else if (state_ == "listening") {
    HBRUSH mic = CreateSolidBrush(accent);
    RECT mic_body = {icon_cx - ScalePx(5, dpi), cy - ScalePx(11, dpi),
                     icon_cx + ScalePx(5, dpi), cy + ScalePx(5, dpi)};
    FillRect(hdc, &mic_body, mic);
    DeleteObject(mic);
    HPEN mic_pen = CreatePen(PS_SOLID, 2, accent);
    HGDIOBJ old_mic = SelectObject(hdc, mic_pen);
    MoveToEx(hdc, icon_cx - ScalePx(7, dpi), cy + ScalePx(5, dpi), nullptr);
    LineTo(hdc, icon_cx + ScalePx(7, dpi), cy + ScalePx(5, dpi));
    MoveToEx(hdc, icon_cx, cy + ScalePx(5, dpi), nullptr);
    LineTo(hdc, icon_cx, cy + ScalePx(11, dpi));
    SelectObject(hdc, old_mic);
    DeleteObject(mic_pen);
  } else {
    HBRUSH dot = CreateSolidBrush(accent);
    RECT dr = {icon_cx - ScalePx(6, dpi), cy - ScalePx(6, dpi),
               icon_cx + ScalePx(6, dpi), cy + ScalePx(6, dpi)};
    FillRect(hdc, &dr, dot);
    DeleteObject(dot);
  }

  if (state_ == "listening") {
    // Dart sends perceptual 0..1 already — do not sqrt again.
    const int bar_count = 5;
    const int bar_w = ScalePx(5, dpi);
    const int gap = ScalePx(6, dpi);
    const int max_h = ScalePx(30, dpi);
    const double min_visible = 0.12;
    const double effective_level = std::max(std::max(level_, 0.0), min_visible);
    const double phase = static_cast<double>(GetTickCount64()) / 220.0;
    const int total_w = bar_count * bar_w + (bar_count - 1) * gap;
    int x = (rect.left + rect.right - total_w) / 2;
    for (int i = 0; i < bar_count; ++i) {
      const double shape = 0.45 + 0.55 * std::sin(phase + (i + 1) * 0.9);
      const double leveled = effective_level * shape + min_visible * 0.25;
      const int bh = static_cast<int>(
          std::clamp(leveled * max_h, static_cast<double>(ScalePx(6, dpi)),
                     static_cast<double>(max_h)));
      HBRUSH bar = CreateSolidBrush(accent);
      RECT bar_rect = {x, cy - bh / 2, x + bar_w, cy + bh / 2};
      FillRect(hdc, &bar_rect, bar);
      DeleteObject(bar);
      x += bar_w + gap;
    }
  } else if (state_ == "error") {
    HFONT title_font = MakePtFont(kTitleFontPt, FW_SEMIBOLD, dpi);
    HFONT body_font = MakePtFont(kBodyFontPt, FW_NORMAL, dpi);
    HGDIOBJ old_font = SelectObject(hdc, title_font);
    SetTextColor(hdc, title_on_error);
    RECT title_rect = {rect.left + ScalePx(56, dpi), rect.top + ScalePx(18, dpi),
                       content_right, rect.top + ScalePx(52, dpi)};
    DrawTextW(hdc, primary_.c_str(), -1, &title_rect,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    if (!secondary_.empty()) {
      SelectObject(hdc, body_font);
      SetTextColor(hdc, muted);
      RECT detail_rect = {rect.left + ScalePx(56, dpi),
                          rect.top + ScalePx(56, dpi), content_right,
                          rect.bottom - ScalePx(18, dpi)};
      DrawTextW(hdc, secondary_.c_str(), -1, &detail_rect,
                DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
    }
    SelectObject(hdc, old_font);
    DeleteObject(title_font);
    DeleteObject(body_font);
  } else if (state_ == "pending") {
    HFONT title_font = MakePtFont(kTitleFontPt, FW_SEMIBOLD, dpi);
    HFONT body_font = MakePtFont(kBodyFontPt, FW_NORMAL, dpi);
    HGDIOBJ old_font = SelectObject(hdc, title_font);
    SetTextColor(hdc, accent);
    RECT title_rect = {rect.left + ScalePx(56, dpi), rect.top + ScalePx(16, dpi),
                       content_right, rect.top + ScalePx(50, dpi)};
    DrawTextW(hdc, primary_.c_str(), -1, &title_rect,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    if (!secondary_.empty()) {
      SelectObject(hdc, body_font);
      SetTextColor(hdc, muted);
      RECT hint_rect = {rect.left + ScalePx(56, dpi),
                        rect.top + ScalePx(54, dpi), content_right,
                        rect.top + ScalePx(90, dpi)};
      DrawTextW(hdc, secondary_.c_str(), -1, &hint_rect,
                DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    }
    SelectObject(hdc, old_font);
    DeleteObject(title_font);
    DeleteObject(body_font);

    const int bar_h = ScalePx(5, dpi);
    const int track_top = rect.bottom - bar_h - ScalePx(14, dpi);
    const int track_left = rect.left + ScalePx(20, dpi);
    const int track_right = rect.right - ScalePx(20, dpi);
    const int track_w = track_right - track_left;
    const int filled_w = static_cast<int>(
        static_cast<double>(track_w) * std::clamp(progress_, 0.0, 1.0));
    HBRUSH track = CreateSolidBrush(RGB(50, 50, 54));
    RECT track_rect = {track_left, track_top, track_right, track_top + bar_h};
    FillRect(hdc, &track_rect, track);
    DeleteObject(track);
    if (filled_w > 0) {
      HBRUSH fill = CreateSolidBrush(RGB(90, 150, 255));
      RECT fill_rect = {track_left, track_top, track_left + filled_w,
                        track_top + bar_h};
      FillRect(hdc, &fill_rect, fill);
      DeleteObject(fill);
    }
  } else {
    HFONT title_font = MakePtFont(kTitleFontPt, FW_SEMIBOLD, dpi);
    HFONT body_font = MakePtFont(kBodyFontPt, FW_NORMAL, dpi);
    HGDIOBJ old_font = SelectObject(hdc, title_font);
    SetTextColor(hdc, accent);
    if (!secondary_.empty()) {
      RECT title_rect = {rect.left + ScalePx(56, dpi),
                         rect.top + ScalePx(12, dpi), content_right,
                         rect.top + ScalePx(42, dpi)};
      DrawTextW(hdc, primary_.c_str(), -1, &title_rect,
                DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
      SelectObject(hdc, body_font);
      SetTextColor(hdc, muted);
      RECT detail_rect = {rect.left + ScalePx(56, dpi),
                          rect.top + ScalePx(42, dpi), content_right,
                          rect.bottom - ScalePx(12, dpi)};
      DrawTextW(hdc, secondary_.c_str(), -1, &detail_rect,
                DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    } else {
      RECT title_rect = {rect.left + ScalePx(56, dpi),
                         rect.top + ScalePx(12, dpi), content_right,
                         rect.bottom - ScalePx(12, dpi)};
      DrawTextW(hdc, primary_.c_str(), -1, &title_rect,
                DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    }
    SelectObject(hdc, old_font);
    DeleteObject(title_font);
    DeleteObject(body_font);
  }

  const int close_left = rect.right - close_margin - close;
  const int close_top = close_margin;
  HPEN close_pen = CreatePen(PS_SOLID, 2, muted);
  HGDIOBJ old_close_pen = SelectObject(hdc, close_pen);
  const int cx = close_left + close / 2;
  const int cyy = close_top + close / 2;
  const int d = ScalePx(7, dpi);
  MoveToEx(hdc, cx - d, cyy - d, nullptr);
  LineTo(hdc, cx + d, cyy + d);
  MoveToEx(hdc, cx + d, cyy - d, nullptr);
  LineTo(hdc, cx - d, cyy + d);
  SelectObject(hdc, old_close_pen);
  DeleteObject(close_pen);

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
      const int dpi = DpiForHwnd(hwnd);
      const int x = LOWORD(lparam);
      const int y = HIWORD(lparam);
      if (PointInCloseButton(x, y, rect, dpi)) {
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
    case WM_DPICHANGED: {
      PositionOverlay();
      InvalidateRect(hwnd, nullptr, TRUE);
      return 0;
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
        L"", WS_POPUP, 0, 0, kListeningWidth, kListeningHeight, nullptr, nullptr,
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
        if (method == "overlayMetrics") {
          const int dpi = DpiForHwnd(
              overlay_hwnd_ != nullptr ? overlay_hwnd_ : main_hwnd_);
          const double scale = static_cast<double>(dpi) / USER_DEFAULT_SCREEN_DPI;
          flutter::EncodableMap map;
          map[flutter::EncodableValue("overlay_dpi")] =
              flutter::EncodableValue(dpi);
          map[flutter::EncodableValue("overlay_scale_factor")] =
              flutter::EncodableValue(scale);
          map[flutter::EncodableValue("overlay_renderer")] =
              flutter::EncodableValue(std::string("native_handy_pill"));
          map[flutter::EncodableValue("overlay_state")] =
              flutter::EncodableValue(state_);
          map[flutter::EncodableValue("overlay_width_px")] =
              flutter::EncodableValue(
                  ScalePx(OverlayWidthForState(state_), dpi));
          map[flutter::EncodableValue("overlay_height_px")] =
              flutter::EncodableValue(
                  ScalePx(OverlayHeightForState(state_), dpi));
          map[flutter::EncodableValue("overlay_min_font_pt")] =
              flutter::EncodableValue(kMinFontPt);
          map[flutter::EncodableValue("overlay_title_font_pt")] =
              flutter::EncodableValue(kTitleFontPt);
          map[flutter::EncodableValue("overlay_detail_font_pt")] =
              flutter::EncodableValue(kBodyFontPt);
          map[flutter::EncodableValue("overlay_close_hit_px")] =
              flutter::EncodableValue(ScalePx(kCloseButtonSize, dpi));
          result->Success(flutter::EncodableValue(map));
          return;
        }
        result->NotImplemented();
      });
}

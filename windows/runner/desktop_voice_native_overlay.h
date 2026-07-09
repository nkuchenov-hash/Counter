#ifndef RUNNER_DESKTOP_VOICE_NATIVE_OVERLAY_H_
#define RUNNER_DESKTOP_VOICE_NATIVE_OVERLAY_H_

#include <flutter/flutter_engine.h>

#include <windows.h>

#include <string>

// Separate topmost tool-window overlay — never mutates the main Flutter HWND.
class DesktopVoiceNativeOverlay {
 public:
  static void Register(flutter::FlutterEngine* engine, HWND main_hwnd);

  static bool Show(const std::string& primary,
                   const std::string& secondary,
                   const std::string& state,
                   double level,
                   const std::string& timer_text,
                   double progress = 0.0);

  static void Hide();

  static bool IsVisible();

  // Short ready click on the default output device (non-blocking).
  static bool PlayReadyCue(int frequency_hz, int duration_ms,
                           std::string* error_out);

 private:
  static void EnsureClassRegistered();
  static void EnsureLayeredTransparency();
  static void PositionOverlay();
  static void PaintOverlay(HDC hdc, const RECT& rect);
  static LRESULT CALLBACK OverlayWndProc(HWND hwnd,
                                           UINT message,
                                           WPARAM wparam,
                                           LPARAM lparam) noexcept;

  // Mic-bar animation. [target_level_] holds the latest incoming level from
  // Dart; [level_] is the smoothed value actually painted. A 33ms timer
  // (kAnimTimerId) leaks [level_] toward [target_level_] and forces a repaint
  // so the bars visibly react / settle even between Dart-side pushes.
  static void StartAnimationTimer();
  static void StopAnimationTimer();
  static void TickAnimation();

  static HWND main_hwnd_;
  static HWND overlay_hwnd_;
  static bool class_registered_;
  static std::wstring primary_;
  static std::wstring secondary_;
  static std::string state_;
  static double level_;
  static double target_level_;
  static UINT_PTR anim_timer_id_;
  static std::wstring timer_text_;
  static double progress_;
};

#endif  // RUNNER_DESKTOP_VOICE_NATIVE_OVERLAY_H_

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
                   const std::string& timer_text);

  static void Hide();

  static bool IsVisible();

 private:
  static void EnsureClassRegistered();
  static void PositionOverlay();
  static void PaintOverlay(HDC hdc, const RECT& rect);
  static LRESULT CALLBACK OverlayWndProc(HWND hwnd,
                                           UINT message,
                                           WPARAM wparam,
                                           LPARAM lparam) noexcept;

  static HWND main_hwnd_;
  static HWND overlay_hwnd_;
  static bool class_registered_;
  static std::wstring primary_;
  static std::wstring secondary_;
  static std::string state_;
  static double level_;
  static std::wstring timer_text_;
};

#endif  // RUNNER_DESKTOP_VOICE_NATIVE_OVERLAY_H_

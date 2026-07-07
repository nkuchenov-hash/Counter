import 'dart:io';

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Main Counter desktop window sizing — separate from voice overlay bounds.
abstract final class DesktopMainWindow {
  static const minWidth = 1100.0;
  static const minHeight = 720.0;

  static bool _startupApplied = false;

  static Future<void> ensureInitialized() async {
    if (!Platform.isWindows) return;
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(minWidth, minHeight));
  }

  /// Maximize on startup — user expects full working-area height, not a saved
  /// medium window from a prior session.
  static Future<void> applyDefaultIfNeeded() async {
    if (!Platform.isWindows) return;

    await ensureInitialized();

    if (!await windowManager.isMaximized()) {
      final size = await windowManager.getSize();
      DesktopVoicePipeline.mark(
        'DESKTOP_MAIN_WINDOW_BOUNDS_RESET',
        '${size.width.toInt()}x${size.height.toInt()}',
      );
      await windowManager.maximize();
    }
    DesktopVoicePipeline.mark('DESKTOP_MAIN_WINDOW_DEFAULT_MAXIMIZED');
    DesktopVoicePipeline.mark('DESKTOP_MAIN_WINDOW_FULL_HEIGHT');
    DesktopVoicePipeline.mark('DESKTOP_OVERLAY_BOUNDS_SEPARATE_FROM_MAIN_WINDOW');
    _startupApplied = true;
  }

  /// Called when the user opens the main window from tray or shell.
  static Future<void> ensureSaneSizeOnShow() async {
    if (!Platform.isWindows) return;
    await ensureInitialized();

    if (!await windowManager.isMaximized()) {
      await windowManager.maximize();
    }
    DesktopVoicePipeline.mark('DESKTOP_TRAY_RESTORE_MAIN_WINDOW_SIZE_OK', 'maximized');
    DesktopVoicePipeline.mark('DESKTOP_MAIN_WINDOW_FULL_HEIGHT');
  }

  /// Post-frame hook — window_manager needs a visible HWND before bounds apply.
  static Future<void> applyAfterFirstFrame() async {
    if (!Platform.isWindows || _startupApplied) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await applyDefaultIfNeeded();
    // window_manager may restore saved bounds shortly after first show.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!await windowManager.isMaximized()) {
      await windowManager.maximize();
      DesktopVoicePipeline.mark('DESKTOP_MAIN_WINDOW_FULL_HEIGHT_RETRY');
    }
  }
}

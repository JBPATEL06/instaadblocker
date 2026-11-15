import 'dart:async';
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('adskip/native');

  /// Opens the Android Accessibility Settings page so user can enable the service.
  static Future<bool> openAccessibilitySettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Checks whether the AdSkipService AccessibilityService is enabled in Android settings.
  static Future<bool> isServiceEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isServiceEnabled');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Sets whether ad skipping is actively toggled ON in user preferences.
  static Future<bool> setEnabled(bool enabled) async {
    try {
      final res = await _channel.invokeMethod<bool>('setEnabled', {'enabled': enabled});
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Gets whether ad skipping is active.
  static Future<bool> getEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('getEnabled');
      return res ?? true;
    } on PlatformException catch (_) {
      return true;
    }
  }

  /// Retrieves the total number of skipped ads and reels.
  static Future<int> getCount() async {
    try {
      final res = await _channel.invokeMethod<int>('getCount');
      return res ?? 0;
    } on PlatformException catch (_) {
      return 0;
    }
  }

  /// Resets the skip counter to 0.
  static Future<bool> resetCount() async {
    try {
      final res = await _channel.invokeMethod<bool>('resetCount');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Fetches all per-app blocker settings in a single call.
  static Future<Map<String, dynamic>> getAllSettings() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getAllSettings');
      return res ?? {};
    } on PlatformException catch (_) {
      return {};
    }
  }

  /// Updates a specific setting (e.g. key="youtubeShorts", value=true).
  static Future<bool> setSetting(String key, dynamic value) async {
    try {
      final res = await _channel.invokeMethod<bool>('setSetting', {
        'key': key,
        'value': value,
      });
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Returns recent service activity log lines.
  static Future<List<String>> getRecentLogs() async {
    try {
      final res = await _channel.invokeListMethod<String>('getRecentLogs');
      return res ?? [];
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Clears recent activity logs.
  static Future<bool> clearLogs() async {
    try {
      final res = await _channel.invokeMethod<bool>('clearLogs');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Triggers a live UI tree dump of the active window for marker analysis.
  static Future<String> triggerDump() async {
    try {
      final res = await _channel.invokeMethod<String>('triggerDump');
      return res ?? 'No dump available.';
    } on PlatformException catch (e) {
      return 'Error capturing dump: ${e.message}';
    }
  }

  /// Starts a temporary mindful break for the specified minutes.
  static Future<bool> startBreak(int minutes) async {
    try {
      final res = await _channel.invokeMethod<bool>('startBreak', {'minutes': minutes});
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Cancels an active mindful break and immediately resumes blocking.
  static Future<bool> cancelBreak() async {
    try {
      final res = await _channel.invokeMethod<bool>('cancelBreak');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Retrieves current break status and remaining seconds.
  static Future<Map<String, dynamic>> getBreakStatus() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getBreakStatus');
      return res ?? {};
    } on PlatformException catch (_) {
      return {};
    }
  }

  /// Opens an app by package name.
  static Future<bool> openApp(String packageName) async {
    try {
      final res = await _channel.invokeMethod<bool>('openApp', {'package': packageName});
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Opens the Instagram app directly.
  static Future<bool> openInstagram() async {
    return openApp('com.instagram.android');
  }

  /// Opens battery optimization settings to prevent the service from being killed.
  static Future<bool> openBatteryOptimizationSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Opens OEM autostart settings (Xiaomi/MIUI/Oppo/Vivo) to allow running in background.
  static Future<bool> openAutostartSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAutostartSettings');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}

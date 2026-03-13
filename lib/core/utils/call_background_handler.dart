import 'package:flutter_background/flutter_background.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart';

class CallBackgroundHandler {
  static Future<void> start() async {
    try {
      // 1. Keep screen on
      await WakelockPlus.enable();

      // 2. Enable background execution (Android specific)
      if (defaultTargetPlatform == TargetPlatform.android) {
        const androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: "Safe Space",
          notificationText: "Dil se baat chal rahi hai... 🫂",
          notificationImportance: AndroidNotificationImportance.high,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        );

        bool hasPermissions = await FlutterBackground.hasPermissions;
        if (!hasPermissions) {
          await FlutterBackground.initialize(androidConfig: androidConfig);
        }

        await FlutterBackground.enableBackgroundExecution();
      }
      debugPrint('🟢 CallBackgroundHandler: Started');
    } catch (e) {
      debugPrint('🔴 CallBackgroundHandler Error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await WakelockPlus.disable();
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterBackground.disableBackgroundExecution();
      }
      debugPrint('🔴 CallBackgroundHandler: Stopped');
    } catch (e) {
      debugPrint('🔴 CallBackgroundHandler Stop Error: $e');
    }
  }
}

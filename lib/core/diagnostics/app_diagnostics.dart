import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AppDiagnostics {
  AppDiagnostics._();

  static bool _crashCollectionEnabled = false;
  static bool _handlersInstalled = false;
  static FlutterExceptionHandler? _previousFlutterErrorHandler;
  static bool Function(Object, StackTrace)? _previousPlatformErrorHandler;

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (!isSupportedPlatform) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (_) {
      // Keep the local app usable if Firebase is unavailable.
      return;
    }
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      await FirebaseAnalytics.instance.logEvent(name: 'rooko_app_open');
    } catch (_) {
      // Analytics failure does not prevent crash reporting.
    }
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _crashCollectionEnabled = true;
      _installCrashHandlers();
    } catch (_) {
      // Crash reporting failure does not prevent app startup.
    }
  }

  static void _installCrashHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    _previousFlutterErrorHandler = FlutterError.onError;
    _previousPlatformErrorHandler = PlatformDispatcher.instance.onError;

    FlutterError.onError = (details) {
      (_previousFlutterErrorHandler ?? FlutterError.presentError)(details);
      if (_crashCollectionEnabled) {
        unawaited(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      }
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      if (!_crashCollectionEnabled) {
        return _previousPlatformErrorHandler?.call(error, stackTrace) ?? false;
      }
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: true,
        ),
      );
      return true;
    };
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/diagnostics/app_diagnostics.dart';
import 'core/design_system/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var onboardingComplete = false;
  var appearance = AppAppearance.system;

  try {
    final preferences = await SharedPreferences.getInstance();
    onboardingComplete =
        preferences.getBool('rooko_onboarding_complete') ?? false;
    appearance = AppAppearance.values.firstWhere(
      (value) => value.name == preferences.getString('rooko_appearance'),
      orElse: () => AppAppearance.system,
    );
  } catch (_) {
    // Keep onboarding reachable if local preferences cannot be read.
  }

  runApp(
    RookoApp(
      onboardingComplete: onboardingComplete,
      initialAppearance: appearance,
    ),
  );
  unawaited(AppDiagnostics.initialize());
}

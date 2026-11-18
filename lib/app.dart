import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/design_system/app_colors.dart';
import 'core/design_system/app_theme.dart';
import 'features/onboarding/app_flow_screen.dart';

class RookoApp extends StatefulWidget {
  const RookoApp({
    super.key,
    this.onboardingComplete = false,
    this.initialAppearance = AppAppearance.system,
  });

  final bool onboardingComplete;
  final AppAppearance initialAppearance;

  @override
  State<RookoApp> createState() => _RookoAppState();
}

class _RookoAppState extends State<RookoApp> {
  static const _appearanceKey = 'rooko_appearance';
  late AppAppearance _appearance = widget.initialAppearance;

  Future<void> _setAppearance(AppAppearance appearance) async {
    setState(() => _appearance = appearance);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_appearanceKey, appearance.name);
    } catch (_) {
      // The current screen remains usable if preference storage is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rooko',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: _appearance == AppAppearance.amoled
          ? AppTheme.amoledBlack
          : AppTheme.dark,
      themeMode: switch (_appearance) {
        AppAppearance.system => ThemeMode.system,
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark || AppAppearance.amoled => ThemeMode.dark,
      },
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final statusBarColor = !isDark
            ? AppColors.canvasLight
            : _appearance == AppAppearance.amoled
            ? AppColors.canvasAmoled
            : AppColors.canvasDark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: statusBarColor,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: AppColors.canvasAmoled,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AppFlowScreen(
        onboardingComplete: widget.onboardingComplete,
        appearance: _appearance,
        onAppearanceChanged: _setAppearance,
      ),
    );
  }
}

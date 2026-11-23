import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

typedef AppIconData = List<List<dynamic>>;

/// Icon sizes used across Rooko. Tap targets belong to the controls.
abstract final class AppIconSizes {
  static const double badge = 13;
  static const double small = 18;
  static const double standard = 22;
  static const double large = 28;
}

/// Semantic roles mapped to the free HugeIcons stroke-rounded set.
///
/// Add an entry here when a product screen needs a new icon. Screens should
/// use these names instead of importing HugeIcons directly.
abstract final class AppIcons {
  // Primary destinations and product concepts.
  static const home = HugeIcons.strokeRoundedHome01;
  static const progress = HugeIcons.strokeRoundedAnalytics01;
  static const battle = HugeIcons.strokeRoundedSwords;
  static const limits = HugeIcons.strokeRoundedTarget01;
  static const settings = HugeIcons.strokeRoundedSettings01;
  static const sourceApp = HugeIcons.strokeRoundedAndroid;
  static const insight = HugeIcons.strokeRoundedBarChart;

  // Permissions, status, and safety.
  static const permission = HugeIcons.strokeRoundedAccessibility;
  static const warning = HugeIcons.strokeRoundedAlert01;
  static const success = HugeIcons.strokeRoundedCheckmarkCircle01;
  static const privacy = HugeIcons.strokeRoundedShield01;
  static const lock = HugeIcons.strokeRoundedLock;

  // Actions and device features.
  static const export = HugeIcons.strokeRoundedDownload01;
  static const delete = HugeIcons.strokeRoundedTrash;
  static const help = HugeIcons.strokeRoundedHelpCircle;
  static const featureRequest = HugeIcons.strokeRoundedBulb;
  static const email = HugeIcons.strokeRoundedMail01;
  static const externalLink = HugeIcons.strokeRoundedExternalLink;
  static const sync = HugeIcons.strokeRoundedRefresh01;
  static const nfc = HugeIcons.strokeRoundedNfc;
  static const steps = HugeIcons.strokeRoundedWalking;
  static const pause = HugeIcons.strokeRoundedPause;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const closeCircle = HugeIcons.strokeRoundedCancelCircle;
  static const back = HugeIcons.strokeRoundedArrowLeft01;
  static const next = HugeIcons.strokeRoundedArrowRight01;
  static const timer = HugeIcons.strokeRoundedClock01;
  static const phone = HugeIcons.strokeRoundedSmartPhone01;
  static const screenTime = HugeIcons.strokeRoundedTimeSchedule;
  static const accessSettings = HugeIcons.strokeRoundedFingerAccess;
  static const privacyCheck = HugeIcons.strokeRoundedShieldCheck;
  static const appearance = HugeIcons.strokeRoundedSun03;
  static const notification = HugeIcons.strokeRoundedNotification01;
  static const check = HugeIcons.strokeRoundedCheckmarkCircle02;
}

/// Renders a registry glyph using the surrounding [IconTheme].
///
/// Decorative icons are excluded from semantics. Pass [semanticLabel] when
/// the icon carries meaning without nearby text, such as in an icon-only
/// control.
class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    required this.icon,
    this.semanticLabel,
    this.size,
    this.color,
    this.strokeWidth,
  });

  final AppIconData icon;
  final String? semanticLabel;
  final double? size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final glyph = HugeIcon(
      icon: icon,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
    );

    return semanticLabel == null
        ? ExcludeSemantics(child: glyph)
        : Semantics(label: semanticLabel, image: true, child: glyph);
  }
}

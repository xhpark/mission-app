import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class LearningTextEmphasis {
  const LearningTextEmphasis._();

  static TextStyle? meaningPrompt(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.headlineMedium;
    return base?.copyWith(
      fontSize: _atLeast(base.fontSize, 34),
      fontWeight: FontWeight.w800,
      color: AppColors.pronunciation,
      height: 1.25,
    );
  }

  static TextStyle? pronunciation(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.titleLarge;
    return base?.copyWith(
      fontSize: _atLeast(base.fontSize, 30),
      fontWeight: FontWeight.w800,
      color: AppColors.pronunciation,
      height: 1.25,
    );
  }

  static TextStyle? optionPronunciation(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.titleLarge;
    return base?.copyWith(
      fontSize: _atLeast(base.fontSize, 24),
      fontWeight: FontWeight.w800,
      color: AppColors.pronunciation,
      height: 1.25,
    );
  }

  static TextStyle? foreignScript(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.headlineSmall;
    return base?.copyWith(
      fontSize: _atLeast(base.fontSize, 28),
      fontWeight: FontWeight.w700,
      color: AppColors.pronunciation,
      height: 1.25,
    );
  }

  static TextStyle? supportingMeaning(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.titleLarge;
    return base?.copyWith(
      fontSize: _atLeast(base.fontSize, 26),
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
      height: 1.3,
    );
  }

  static double _atLeast(double? value, double minimum) {
    final current = value ?? minimum;
    return current < minimum ? minimum : current;
  }
}

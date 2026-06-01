import 'package:flutter/material.dart';

/// semantic color palette for the eda suite
abstract final class AppColors {
  // -- surface & background --
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceVariant = Color(0xFF1C2333);
  static const Color panel = Color(0xFF13171F);
  static const Color panelBorder = Color(0xFF2A3040);

  // -- primary accent (cyan for traces/signals) --
  static const Color primary = Color(0xFF58A6FF);
  static const Color primaryMuted = Color(0xFF1F4068);

  // -- secondary accent (green for active/success) --
  static const Color secondary = Color(0xFF3FB950);
  static const Color secondaryMuted = Color(0xFF1B3826);

  // -- warning (amber for design warnings) --
  static const Color warning = Color(0xFFD29922);
  static const Color warningMuted = Color(0xFF3D2E00);

  // -- error (red for faults/shorts) --
  static const Color error = Color(0xFFF85149);
  static const Color errorMuted = Color(0xFF3D1418);

  // -- text --
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  // -- grid & canvas --
  static const Color gridDot = Color(0xFF4A5568);
  static const Color gridLine = Color(0xFF1B2029);
  static const Color wire = Color(0xFF58A6FF);
  static const Color wireSelected = Color(0xFF79C0FF);
  static const Color componentStroke = Color(0xFFC9D1D9);
  static const Color componentFill = Color(0xFF161B22);

  // -- misc --
  static const Color divider = Color(0xFF21262D);
  static const Color tooltip = Color(0xFF1C2333);
  static const Color selection = Color(0x3358A6FF);
}

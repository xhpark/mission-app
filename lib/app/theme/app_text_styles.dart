import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// App-wide typography rule: widget/section *names* (headings, card titles)
/// use a bold Gothic/sans face in [AppColors.titleAccent] instead of plain
/// black, while everything else (selectable option labels, descriptions,
/// body copy) uses a lighter-weight Myeongjo/serif face. See
/// [AppSectionCard] and `_ChoiceChipRow` for where this split is applied.
class AppTextStyles {
  static TextStyle get heading => GoogleFonts.notoSansKr(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.22,
    color: AppColors.titleAccent,
  );

  static TextStyle get title => GoogleFonts.notoSansKr(
    fontSize: 23,
    fontWeight: FontWeight.w800,
    height: 1.32,
    color: AppColors.titleAccent,
  );

  static TextStyle get body => GoogleFonts.notoSerifKr(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  static TextStyle get bodySmall => GoogleFonts.notoSerifKr(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
}

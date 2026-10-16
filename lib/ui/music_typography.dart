import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App chrome stays English/Roboto. Only actual Persian music metadata uses
/// Vazirmatn (modern Vazir family); runtime font is cached by google_fonts.
/// When offline before its first download, the platform falls back to Tahoma.
TextStyle musicTextStyle(String text, TextStyle style) {
  if (!RegExp(r'[\u0600-\u06FF\u0750-\u077F]').hasMatch(text)) {
    return style;
  }
  return GoogleFonts.vazirmatn(textStyle: style.copyWith(
    fontFamilyFallback: const ['Vazir', 'Tahoma', 'Segoe UI'],
  ));
}

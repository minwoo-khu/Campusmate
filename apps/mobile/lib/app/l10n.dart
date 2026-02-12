import 'package:flutter/material.dart';

extension CampusMateL10nX on BuildContext {
  bool get isEnglish =>
      Localizations.localeOf(this).languageCode.toLowerCase().startsWith('en');

  String tr(String ko, String en) => isEnglish ? en : ko;
}

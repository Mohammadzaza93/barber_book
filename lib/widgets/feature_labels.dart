import 'package:flutter/widgets.dart';

class FeatureLabels {
  static String text(BuildContext context, String ar, String en) {
    return Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  }
}

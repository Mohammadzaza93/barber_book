import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Shorthand for `AppLocalizations.of(context)`.
AppLocalizations t(BuildContext context) => AppLocalizations.of(context);

String fmtPrice(double amount, String currency) {
  final n = amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  return '$n $currency';
}

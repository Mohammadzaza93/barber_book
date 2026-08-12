import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/appointment_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/discount_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/feedback_provider.dart';
import 'providers/language_provider.dart';
import 'providers/shop_provider.dart';
import 'screens/root_gate.dart';

class BarberApp extends StatelessWidget {
  const BarberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => DiscountProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => FeedbackProvider()),
      ],
      child: const _Material(),
    );
  }
}

class _Material extends StatelessWidget {
  const _Material();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return MaterialApp(
      title: 'BarberBook',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(useMaterial3: true),
      locale: lang.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootGate(),
    );
  }
}

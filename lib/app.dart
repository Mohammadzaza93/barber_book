import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/appointment_provider.dart';
import 'providers/business_tools_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/discount_provider.dart';
import 'providers/feedback_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/language_provider.dart';
import 'providers/ops_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/team_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/root_gate.dart';
import 'theme/app_theme.dart';

class BarberApp extends StatelessWidget {
  const BarberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => BusinessToolsProvider()),
        ChangeNotifierProvider(create: (_) => DiscountProvider()),
        ChangeNotifierProvider(create: (_) => FeedbackProvider()),
        ChangeNotifierProvider(
          create: (context) => ConnectionProvider(
            onReconnected: context.read<AuthProvider>().reconcileShopTopic,
          )..start(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, FinanceProvider>(
          create: (_) => FinanceProvider(),
          update: (_, auth, finance) {
            finance ??= FinanceProvider();
            finance.bind(auth.shopId);
            return finance;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, TeamProvider>(
          create: (_) => TeamProvider(),
          update: (_, auth, team) {
            team ??= TeamProvider();
            team.bind(auth.shopId);
            return team;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, OpsProvider>(
          create: (_) => OpsProvider(),
          update: (_, auth, ops) {
            ops ??= OpsProvider();
            ops.bind(auth.shopId);
            return ops;
          },
        ),
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
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'BarberBook',
      debugShowCheckedModeBanner: false,
      themeMode: theme.mode,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
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

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/app_role.dart';
import '../../models/staff_permissions.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/connection_banner.dart';
import '../../widgets/feature_labels.dart';
import '../../widgets/live_badge.dart';
import '../profile_screen.dart';
import 'appointments_screen.dart';
import 'business_tools_screen.dart';
import 'dashboard_screen.dart';
import 'discounts_screen.dart';
import 'feedback_screen.dart';
import 'finance/finance_home_screen.dart';
import 'ops/ops_security_screen.dart';
import 'reports_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'staff_screen.dart';
import 'unavailability_screen.dart';

const Set<int> adminTabsSet = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};

bool adminTabVisible(AppRole role, int index, {StaffPermissions? perms}) {
  if (role.isAdmin) {
    return adminTabsSet.contains(index);
  }
  final p = perms ?? StaffPermissions.minimal;
  switch (index) {
    case 0:
      return false;
    case 1:
      return p.appointments;
    case 2:
      return p.services;
    case 3:
      return p.staff;
    case 4:
      return p.discounts;
    case 5:
      return p.feedback;
    case 6:
      return p.outOfHours;
    case 7:
      return p.reports;
    case 8:
      return p.settings;
    case 9:
      return p.businessTools;
    case 10:
      return true;
    case 11:
      return p.finance;
    default:
      return false;
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;
  final Set<int> _visited = {0};

  bool _visibleFor(BuildContext context, int index) {
    final auth = context.read<AuthProvider>();
    return adminTabVisible(auth.role, index, perms: auth.permissions);
  }

  final _screens = const [
    DashboardScreen(),
    AppointmentsScreen(),
    ServicesScreen(),
    StaffScreen(),
    DiscountsScreen(),
    FeedbackScreen(),
    UnavailabilityScreen(),
    ReportsScreen(),
    SettingsScreen(),
    BusinessToolsScreen(),
    ProfileScreen(),
    FinanceHomeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final primary =
        parseHexColor(shop.settings?.primaryColorHex ?? '0xFF121316');
    final accent =
        parseHexColor(shop.settings?.accentColorHex ?? '0xFFC6CBD4');
    final brightness = Theme.of(context).brightness;
    final theme = buildAppTheme(
      primary: primary,
      accent: accent,
      brightness: brightness,
    );

    return Theme(
      data: theme,
      child: Consumer<AppointmentProvider>(
        builder: (context, appointments, _) {
          final pendingCount = appointments.pendingRequests.length;
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      shop.settings?.shopName ?? 'BarberBook',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const LiveBadge(compact: true),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: brightness == Brightness.dark
                      ? 'المظهر الفاتح'
                      : 'المظهر الداكن',
                  onPressed: () =>
                      context.read<ThemeProvider>().toggleLightDark(context),
                  icon: Icon(
                    brightness == Brightness.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                ),
                IconButton(
                  tooltip: t(context).openBookingPage,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(openShare: true),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
            drawer: _buildDrawer(context, pendingCount),
            body: Column(
              children: [
                const ConnectionBanner(),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      for (var i = 0; i < _screens.length; i++)
                        _visited.contains(i)
                            ? _screens[i]
                            : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, int pendingCount) {
    final lang = context.watch<LanguageProvider>();
    final themeProv = context.watch<ThemeProvider>();
    final shop = context.read<ShopProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B0B0D),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: SvgPicture.asset(
                      'assets/brand/logo.svg',
                      colorFilter: const ColorFilter.mode(
                          Color(0xFFC6CBD4), BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.settings?.shopName ?? 'BarberBook',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        const LiveBadge(compact: true),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: t(context).language,
                    onPressed: () => lang.setLocale(
                      lang.isArabic ? const Locale('en') : const Locale('ar'),
                    ),
                    icon: Text(
                      lang.isArabic ? 'EN' : 'عربي',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  if (_visibleFor(context, 0))
                    _item(context, 0, Icons.dashboard_outlined, Icons.dashboard,
                        t(context).dashboard),
                  if (_visibleFor(context, 1))
                    _item(context, 1, Icons.event_note_outlined,
                        Icons.event_note, t(context).appointments),
                  if (_visibleFor(context, 2))
                    _item(context, 2, Icons.content_cut_outlined,
                        Icons.content_cut, t(context).servicesManagement),
                  if (_visibleFor(context, 3))
                    _item(context, 3, Icons.people_outline_rounded,
                        Icons.people_rounded, t(context).staff),
                  if (_visibleFor(context, 4))
                    _item(context, 4, Icons.local_offer_outlined,
                        Icons.local_offer, t(context).discounts),
                  if (_visibleFor(context, 5))
                    _item(context, 5, Icons.star_outline_rounded,
                        Icons.star_rounded, t(context).feedback),
                  if (_visibleFor(context, 6))
                    _item(
                      context,
                      6,
                      Icons.schedule_send_outlined,
                      Icons.schedule_send,
                      t(context).requestOutOfHours,
                      badge: pendingCount,
                    ),
                  if (_visibleFor(context, 7))
                    _item(context, 7, Icons.insights_outlined, Icons.insights,
                        t(context).reports),
                  if (_visibleFor(context, 8))
                    _item(context, 8, Icons.tune_rounded, Icons.tune,
                        t(context).bookingPageSettings),
                  if (_visibleFor(context, 9))
                    _item(
                      context,
                      9,
                      Icons.business_center_outlined,
                      Icons.business_center,
                      FeatureLabels.text(
                          context, 'أدوات الأعمال', 'Business Tools'),
                    ),
                  if (_visibleFor(context, 10))
                    _item(context, 10, Icons.person_outline_rounded,
                        Icons.person_rounded, t(context).profile),
                  if (_visibleFor(context, 11))
                    _item(
                      context,
                      11,
                      Icons.account_balance_wallet_outlined,
                      Icons.account_balance_wallet_rounded,
                      FeatureLabels.text(
                          context, 'المالية والمحاسبة', 'Finance & Accounting'),
                    ),
                ],
              ),
            ),
            const Divider(),
            SwitchListTile(
              secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              ),
              title: Text(isDark ? 'المظهر الداكن' : 'المظهر الفاتح'),
              subtitle: Text(
                switch (themeProv.mode) {
                  ThemeMode.system => 'حسب النظام',
                  ThemeMode.light => 'فاتح ثابت',
                  ThemeMode.dark => 'داكن ثابت',
                },
                style: const TextStyle(fontSize: 12),
              ),
              value: isDark,
              onChanged: (_) =>
                  context.read<ThemeProvider>().toggleLightDark(context),
            ),
            ListTile(
              leading: const Icon(Icons.security_rounded),
              title: const Text('الأمان والنسخ الاحتياطي'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OpsSecurityScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(t(context).shareBookingLink),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(openShare: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int index,
    IconData icon,
    IconData selectedIcon,
    String label, {
    int? badge,
  }) {
    final selected = _index == index;
    return ListTile(
      leading: Badge(
        isLabelVisible: (badge ?? 0) > 0,
        label: Text('$badge'),
        child: Icon(selected ? selectedIcon : icon),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      selected: selected,
      selectedTileColor:
          Theme.of(context).colorScheme.primary.withOpacity(0.08),
      onTap: () {
        setState(() {
          _index = index;
          _visited.add(index);
        });
        Navigator.pop(context);
      },
    );
  }
}

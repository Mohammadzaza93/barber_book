import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/app_role.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/shop_provider.dart';
import '../../theme/app_theme.dart';
import '../customer/booking_flow_screen.dart';
import '../profile_screen.dart';
import 'dashboard_screen.dart';
import 'appointments_screen.dart';
import 'discounts_screen.dart';
import 'expenses_screen.dart';
import 'feedback_screen.dart';
import 'reports_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'business_tools_screen.dart';
import 'staff_screen.dart';
import 'unavailability_screen.dart';

/// Admin shell tab indices, in the same order as `_AdminHomeScreenState._screens`:
/// 0 dashboard, 1 appointments, 2 services, 3 staff, 4 discounts, 5 expenses,
/// 6 feedback, 7 out-of-hours requests, 8 reports, 9 booking-page settings,
/// 10 business tools, 11 profile.
///
/// This is a UI-only capability map. Hiding a tab is a UX affordance, not a
/// security boundary — the backend rules and callables remain authoritative and
/// reject unauthorized operations regardless of what the UI renders.
const Set<int> ownerManagerAdminTabs = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
const Set<int> staffAdminTabs = {0, 1, 2, 3, 7, 11};

/// Pure capability check so the navigation policy can be unit-tested without a
/// widget tree.
bool adminTabVisible(AppRole role, int index) {
  if (role == AppRole.owner || role == AppRole.manager) {
    return ownerManagerAdminTabs.contains(index);
  }
  return staffAdminTabs.contains(index);
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  /// Tabs that have been opened. Restricted tabs are never built until visited,
  /// so a staff session does not initialise manager-only screens/listeners just
  /// because the admin shell is mounted.
  final Set<int> _visited = {0};

  bool _visibleFor(BuildContext context, int index) =>
      adminTabVisible(context.read<AuthProvider>().role, index);

  final _screens = const [
    DashboardScreen(),
    AppointmentsScreen(),
    ServicesScreen(),
    StaffScreen(),
    DiscountsScreen(),
    ExpensesScreen(),
    FeedbackScreen(),
    UnavailabilityScreen(),
    ReportsScreen(),
    SettingsScreen(),
    BusinessToolsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final primary = parseHexColor(shop.settings?.primaryColorHex ?? '0xFF121316');
    final accent = parseHexColor(shop.settings?.accentColorHex ?? '0xFFC6CBD4');
    final theme = buildAppTheme(primary: primary, accent: accent);

    return Theme(
      data: theme,
      child: Consumer<AppointmentProvider>(
        builder: (context, appointments, _) {
          final pendingCount = appointments.pendingRequests.length;
          return Scaffold(
            appBar: AppBar(
              title: Text(shop.settings?.shopName ?? 'BarberBook'),
              actions: [
                IconButton(
                  tooltip: t(context).openBookingPage,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookingFlowScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
            drawer: _buildDrawer(context, pendingCount),
            body: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _screens.length; i++)
                  _visited.contains(i) ? _screens[i] : const SizedBox.shrink(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, int pendingCount) {
    final lang = context.watch<LanguageProvider>();
    final shop = context.read<ShopProvider>();
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
                        Text(
                          t(context).appName,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
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
                  if (_visibleFor(context, 0)) _item(context, 0, Icons.dashboard_outlined, Icons.dashboard, t(context).dashboard),
                  if (_visibleFor(context, 1)) _item(context, 1, Icons.event_note_outlined, Icons.event_note, t(context).appointments),
                  if (_visibleFor(context, 2)) _item(context, 2, Icons.content_cut_outlined, Icons.content_cut, t(context).servicesManagement),
                  if (_visibleFor(context, 3)) _item(context, 3, Icons.people_outline_rounded, Icons.people_rounded, t(context).staff),
                  if (_visibleFor(context, 4)) _item(context, 4, Icons.local_offer_outlined, Icons.local_offer, t(context).discounts),
                  if (_visibleFor(context, 5)) _item(context, 5, Icons.payments_outlined, Icons.payments, t(context).expenses),
                  if (_visibleFor(context, 6)) _item(context, 6, Icons.star_outline_rounded, Icons.star_rounded, t(context).feedback),
                  if (_visibleFor(context, 7))
                    _item(
                      context,
                      7,
                      Icons.schedule_send_outlined,
                      Icons.schedule_send,
                      t(context).requestOutOfHours,
                      badge: pendingCount,
                    ),
                  if (_visibleFor(context, 8)) _item(context, 8, Icons.insights_outlined, Icons.insights, t(context).reports),
                  if (_visibleFor(context, 9)) _item(context, 9, Icons.tune_rounded, Icons.tune, t(context).bookingPageSettings),
                  if (_visibleFor(context, 10)) _item(context, 10, Icons.business_center_outlined, Icons.business_center, 'أدوات الأعمال'),
                  if (_visibleFor(context, 11)) _item(context, 11, Icons.person_outline_rounded, Icons.person_rounded, t(context).profile),
                ],
              ),
            ),
            const Divider(),
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

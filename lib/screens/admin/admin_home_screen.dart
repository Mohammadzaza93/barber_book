import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../providers/appointment_provider.dart';
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
import 'staff_screen.dart';
import 'unavailability_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

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
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final primary = parseHexColor(shop.settings?.primaryColorHex ?? '0xFF111827');
    final accent = parseHexColor(shop.settings?.accentColorHex ?? '0xFF2563EB');
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
            body: IndexedStack(index: _index, children: _screens),
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
                  CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.content_cut_rounded,
                        color: Colors.white),
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
                  _item(context, 0, Icons.dashboard_outlined, Icons.dashboard, t(context).dashboard),
                  _item(context, 1, Icons.event_note_outlined, Icons.event_note, t(context).appointments),
                  _item(context, 2, Icons.content_cut_outlined, Icons.content_cut, t(context).servicesManagement),
                  _item(context, 3, Icons.people_outline_rounded, Icons.people_rounded, t(context).staff),
                  _item(context, 4, Icons.local_offer_outlined, Icons.local_offer, t(context).discounts),
                  _item(context, 5, Icons.payments_outlined, Icons.payments, t(context).expenses),
                  _item(context, 6, Icons.star_outline_rounded, Icons.star_rounded, t(context).feedback),
                  _item(
                    context,
                    7,
                    Icons.schedule_send_outlined,
                    Icons.schedule_send,
                    t(context).requestOutOfHours,
                    badge: pendingCount,
                  ),
                  _item(context, 8, Icons.insights_outlined, Icons.insights, t(context).reports),
                  _item(context, 9, Icons.tune_rounded, Icons.tune, t(context).bookingPageSettings),
                  _item(context, 10, Icons.person_outline_rounded, Icons.person_rounded, t(context).profile),
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
        setState(() => _index = index);
        Navigator.pop(context);
      },
    );
  }
}

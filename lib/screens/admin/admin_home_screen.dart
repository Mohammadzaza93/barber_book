import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
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
import 'admin_navigation.dart';
import 'appointments_screen.dart';
import 'business_tools_screen.dart';
import 'dashboard_screen.dart';
import 'discounts_screen.dart';
import 'feedback_screen.dart';
import 'finance/finance_home_screen.dart';
import 'inventory_tab.dart';
import 'ops/ops_security_screen.dart';
import 'reports_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'staff_screen.dart';
import 'unavailability_screen.dart';

// Keep the old import surface (`admin_home_screen.dart`) working for callers
// and tests that referenced the navigation helpers from this file.
export 'admin_navigation.dart'
    show
        AdminNavSection,
        AdminNavigationController,
        AdminNavigationScope,
        adminSections,
        adminTabVisible,
        adminTabsSet,
        primaryAdminTabs;

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const double _wideBreakpoint = 760;

  int _index = 0;
  final Set<int> _visited = <int>{};

  String? _themeKey;
  ThemeData? _theme;

  late final AdminNavigationController _navController =
      AdminNavigationController(_handleSelect);

  final _screens = const [
    DashboardScreen(),
    AppointmentsScreen(),
    ServicesScreen(),
    StaffScreen(),
    DiscountsScreen(),
    FeedbackScreen(),
    UnavailabilityScreen(),
    ReportsScreen(),
    SettingsScreen(embedded: true),
    BusinessToolsScreen(),
    ProfileScreen(embedded: true),
    FinanceHomeScreen(embedded: true),
    InventoryTab(embedded: true),
  ];

  void _handleSelect(int index) => _goTo(index);

  void _goTo(int index, {AuthProvider? auth}) {
    final provider = auth ?? context.read<AuthProvider>();
    if (!adminTabVisible(
      provider.role,
      index,
      perms: provider.permissions,
    )) {
      return;
    }
    if (!mounted) return;
    if (_index == index && _visited.contains(index)) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  int _homeIndex(AuthProvider auth) {
    for (final section in adminSections) {
      if (adminTabVisible(
        auth.role,
        section.index,
        perms: auth.permissions,
      )) {
        return section.index;
      }
    }
    return 10;
  }

  ThemeData _themeFor(String primaryHex, String accentHex, Brightness b) {
    final key = '$primaryHex|$accentHex|${b.name}';
    final cached = _theme;
    if (cached != null && _themeKey == key) return cached;
    _themeKey = key;
    return _theme = buildAppTheme(
      primary: parseHexColor(primaryHex),
      accent: parseHexColor(accentHex),
      brightness: b,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shopName = context.select<ShopProvider, String>(
      (s) => s.settings?.shopName ?? 'BarberBook',
    );
    final primaryHex = context.select<ShopProvider, String>(
      (s) => s.settings?.primaryColorHex ?? defaultPrimaryHex,
    );
    final accentHex = context.select<ShopProvider, String>(
      (s) => s.settings?.accentColorHex ?? defaultAccentHex,
    );
    final brightness = Theme.of(context).brightness;
    final theme = _themeFor(primaryHex, accentHex, brightness);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    bool visible(int index) => adminTabVisible(
          auth.role,
          index,
          perms: auth.permissions,
        );

    final homeIndex = _homeIndex(auth);
    final effectiveIndex = visible(_index) ? _index : homeIndex;
    final visibleSections =
        adminSections.where((s) => visible(s.index)).toList(growable: false);
    final primary = primaryAdminTabs(auth.role, perms: auth.permissions);
    final primarySections = <AdminNavSection>[
      for (final index in primary)
        adminSections.firstWhere((s) => s.index == index),
    ];
    final moreSections = visibleSections
        .where((s) => !primary.contains(s.index))
        .toList(growable: false);

    return Theme(
      data: theme,
      child: AdminNavigationScope(
        controller: _navController,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (effectiveIndex != homeIndex) {
              setState(() => _index = homeIndex);
              return;
            }
            final leave = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('إغلاق التطبيق؟'),
                content: const Text('هل تريد الخروج من لوحة تحكم الصالون؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('خروج'),
                  ),
                ],
              ),
            );
            if (leave == true) {
              SystemNavigator.pop();
            }
          },
          child: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Scaffold(
              appBar: AppBar(
                titleSpacing: 0,
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        shopName,
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
              drawer: _AdminDrawer(
                shopName: shopName,
                sections: visibleSections,
                selectedIndex: effectiveIndex,
                onSelect: (index) => _goTo(index, auth: auth),
              ),
              body: Column(
                children: [
                  const ConnectionBanner(),
                  Expanded(
                    child: isWide
                        ? Row(
                            children: [
                              NavigationRail(
                                selectedIndex: _railIndex(
                                  primarySections,
                                  effectiveIndex,
                                ),
                                onDestinationSelected: (i) => _onRailSelected(
                                  i,
                                  primarySections,
                                  moreSections,
                                  auth,
                                ),
                                groupAlignment: -0.9,
                                labelType:
                                    MediaQuery.sizeOf(context).width >= 1080
                                        ? NavigationRailLabelType.all
                                        : NavigationRailLabelType.none,
                                destinations: _railDestinations(
                                  primarySections,
                                  moreSections,
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: _tabStack(effectiveIndex, visible),
                              ),
                            ],
                          )
                        : _tabStack(effectiveIndex, visible),
                  ),
                ],
              ),
              bottomNavigationBar: isWide
                  ? null
                  : _bottomBar(
                      primarySections,
                      moreSections,
                      effectiveIndex,
                      auth,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabStack(int effectiveIndex, bool Function(int) visible) {
    return IndexedStack(
      index: effectiveIndex,
      children: [
        for (var i = 0; i < _screens.length; i++)
          ((_visited.contains(i) || i == effectiveIndex) && visible(i))
              ? _screens[i]
              : const SizedBox.shrink(),
      ],
    );
  }

  int _railIndex(
    List<AdminNavSection> primary,
    int effectiveIndex,
  ) {
    final found = primary.indexWhere((s) => s.index == effectiveIndex);
    return found >= 0 ? found : primary.length;
  }

  void _onRailSelected(
    int position,
    List<AdminNavSection> primary,
    List<AdminNavSection> more,
    AuthProvider auth,
  ) {
    if (position >= primary.length) {
      _openMoreSheet(more);
      return;
    }
    _goTo(primary[position].index, auth: auth);
  }

  List<NavigationRailDestination> _railDestinations(
    List<AdminNavSection> primary,
    List<AdminNavSection> more,
  ) {
    return [
      for (final section in primary)
        NavigationRailDestination(
          icon: _sectionIcon(section, selected: false),
          selectedIcon: _sectionIcon(section, selected: true),
          label: Text(section.navLabel(context)),
        ),
      NavigationRailDestination(
        icon: const Icon(Icons.grid_view_rounded),
        selectedIcon: const Icon(Icons.grid_view_rounded),
        label: Text(FeatureLabels.text(context, 'المزيد', 'More')),
      ),
    ];
  }

  Widget _bottomBar(
    List<AdminNavSection> primary,
    List<AdminNavSection> more,
    int effectiveIndex,
    AuthProvider auth,
  ) {
    final selected = _railIndex(primary, effectiveIndex);
    return NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (position) {
        if (position >= primary.length) {
          _openMoreSheet(more);
          return;
        }
        _goTo(primary[position].index, auth: auth);
      },
      destinations: [
        for (final section in primary)
          NavigationDestination(
            icon: _sectionIcon(section, selected: false),
            selectedIcon: _sectionIcon(section, selected: true),
            label: section.navLabel(context),
            tooltip: section.label(context),
          ),
        NavigationDestination(
          icon: const Icon(Icons.grid_view_rounded),
          selectedIcon: const Icon(Icons.grid_view_rounded),
          label: FeatureLabels.text(context, 'المزيد', 'More'),
          tooltip: FeatureLabels.text(context, 'كل الأقسام', 'All sections'),
        ),
      ],
    );
  }

  Widget _sectionIcon(AdminNavSection section, {required bool selected}) {
    final icon = Icon(selected ? section.selectedIcon : section.icon);
    if (section.index == 1) return _PendingBadge(child: icon);
    return icon;
  }

  Future<void> _openMoreSheet(List<AdminNavSection> sections) async {
    if (sections.isEmpty) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _MoreSectionsSheet(sections: sections),
    );
    if (picked != null) _goTo(picked);
  }
}

class _MoreSectionsSheet extends StatelessWidget {
  const _MoreSectionsSheet({required this.sections});

  final List<AdminNavSection> sections;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              FeatureLabels.text(context, 'كل الأقسام', 'All sections'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          for (final section in sections)
            ListTile(
              leading: section.index == 1
                  ? _PendingBadge(child: Icon(section.icon))
                  : Icon(section.icon),
              title: Text(section.label(context)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, section.index),
            ),
        ],
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pending = context.select<AppointmentProvider, int>(
      (a) => a.pendingRequests.length,
    );
    return Badge(
      isLabelVisible: pending > 0,
      label: Text('$pending'),
      child: child,
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.shopName,
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
  });

  final String shopName;
  final List<AdminNavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final themeProv = context.watch<ThemeProvider>();
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
                        Color(0xFFC6CBD4),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
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
                  for (final section in sections)
                    ListTile(
                      leading: section.index == 1
                          ? _PendingBadge(child: Icon(section.icon))
                          : Icon(
                              selectedIndex == section.index
                                  ? section.selectedIcon
                                  : section.icon,
                            ),
                      title: Text(
                        section.label(context),
                        style: TextStyle(
                          fontWeight: selectedIndex == section.index
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      selected: selectedIndex == section.index,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.08),
                      onTap: () {
                        onSelect(section.index);
                        Navigator.pop(context);
                      },
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
                  MaterialPageRoute(builder: (_) => const OpsSecurityScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(t(context).shareBookingLink),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(openShare: true),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

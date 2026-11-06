import 'package:flutter/material.dart';

import '../../models/app_role.dart';
import '../../models/staff_permissions.dart';
import '../../widgets/feature_labels.dart';

/// كل تبويبات لوحة الإدارة. الترتيب هو معرّف التبويب المستخدم في التنقّل.
const Set<int> adminTabsSet = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};

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
    case 12:
      return p.finance || p.businessTools;
    default:
      return false;
  }
}

/// عنصر تنقّل واحد مع تسمية عربية وإنجليزية.
class AdminNavSection {
  const AdminNavSection({
    required this.index,
    required this.ar,
    required this.en,
    required this.icon,
    required this.selectedIcon,
    this.shortAr,
    this.shortEn,
  });

  final int index;
  final String ar;
  final String en;
  final IconData icon;
  final IconData selectedIcon;

  /// Optional compact label for the bottom bar / rail, where space is tight.
  final String? shortAr;
  final String? shortEn;

  String label(BuildContext context) => FeatureLabels.text(context, ar, en);

  String navLabel(BuildContext context) =>
      FeatureLabels.text(context, shortAr ?? ar, shortEn ?? en);
}

/// كل الأقسام المتاحة في التطبيق، بترتيب معرّفات التبويبات.
const List<AdminNavSection> adminSections = [
  AdminNavSection(
    index: 0,
    ar: 'لوحة التحكم',
    en: 'Dashboard',
    shortAr: 'الرئيسية',
    shortEn: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
  AdminNavSection(
    index: 1,
    ar: 'المواعيد',
    en: 'Appointments',
    shortAr: 'المواعيد',
    shortEn: 'Bookings',
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note_rounded,
  ),
  AdminNavSection(
    index: 2,
    ar: 'الخدمات',
    en: 'Services',
    shortAr: 'الخدمات',
    shortEn: 'Services',
    icon: Icons.content_cut_outlined,
    selectedIcon: Icons.content_cut_rounded,
  ),
  AdminNavSection(
    index: 3,
    ar: 'الفريق',
    en: 'Team',
    shortAr: 'الفريق',
    shortEn: 'Team',
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
  ),
  AdminNavSection(
    index: 4,
    ar: 'الخصومات',
    en: 'Discounts',
    shortAr: 'الخصومات',
    shortEn: 'Offers',
    icon: Icons.local_offer_outlined,
    selectedIcon: Icons.local_offer_rounded,
  ),
  AdminNavSection(
    index: 5,
    ar: 'آراء الزبائن',
    en: 'Feedback',
    shortAr: 'الآراء',
    shortEn: 'Reviews',
    icon: Icons.star_outline_rounded,
    selectedIcon: Icons.star_rounded,
  ),
  AdminNavSection(
    index: 6,
    ar: 'طلبات خارج الدوام',
    en: 'Out of hours',
    shortAr: 'خارج الدوام',
    shortEn: 'Off-hours',
    icon: Icons.schedule_send_outlined,
    selectedIcon: Icons.schedule_send_rounded,
  ),
  AdminNavSection(
    index: 7,
    ar: 'التقارير',
    en: 'Reports',
    shortAr: 'التقارير',
    shortEn: 'Reports',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
  ),
  AdminNavSection(
    index: 8,
    ar: 'إعدادات الحجز',
    en: 'Booking settings',
    shortAr: 'الإعدادات',
    shortEn: 'Settings',
    icon: Icons.tune_rounded,
    selectedIcon: Icons.tune_rounded,
  ),
  AdminNavSection(
    index: 9,
    ar: 'أدوات الأعمال',
    en: 'Business tools',
    shortAr: 'الأدوات',
    shortEn: 'Tools',
    icon: Icons.business_center_outlined,
    selectedIcon: Icons.business_center_rounded,
  ),
  AdminNavSection(
    index: 10,
    ar: 'الملف الشخصي',
    en: 'Profile',
    shortAr: 'حسابي',
    shortEn: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
  AdminNavSection(
    index: 11,
    ar: 'المالية والمحاسبة',
    en: 'Finance',
    shortAr: 'المالية',
    shortEn: 'Finance',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
  ),
  AdminNavSection(
    index: 12,
    ar: 'المخزون',
    en: 'Inventory',
    shortAr: 'المخزون',
    shortEn: 'Stock',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
  ),
];

/// ترتيب الأقسام الأكثر استخداماً في شريط التنقّل السفلي.
const List<int> _primaryOrder = [0, 1, 11, 12, 10, 9];

/// أقصى عدد وجهات أساسية قبل زر «المزيد».
const int kMaxPrimaryTabs = 4;

/// الأقسام الأساسية حسب الصلاحيات — تُستخدم في الشريط السفلي وRail.
List<int> primaryAdminTabs(AppRole role, {StaffPermissions? perms}) =>
    _primaryOrder
        .where((index) => adminTabVisible(role, index, perms: perms))
        .take(kMaxPrimaryTabs)
        .toList();

/// تحكّم مستقر في التنقّل حتى لا يُعاد بناء الشاشات المفتوحة عند كل تحديث.
class AdminNavigationController {
  AdminNavigationController(this._select);

  final void Function(int index) _select;

  void select(int index) => _select(index);
}

class AdminNavigationScope extends InheritedWidget {
  const AdminNavigationScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final AdminNavigationController controller;

  static AdminNavigationController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AdminNavigationScope>()
      ?.controller;

  @override
  bool updateShouldNotify(AdminNavigationScope oldWidget) =>
      controller != oldWidget.controller;
}

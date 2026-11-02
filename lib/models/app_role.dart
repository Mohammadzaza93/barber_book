/// أدوار المستخدمين داخل التطبيق — دوران فقط:
///
/// - [admin]   أدمن: كل الصلاحيات (خدمات، موظفون، تقارير، نفقات، مخزون،
///             إعدادات، إدارة الموظفين والنسخ الاحتياطي).
/// - [staff]   محاسب: صلاحيات محدودة يحددها الأدمن من شاشة الموظفين.
///
/// كلمة `staff` هنا اسم تقني للدور المحدود فقط؛ واجهة المستخدم تعرضه دائماً
/// باسم «محاسب». المعرّفات القديمة (owner/manager/barber/admin_staff) تُترجم
/// بأمان حتى لا تفقد الحسابات القائمة وصولها.
enum AppRole { admin, staff }

extension AppRoleX on AppRole {
  String get name => toString().split('.').last;

  static AppRole fromName(String? name) {
    switch (name) {
      case 'admin':
      case 'owner':
      case 'manager':
        return AppRole.admin;
      case 'accountant':
      case 'staff':
      case 'barber':
      case 'admin_staff':
        return AppRole.staff;
      default:
        return AppRole.staff;
    }
  }

  /// يحوّل معرّف دور الفريق (أدمن/محاسب أو أي معرّف قديم) إلى دور الحساب.
  static AppRole fromTeamRole(String? roleId) => fromName(roleId);

  /// هل يمكن لهذا الدور إدارة كل شيء؟
  bool get isAdmin => this == AppRole.admin;

  /// هل يمكن لهذا الدور تعديل الإعدادات والقواعد؟
  bool get canManageRules => this == AppRole.admin;

  /// هل يمكن لهذا الدور إدارة العمليات اليومية؟
  bool get canManageOperations => this == AppRole.admin;

  /// هل يمكن لهذا الدور عرض التقارير المالية؟
  bool get canViewReports => this == AppRole.admin;

  /// إدخال بيانات عادية
  bool get canEnterData => true;
}

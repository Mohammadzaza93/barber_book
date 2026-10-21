/// أدوار المستخدمين داخل التطبيق.
///
/// - [admin]   أدمن: كل الصلاحيات (خدمات، حلاقون، تقارير، نفقات، مخزون، إعدادات، إدارة الموظفين)
/// - [staff]   موظف إدخال: إدخال المواعيد والمدفوعات وتعديل ما أدخله فقط، بلا تقارير مالية ولا إعدادات
enum AppRole { admin, staff }

extension AppRoleX on AppRole {
  String get name => toString().split('.').last;

  static AppRole fromName(String? name) {
    switch (name) {
      case 'admin':
      case 'owner':
      case 'manager':
        return AppRole.admin;
      case 'staff':
        return AppRole.staff;
      default:
        return AppRole.staff;
    }
  }

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

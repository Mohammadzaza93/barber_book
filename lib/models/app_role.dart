/// أدوار المستخدمين داخل التطبيق.
///
/// - [owner]   المالك: كل الصلاحيات بما فيها تغيير الإعدادات والقواعد.
/// - [manager] مدير: إدارة العمليات اليومية (مواعيد، طلبات، مصروفات، تقارير)
///   دون القدرة على تعديل إعدادات المحل أو القواعد أو الأعضاء.
/// - [staff]   موظف (مستخدم عادي): إدخال بيانات عادية فقط
///   (إنشاء مواعيد/مصروفات/طلبات) ولا يملك أي صلاحية تغيير للقواعد.
enum AppRole { owner, manager, staff }

extension AppRoleX on AppRole {
  String get name => toString().split('.').last;

  static AppRole fromName(String? name) {
    switch (name) {
      case 'owner':
        return AppRole.owner;
      case 'manager':
        return AppRole.manager;
      case 'staff':
        return AppRole.staff;
      default:
        return AppRole.staff;
    }
  }

  /// هل يمكن لهذا الدور تعديل "القواعد"؟
  /// (إعدادات صفحة الحجز، الخدمات، الخصومات، الموظفين، أدوات الأعمال، الأعضاء)
  bool get canManageRules => this == AppRole.owner;

  /// هل يمكن لهذا الدور إدارة العمليات اليومية؟
  /// (تأكيد/إلغاء المواعيد، اعتماد طلبات التعطيل، حذف سجلات تشغيلية، عرض التقارير)
  bool get canManageOperations => this != AppRole.staff;

  /// هل يمكن لهذا الدور عرض لوحة البيانات والتقارير المالية؟
  bool get canViewReports => this != AppRole.staff;

  /// إدخال بيانات عادية متاح لجميع الأدوار.
  bool get canEnterData => true;
}

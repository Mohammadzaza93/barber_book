import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

/// رسالة خطأ واضحة + حل مقترح للمستخدم.
class AppError {
  final String message;
  final String suggestion;
  final String? code;
  final bool canRetry;

  const AppError({
    required this.message,
    required this.suggestion,
    this.code,
    this.canRetry = true,
  });

  @override
  String toString() => message;

  static AppError from(Object error) {
    if (error is AppError) return error;

    if (error is FirebaseAuthException) {
      return _auth(error.code, error.message);
    }
    if (error is FirebaseException) {
      return _firebase(error.code, error.message);
    }
    if (error is PlatformException) {
      return AppError(
        message: error.message ?? 'خطأ في النظام',
        suggestion: 'أعد تشغيل التطبيق. إن استمر المشكلة أعد تثبيت التطبيق.',
        code: error.code,
      );
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socket') ||
        raw.contains('network') ||
        raw.contains('failed host') ||
        raw.contains('connection')) {
      return AppError(
        message: 'لا يوجد اتصال بالإنترنت',
        suggestion:
            'تحقق من الواي فاي أو بيانات الجوال ثم أعد المحاولة. '
            'يمكنك متابعة العمل؛ ستُزامَن التغييرات عند عودة الشبكة.',
        code: 'network',
      );
    }
    if (raw.contains('permission-denied') || raw.contains('permission_denied')) {
      return AppError(
        message: 'ليس لديك صلاحية لهذا الإجراء',
        suggestion:
            'اطلب من مالك الصالون منحك الدور المناسب (مدير / موظف).',
        code: 'permission-denied',
        canRetry: false,
      );
    }

    return AppError(
      message: 'حدث خطأ غير متوقع',
      suggestion:
          'أعد المحاولة بعد ثوانٍ. إن تكرر الخطأ انسخ الرسالة وأرسلها للدعم.\n'
          'التفاصيل: ${_short(error.toString())}',
      code: 'unknown',
    );
  }

  static String _short(String s) =>
      s.length > 160 ? '${s.substring(0, 160)}…' : s;

  static AppError _auth(String code, String? msg) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return AppError(
          message: 'بيانات الدخول غير صحيحة',
          suggestion: 'تحقق من البريد وكلمة المرور، أو استخدم «نسيت كلمة المرور».',
          code: 'auth',
          canRetry: true,
        );
      case 'too-many-requests':
        return AppError(
          message: 'محاولات كثيرة',
          suggestion: 'انتظر دقيقة ثم حاول مرة أخرى.',
          code: code,
        );
      case 'network-request-failed':
        return AppError(
          message: 'تعذر الاتصال بالخادم',
          suggestion: 'تحقق من الإنترنت ثم أعد المحاولة.',
          code: code,
        );
      case 'email-already-in-use':
        return AppError(
          message: 'البريد مستخدم مسبقاً',
          suggestion: 'سجّل الدخول بدل إنشاء حساب جديد.',
          code: code,
          canRetry: false,
        );
      default:
        return AppError(
          message: msg ?? 'خطأ في المصادقة',
          suggestion: 'أعد تسجيل الدخول. إن استمرت المشكلة امسح بيانات التطبيق.',
          code: code,
        );
    }
  }

  static AppError _firebase(String code, String? msg) {
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppError(
          message: 'الخادم غير متاح حالياً',
          suggestion:
              'انتظر قليلاً وأعد المحاولة. التطبيق قد يعرض آخر بيانات محفوظة محلياً.',
          code: code,
        );
      case 'permission-denied':
        return AppError(
          message: 'صلاحيات غير كافية',
          suggestion:
              'تأكد أن حسابك عضو في هذا الصالون وأن قواعد Firestore منشورة.',
          code: code,
          canRetry: false,
        );
      case 'not-found':
        return AppError(
          message: 'البيانات غير موجودة',
          suggestion: 'حدّث الصفحة أو تحقق من رقم الصالون.',
          code: code,
        );
      case 'resource-exhausted':
        return AppError(
          message: 'تم تجاوز حد الاستخدام',
          suggestion:
              'قلّل التحديثات المتكررة أو راجع حصة Firebase في لوحة التحكم.',
          code: code,
        );
      case 'failed-precondition':
        return AppError(
          message: 'العملية غير جاهزة',
          suggestion:
              'قد تحتاج فهرساً في Firestore أو بيانات ناقصة. راجع Console إن تكرر.',
          code: code,
        );
      default:
        return AppError(
          message: msg ?? 'خطأ في قاعدة البيانات',
          suggestion: 'أعد المحاولة. إن استمر الخطأ انشر قواعد Firestore من جديد.',
          code: code,
        );
    }
  }
}

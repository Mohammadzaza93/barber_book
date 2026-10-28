import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// رفع صور من الجهاز إلى Firebase Storage.
class MediaUploadService {
  MediaUploadService._();
  static final instance = MediaUploadService._();

  Future<String> uploadPortfolioImage({
    required String shopId,
    required File file,
  }) async {
    if (shopId.isEmpty) {
      throw StateError(
          'معرّف الصالون غير جاهز. أعد تسجيل الدخول ثم حاول مجدداً.');
    }
    final id = const Uuid().v4();
    final ref = FirebaseStorage.instance
        .ref()
        .child('shops')
        .child(shopId)
        .child('portfolio')
        .child('$id.jpg');
    final meta = SettableMetadata(contentType: 'image/jpeg');
    try {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, meta);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found' ||
          e.code == 'bucket-not-found' ||
          (e.message ?? '').contains('Not Found')) {
        throw StateError(
          'Firebase Storage غير مفعّل أو الـ bucket غير موجود.\n'
          'افتح Firebase Console → Storage → Get started، ثم أعد المحاولة.',
        );
      }
      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        throw StateError(
          'رفض التخزين الكتابة. حدّث قواعد Storage للسماح للمستخدم المسجّل.',
        );
      }
      throw StateError('فشل رفع الصورة (${e.code}): ${e.message}');
    }
  }
}

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
    final id = const Uuid().v4();
    final ref = FirebaseStorage.instance
        .ref()
        .child('shops')
        .child(shopId)
        .child('portfolio')
        .child('$id.jpg');
    final meta = SettableMetadata(contentType: 'image/jpeg');
    await ref.putFile(file, meta);
    return ref.getDownloadURL();
  }
}

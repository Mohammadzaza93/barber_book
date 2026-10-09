import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/feedback.dart';
import '../services/firestore_service.dart';

class FeedbackProvider extends ChangeNotifier {
  List<Feedback> feedback = [];
  bool loading = true;

  /// First non-permission stream failure, surfaced instead of hanging.
  String? error;

  /// True when Firestore rejected the feedback read for this role. Moderation
  /// is manager-only, so a denial is an expected capability boundary rather
  /// than an exceptional error.
  bool permissionDenied = false;
  String? _boundShopId;
  final List<StreamSubscription> _subs = [];

  void bind(String shopId) {
    if (_boundShopId == shopId) return;
    _boundShopId = shopId;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    loading = true;
    error = null;
    permissionDenied = false;
    _subs.add(FirestoreService.instance.watchFeedback(shopId).listen(
      (list) {
        feedback = list;
        loading = false;
        notifyListeners();
      },
      // Feedback is manager-only; a denied read must clear `loading` and
      // surface an explicit access state instead of an empty list.
      onError: (Object e, StackTrace _) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          permissionDenied = true;
        } else {
          error ??= e.toString();
        }
        loading = false;
        notifyListeners();
      },
    ));
  }

  /// Re-subscribes to the bound shop after a transient error.
  void retry() {
    final shop = _boundShopId;
    if (shop == null) return;
    _boundShopId = null;
    bind(shop);
  }

  List<Feedback> get approved =>
      feedback.where((f) => f.showOnPage).toList();

  double get averageRating {
    if (approved.isEmpty) return 0;
    return approved.fold(0.0, (s, f) => s + f.rating) / approved.length;
  }

  Future<void> add(Feedback f, String shopId) =>
      FirestoreService.instance.addFeedback(shopId, f);

  Future<void> toggleShow(Feedback f, bool show, String shopId) =>
      FirestoreService.instance
          .updateFeedback(shopId, f.copyWith(showOnPage: show));

  Future<void> delete(String id, String shopId) =>
      FirestoreService.instance.deleteFeedback(shopId, id);

  /// Drops the bound shop and cached feedback. Used on sign-out.
  void reset() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _boundShopId = null;
    feedback = [];
    loading = true;
    error = null;
    permissionDenied = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

String newFeedbackId() => const Uuid().v4();

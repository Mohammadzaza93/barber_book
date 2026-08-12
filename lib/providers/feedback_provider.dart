import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/feedback.dart';
import '../services/firestore_service.dart';

class FeedbackProvider extends ChangeNotifier {
  List<Feedback> feedback = [];
  bool loading = true;
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
    _subs.add(FirestoreService.instance
        .watchFeedback(shopId)
        .listen((list) {
      feedback = list;
      loading = false;
      notifyListeners();
    }));
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

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

String newFeedbackId() => const Uuid().v4();

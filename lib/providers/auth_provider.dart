import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/owner.dart';
import '../models/app_role.dart';
import '../models/staff_permissions.dart';
import '../services/auth_service.dart';
import '../services/firebase_status.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/shop_manager.dart';

/// Resolves the shop and role for an authenticated uid. Overridable so session
/// transitions can be exercised deterministically without Firebase.
typedef ShopResolver = Future<({String? shopId, AppRole role})> Function(
    String uid);

/// Subscribes to / unsubscribes from a shop's FCM topic, given the explicit
/// tenant id. Returns `true` only when the operation completed (see
/// [NotificationService.subscribeToShop]).
typedef ShopTopicOp = Future<bool> Function(String shopId);

/// Creates the Firebase Auth user for a staff member on a secondary app.
typedef StaffAuthCreator = Future<String> Function(
    String email, String password);

/// Writes `shops/{shopId}/members/{uid}` (owner-only in the rules).
typedef MembershipWriter = Future<void> Function(
  String shopId,
  String uid, {
  required String email,
  required String name,
  required AppRole role,
  required StaffPermissions permissions,
});

/// Verifies that the current account is the immutable shop owner.
typedef ShopOwnerCheck = Future<bool> Function(String shopId);

/// Reads the owner-controlled capability map for a staff member.
typedef MemberPermissionsLoader = Future<StaffPermissions> Function(
    String shopId, String uid);

/// Thrown when the email already has a Firebase Auth account.
class StaffAccountAlreadyExists implements Exception {
  const StaffAccountAlreadyExists(this.email);
  final String email;

  @override
  String toString() => 'email-already-in-use:$email';
}

/// Thrown when the Auth account was created but the membership write failed.
class MembershipWriteException implements Exception {
  const MembershipWriteException(this.uid, this.cause);
  final String uid;
  final Object cause;

  @override
  String toString() => 'membership-write-failed:$uid';
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    ShopResolver? resolveShop,
    ShopTopicOp? subscribeShopNotifications,
    ShopTopicOp? unsubscribeShopNotifications,
    StaffAuthCreator? createStaffAuth,
    MembershipWriter? writeMembership,
    ShopOwnerCheck? isShopOwner,
    MemberPermissionsLoader? loadMemberPermissions,
    Duration topicRetryDelay = const Duration(seconds: 5),
    int maxTopicRetries = 3,
  })  : _resolveShop =
            resolveShop ?? FirestoreService.instance.resolveShopForUser,
        _subscribeShopNotifications = subscribeShopNotifications ??
            NotificationService.instance.subscribeToShop,
        _unsubscribeShopNotifications = unsubscribeShopNotifications ??
            NotificationService.instance.unsubscribeFromShop,
        _createStaffAuth =
            createStaffAuth ?? AuthService.instance.createStaffAccount,
        _writeMembership =
            writeMembership ?? FirestoreService.instance.saveMember,
        _isShopOwner = isShopOwner ?? FirestoreService.instance.isShopOwner,
        _loadMemberPermissions = loadMemberPermissions ??
            FirestoreService.instance.getMemberPermissions,
        _topicRetryDelay = topicRetryDelay,
        _maxTopicRetries = maxTopicRetries {
    if (!firebaseReady) {
      initializing = false;
      return;
    }
    _authSub = AuthService.instance.authStateChanges.listen(
      _onAuthChanged,
      onError: (Object e, StackTrace _) {
        error = e.toString();
        initializing = false;
        notifyListeners();
      },
    );
  }

  User? user;
  String? shopId;
  AppRole role = AppRole.staff;
  StaffPermissions _staffPermissions = StaffPermissions.minimal;
  StaffPermissions get permissions =>
      role.isAdmin ? StaffPermissions.all : _staffPermissions;
  bool initializing = true;
  String? error;

  final ShopResolver _resolveShop;
  final ShopTopicOp _subscribeShopNotifications;
  final ShopTopicOp _unsubscribeShopNotifications;
  final StaffAuthCreator _createStaffAuth;
  final MembershipWriter _writeMembership;
  final ShopOwnerCheck _isShopOwner;
  final MemberPermissionsLoader _loadMemberPermissions;
  final Duration _topicRetryDelay;
  final int _maxTopicRetries;

  StreamSubscription<User?>? _authSub;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _disposed = false;
  int _sessionGeneration = 0;
  String? _confirmedTopic;
  Future<void> _topicQueue = Future<void>.value();

  bool get isOwner => role == AppRole.admin;
  bool get isOwnerAccount => isOwnerEmail(user?.email);
  bool get canManageRules => role.canManageRules;
  bool get canManageOperations => role.canManageOperations;
  bool get canViewReports => role.canViewReports;

  @visibleForTesting
  String? get confirmedTopic => _confirmedTopic;
  @visibleForTesting
  Future<void> get pendingTopicWork => _topicQueue;

  Future<void> _onAuthChanged(User? u) async {
    user = u;
    await _applySession(u?.uid);
  }

  Future<void> _applySession(String? uid) async {
    final generation = ++_sessionGeneration;
    if (uid == null) {
      _clearSession();
      initializing = false;
      notifyListeners();
      return;
    }
    try {
      final resolved = await _resolveShop(uid);
      if (generation != _sessionGeneration) return;
      final resolvedShopId = resolved.shopId;
      shopId = resolvedShopId;
      role = resolved.role;
      ShopManager.shopId = resolvedShopId;
      _staffPermissions =
          role.isAdmin ? StaffPermissions.all : StaffPermissions.minimal;
      if (!role.isAdmin &&
          resolvedShopId != null &&
          resolvedShopId.isNotEmpty) {
        _refreshMemberPermissions(resolvedShopId, uid, generation);
      }
      _scheduleTopicReconcile(shopId, guarded: true, generation: generation);
    } catch (e) {
      if (generation != _sessionGeneration) return;
      error = e.toString();
      shopId = null;
      role = AppRole.staff;
      _staffPermissions = StaffPermissions.minimal;
      ShopManager.reset();
    }
    initializing = false;
    notifyListeners();
  }

  Future<void> refreshSession() async {
    final uid = user?.uid;
    if (uid == null) return;
    error = null;
    initializing = false;
    await _applySession(uid);
  }

  @visibleForTesting
  Future<void> applySessionForTest(String? uid) => _applySession(uid);

  void _refreshMemberPermissions(String shopId, String uid, int generation) {
    unawaited(
      _loadMemberPermissions(shopId, uid).then((perms) {
        if (_disposed || generation != _sessionGeneration) return;
        _staffPermissions = perms;
        notifyListeners();
      }).catchError((Object e) {
        debugPrint('AuthProvider: permission load failed: $e');
      }),
    );
  }

  void _clearSession() {
    shopId = null;
    role = AppRole.staff;
    _staffPermissions = StaffPermissions.minimal;
    ShopManager.reset();
    _scheduleTopicReconcile(null, guarded: false);
  }

  void _scheduleTopicReconcile(
    String? target, {
    required bool guarded,
    int? generation,
  }) {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _enqueueReconcile(target, guarded: guarded, generation: generation);
  }

  void _enqueueReconcile(
    String? target, {
    required bool guarded,
    int? generation,
  }) {
    _topicQueue = _topicQueue.then((_) async {
      if (guarded && generation != _sessionGeneration) return;
      final settled = await _reconcileTopic(target);
      if (!settled && guarded && generation == _sessionGeneration) {
        _scheduleRetry();
      }
    }).catchError((Object e) {
      debugPrint('AuthProvider: topic transition failed: $e');
    });
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_retryAttempt >= _maxTopicRetries) {
      debugPrint('AuthProvider: giving up topic reconcile after '
          '$_retryAttempt retries');
      return;
    }
    _retryAttempt++;
    final delay = _topicRetryDelay * _retryAttempt;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_disposed) return;
      _enqueueReconcile(shopId, guarded: true, generation: _sessionGeneration);
    });
  }

  Future<bool> _reconcileTopic(String? target) async {
    final previous = _confirmedTopic;
    if (previous != null && previous != target) {
      final removed = await _unsubscribeShopNotifications(previous);
      if (!removed) return false;
      if (_confirmedTopic == previous) _confirmedTopic = null;
    }
    if (target != null && _confirmedTopic != target) {
      final subscribed = await _subscribeShopNotifications(target);
      if (subscribed) {
        _confirmedTopic = target;
      } else {
        return false;
      }
    }
    return true;
  }

  void reconcileShopTopic() {
    _scheduleTopicReconcile(shopId,
        guarded: true, generation: _sessionGeneration);
  }

  Future<bool> signIn(String email, String password) async {
    error = null;
    try {
      await AuthService.instance.signIn(email, password);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String> createShop({
    required String shopName,
    required String phone,
    required String address,
    required String currency,
    String? primaryColorHex,
    String? accentColorHex,
  }) async {
    error = null;
    if (!isOwnerAccount) {
      error = 'owner-only';
      notifyListeners();
      throw StateError('owner-only');
    }
    try {
      final uid = user!.uid;
      final id = await FirestoreService.instance.createShop(
        ownerId: uid,
        shopName: shopName,
        phone: phone,
        address: address,
        currency: currency,
        primaryColorHex: primaryColorHex,
        accentColorHex: accentColorHex,
      );
      shopId = id;
      ShopManager.shopId = id;
      final resolved = await _resolveShop(uid);
      role = resolved.role;
      await _loadStaffPermissions(id, uid, user?.email);
      _scheduleTopicReconcile(id,
          guarded: true, generation: _sessionGeneration);
      notifyListeners();
      return id;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Creates accountant login (owner only). Forces [AppRole.staff].
  /// Sends password-reset email after membership write.
  Future<String> addStaffAccount({
    required String email,
    required String name,
    required AppRole role,
    required StaffPermissions permissions,
    required String password,
  }) async {
    error = null;
    final shop = shopId ?? ShopManager.shopId;
    if (shop == null || shop.isEmpty) {
      error = 'no-shop';
      notifyListeners();
      throw StateError('no-shop');
    }
    if (!await _isShopOwner(shop)) {
      error = 'not-shop-owner';
      notifyListeners();
      throw StateError('not-shop-owner');
    }
    final normalized = email.trim().toLowerCase();
    late final String uid;
    try {
      uid = await _createStaffAuth(normalized, password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        error = 'email-already-in-use';
        notifyListeners();
        throw StaffAccountAlreadyExists(normalized);
      }
      error = e.toString();
      notifyListeners();
      rethrow;
    }
    final safeRole = AppRole.staff;
    try {
      await _writeMembership(
        shop,
        uid,
        email: normalized,
        name: name,
        role: safeRole,
        permissions: permissions,
      );
    } catch (e) {
      error = 'membership-write-failed';
      notifyListeners();
      throw MembershipWriteException(uid, e);
    }
    try {
      await AuthService.instance.sendPasswordReset(normalized);
    } catch (_) {
      error = 'password-reset-failed';
      notifyListeners();
    }
    return uid;
  }

  /// Disabled: client-supplied UID is not proof of identity.
  Future<void> linkStaffAccount({
    required String uid,
    required String email,
    required String name,
    required AppRole role,
    required StaffPermissions permissions,
  }) async {
    error = 'manual-uid-link-disabled';
    notifyListeners();
    throw UnsupportedError(
      'manual-uid-link-disabled: provision via addStaffAccount only',
    );
  }

  Future<bool> joinShopByCode(String code) async {
    error = 'join-code-removed';
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    try {
      await AuthService.instance.signOut();
    } catch (e) {
      debugPrint('signOut: Firebase sign-out failed: $e');
    } finally {
      error = null;
      await _applySession(null);
    }
  }

  Future<void> _loadStaffPermissions(
      String shopId, String uid, String? email) async {
    if (role.isAdmin) {
      _staffPermissions = StaffPermissions.all;
      notifyListeners();
      return;
    }
    try {
      final db = FirebaseFirestore.instance;
      var snap = await db
          .collection('shops')
          .doc(shopId)
          .collection('employees')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isEmpty && email != null && email.isNotEmpty) {
        snap = await db
            .collection('shops')
            .doc(shopId)
            .collection('employees')
            .where('email', isEqualTo: email.toLowerCase())
            .limit(1)
            .get();
      }
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        _staffPermissions = StaffPermissions.fromMap(
            data['permissions'] as Map<String, dynamic>?);
      } else {
        _staffPermissions = StaffPermissions.minimal;
      }
    } catch (e) {
      _staffPermissions = StaffPermissions.minimal;
    }
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) =>
      AuthService.instance.sendPasswordReset(email);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }
}

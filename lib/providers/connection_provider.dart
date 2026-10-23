import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../services/connectivity_source.dart';
import '../services/firebase_status.dart';

/// Connection/synchronization state surfaced to the UI.
enum SyncStatus {
  /// No network interface is available; pending writes cannot be sent yet.
  offline,

  /// A connection is available and pending Firestore writes are being flushed.
  syncing,

  /// Connected with no known pending writes.
  online,

  /// A flush attempt failed (for example a rejected or blocked write). The
  /// local changes stay queued and Firestore will retry while connected.
  syncError,
}

/// Tracks connectivity and pending-write synchronization for the UI banner.
///
/// This never decides authorization or business outcomes — Firestore rules and
/// the Cloud Functions callables stay authoritative. It only observes whether
/// the device *has* a network interface and waits for queued direct writes to
/// drain so the UI can show an honest "offline" / "syncing" state.
class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider({
    ConnectivitySource? source,
    Future<void> Function()? flushPendingWrites,
    VoidCallback? onReconnected,
  })  : _source = source ?? ConnectivityPlusSource(),
        _flush = flushPendingWrites ?? _defaultFlush,
        _onReconnected = onReconnected;

  final ConnectivitySource _source;
  final Future<void> Function() _flush;

  /// Invoked once on each offline/sync-error -> online edge, after the flush is
  /// kicked off. Used to re-reconcile the session's FCM topic (a subscribe that
  /// timed out while offline). Kept a callback so this provider stays an
  /// indicator: it never learns about auth or tenant ownership itself.
  final VoidCallback? _onReconnected;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _disposed = false;

  SyncStatus _status = SyncStatus.online;
  // Guards against an older, slower flush resolving after a newer connection
  // event and overwriting the fresher state.
  int _flushToken = 0;

  SyncStatus get status => _status;
  bool get isOffline => _status == SyncStatus.offline;
  bool get isSyncing => _status == SyncStatus.syncing;

  /// Waits for queued writes to reach Firestore.
  ///
  /// Skipped when Firebase never initialized so the provider still works on the
  /// placeholder-config error screen.
  static Future<void> _defaultFlush() async {
    if (!firebaseReady) return;
    await FirebaseFirestore.instance.waitForPendingWrites();
  }

  /// Reads the initial state and starts listening for connectivity changes.
  Future<void> start() async {
    bool connected;
    try {
      connected = hasConnection(await _source.check());
    } catch (_) {
      // Connectivity could not be read; stay optimistic and let the change
      // stream correct the state instead of pinning a misleading offline banner.
      connected = true;
    }
    if (connected) {
      // Flush anything queued by a previous offline session before showing the
      // app as fully synced.
      _flushThenSettle();
    } else {
      _set(SyncStatus.offline);
    }
    _subscription = _source.changes.listen(
      (results) => _apply(hasConnection(results)),
      onError: (_) {},
    );
  }

  void _apply(bool connected) {
    if (_disposed) return;
    if (!connected) {
      _flushToken++; // Cancel any in-flight flush verdict.
      _set(SyncStatus.offline);
      return;
    }
    // Only re-run the flush when connectivity was previously lost, so ordinary
    // Wi-Fi/cellular interface changes do not re-trigger a sync each time.
    // Duplicate/rapid events while already online are ignored here, which also
    // prevents duplicate reconnect recoveries.
    if (_status == SyncStatus.offline || _status == SyncStatus.syncError) {
      _onReconnected?.call();
      _flushThenSettle();
    }
  }

  Future<void> _flushThenSettle() async {
    final token = ++_flushToken;
    _set(SyncStatus.syncing);
    try {
      await _flush();
      if (_disposed || token != _flushToken) return;
      _set(SyncStatus.online);
    } catch (_) {
      if (_disposed || token != _flushToken) return;
      _set(SyncStatus.syncError);
    }
  }

  void _set(SyncStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _flushToken++;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}

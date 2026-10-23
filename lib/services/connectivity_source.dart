import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports the device's network *interface* state.
///
/// The results are an indicator of network presence only: a device can report
/// Wi-Fi while the access point has no internet, and [ConnectivityResult.none]
/// describes the radio state rather than proof that a server is unreachable.
/// The connection provider therefore treats this as a hint to try flushing
/// pending Firestore writes, never as proof that a request will succeed.
abstract class ConnectivitySource {
  Future<List<ConnectivityResult>> check();

  Stream<List<ConnectivityResult>> get changes;
}

/// Production [ConnectivitySource] backed by the `connectivity_plus` plugin.
class ConnectivityPlusSource implements ConnectivitySource {
  ConnectivityPlusSource([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> check() => _connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}

/// True when the reported interfaces include anything other than
/// [ConnectivityResult.none].
bool hasConnection(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);

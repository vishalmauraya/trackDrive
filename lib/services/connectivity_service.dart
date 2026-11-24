import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps [Connectivity] to provide a simple `isOnline` boolean stream.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// True when at least one connectivity type (wifi / mobile / ethernet) is
  /// available.  False for [ConnectivityResult.none].
  Stream<bool> get onlineStatusStream => _connectivity.onConnectivityChanged
      .map((results) => results.any(_isOnline));

  /// One-shot check used on startup.
  Future<bool> isCurrentlyOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any(_isOnline);
  }

  static bool _isOnline(ConnectivityResult r) =>
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet;
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService instance = ConnectivityService._internal();
  ConnectivityService._internal();

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // Callback invoked when connectivity is restored — set by SyncService
  VoidCallback? onConnectivityRestored;

  Future<void> init() async {
    // Check current state
    final results = await Connectivity().checkConnectivity();
    _isOnline = _hasConnection(results);

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _hasConnection(results);
      notifyListeners();
      // Trigger sync when we just came online
      if (!wasOnline && _isOnline) {
        debugPrint('[ConnectivityService] Network restored — triggering sync.');
        onConnectivityRestored?.call();
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

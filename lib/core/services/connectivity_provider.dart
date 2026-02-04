import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.isNotEmpty &&
        !results.contains(ConnectivityResult.none);

    _isOnline = hasConnection;
    notifyListeners();
  }

  Future<void> checkNow() async {
  final results = await Connectivity().checkConnectivity();
  _updateStatus(results);
}

}

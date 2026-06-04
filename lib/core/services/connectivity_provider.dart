import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _offlineDebounce;

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
    final hasConnection =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (hasConnection) {
      _offlineDebounce?.cancel();
      _offlineDebounce = null;
      if (!_isOnline) {
        _isOnline = true;
        notifyListeners();
      }
      return;
    }

    // Evita pantalla «sin conexión» al despertar el teléfono (Wi‑Fi/datós tardan ms).
    _offlineDebounce?.cancel();
    _offlineDebounce = Timer(const Duration(seconds: 2), () {
      if (_isOnline) {
        _isOnline = false;
        notifyListeners();
      }
    });
  }

  Future<void> checkNow() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  @override
  void dispose() {
    _offlineDebounce?.cancel();
    super.dispose();
  }
}

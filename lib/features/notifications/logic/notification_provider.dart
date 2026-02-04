import 'package:intellitaxi/features/notifications/services/notification_service.dart';
import 'package:intellitaxi/features/notifications/data/notification_model.dart';
import 'package:flutter/material.dart';


class NotificationProvider extends ChangeNotifier {
  final _api = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();
    _notifications = await _api.fetchNotifications();
    _isLoading = false;
    notifyListeners();
  }
}

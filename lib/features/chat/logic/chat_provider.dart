import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/features/auth/data/auth_model.dart';
import 'package:intellitaxi/features/chat/data/message_model.dart' hide Persona;
import 'package:flutter/foundation.dart';
import 'package:intellitaxi/features/chat/data/activacion_chat_model.dart'
    hide User, Persona;
import 'package:intellitaxi/features/chat/services/chat_service.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';


class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  PusherChannelsFlutter? _pusher;

  // 🔹 Flag para saber si llegó un nuevo mensaje
  bool _newMessageArrived = false;
  bool get newMessageArrived => _newMessageArrived;

  void resetNewMessageFlag() {
    _newMessageArrived = false;
  }

  List<ActivationCompanyUser> _users = [];
  List<ActivationCompanyUser> _filteredUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<ActivationCompanyUser> get users => _filteredUsers;
  List<ActivationCompanyUser> get allUsers => _users;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  List<MessageModel> _messages = [];
  bool _loadingMessages = false;

  List<MessageModel> get messages => _messages;
  bool get loadingMessages => _loadingMessages;
  AuthResponse? _authData;
  AuthResponse? get authData => _authData;

  User? get user => _authData?.user;

  Persona? get persona => user?.persona;

  // List<Contract> get contratos => user?.persona.contrato ?? [];

  Future<void> loadUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final users = await _chatService.fetchActivationCompanyUsers();
      _users = users;
      _filteredUsers = users;

      if (kDebugMode) {
        for (var user in users) {
          final roles = user.roles.map((r) => r.name).join(", ");
          final nombreCompleto =
              '${user.user.persona.nombre1} ${user.user.persona.apellido1}';
          print("$nombreCompleto - Roles: $roles");
        }
      }
    } catch (e) {
      print("Error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchUsers(String query) {
    _searchQuery = query;

    if (query.isEmpty) {
      _filteredUsers = _users;
    } else {
      _filteredUsers = _users.where((user) {
        final nombreCompleto =
            '${user.user.persona.nombre1} ${user.user.persona.apellido1} ${user.user.persona.nombre2} ${user.user.persona.apellido2}'
                .toLowerCase();
        final email = user.user.email.toLowerCase();
        final roles = user.roles.map((r) => r.name).join(' ').toLowerCase();

        return nombreCompleto.contains(query.toLowerCase()) ||
            email.contains(query.toLowerCase()) ||
            roles.contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredUsers = _users;
    notifyListeners();
  }

  List<ActivationCompanyUser> getUsersByRole(String roleName) {
    return _users
        .where(
          (user) => user.roles.any(
            (role) => role.name.toLowerCase() == roleName.toLowerCase(),
          ),
        )
        .toList();
  }

  Future<void> loadMessages(int userId, selectedUser, idActivation) async {
    print(idActivation);
    print(selectedUser);

    _loadingMessages = true;
    notifyListeners();

    try {
      _messages = await _chatService.fetchMessages(userId);

      await _initPusher(idActivation, selectedUser);
    } catch (e) {
      _messages = [];
    }

    _loadingMessages = false;
    notifyListeners();
  }

  Future<void> _initPusher(int currentUserId, int otherUserId) async {
    if (_pusher != null) return;

    _pusher = PusherChannelsFlutter.getInstance();

    await _pusher!.init(
      apiKey: "ffb1bc6e573141dd3f35",
      cluster: "us2",
      authEndpoint: "${AppConfig.baseUrl}auth/pusher",
      onConnectionStateChange: (state, prev) {
        debugPrint("Pusher state: $state");
      },
      onEvent: (event) {
        debugPrint("📩 Nuevo evento: ${event.data}");

        final decoded = jsonDecode(event.data);
        final newMessage = MessageModel.fromJson(decoded);

        _messages.add(newMessage);

        _newMessageArrived = true;

        notifyListeners();
      },
      onAuthorizer: (channelName, socketId, options) async {
        final authResponse = await _chatService.authorizePusher(
          channelName,
          socketId,
        );
        return authResponse;
      },
    );

    await _pusher!.connect();

    final users = [currentUserId, otherUserId]..sort();
    final channelName = "private-chat.${users[0]}.${users[1]}";

    print("🔔 Subscribing to channel: $channelName");
    await _pusher!.subscribe(channelName: channelName);

    debugPrint("✅ Subscribed to channel: $channelName");
  }

  void disconnectPusher() {
    _pusher?.disconnect();
    _pusher = null;
  }

  Future<void> sendMessage(
    int idUser,
    int currentUserId,
    String body, {
    String origen = "WEB",
    List<File>? archivos,
    Persona? persona,
  }) async {
    try {
      final formData = FormData.fromMap({
        "idUser": idUser,
        "body": body,
        "origen": origen,
        if (archivos != null && archivos.isNotEmpty)
          "archivos[]": archivos.map((f) {
            return MultipartFile.fromFileSync(
              f.path,
              filename: f.path.split("/").last,
            );
          }).toList(),
      });

      final response = await _chatService.sendMessage(formData);

      final Map<String, dynamic> messageData = Map<String, dynamic>.from(
        response,
      );

      if (persona != null) {
        messageData['persona'] = persona.toJson();
      }

      messageData['side'] = 'right';

      final newMessage = MessageModel.fromJson(messageData);
      _messages.add(newMessage);

      _newMessageArrived = true;
      notifyListeners();

      final users = [currentUserId, idUser]..sort();
      final channelName = "private-chat.${users[0]}.${users[1]}";

      debugPrint("📤 Trigger en: $channelName");

      await _pusher?.trigger(
        PusherEvent(
          channelName: channelName,
          eventName: "client-mensaje-nuevo",
          data: jsonEncode({...messageData, "side": "left"}),
        ),
      );
    } catch (e) {
      debugPrint("⚠️ Error en ChatProvider: $e");
    }
  }
}
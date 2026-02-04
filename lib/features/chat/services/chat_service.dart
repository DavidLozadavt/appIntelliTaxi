import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/chat/data/activacion_chat_model.dart';
import 'package:intellitaxi/features/chat/data/message_model.dart';
import 'package:flutter/material.dart';

class ChatService {
  final Dio _dio = DioClient.getInstance();

  Future<List<ActivationCompanyUser>> fetchActivationCompanyUsers() async {
    try {
      final response = await _dio.get('get_users_and_groups');
      
      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final List users = data['activationCompanyUsers'];
        return users.map((e) => ActivationCompanyUser.fromJson(e)).toList();
      } else {
        throw Exception('Error al cargar los usuarios: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de conexión: ${e.message}');
    }
  }

   Future<List<MessageModel>> fetchMessages(int userId) async {
    try {
      final response = await _dio.get('get_comments_user_to_user/$userId');

      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final List list = data;
        return list.map((e) => MessageModel.fromJson(e)).toList();
      } else {
        throw Exception('Error al cargar los mensajes: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de conexión: ${e.message}');
    }
  }

  Future<dynamic> authorizePusher(String channelName, String socketId) async {
  final response = await _dio.post(
    
    "auth/pusher",
    data: {
      "channel_name": channelName,
      "socket_id": socketId,
    },
    options: Options(
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
    ),
    
  );
  
  
  print("Pusher auth response: ${response.data}");


  return response.data is String ? jsonDecode(response.data) : response.data;
}

 Future<Map<String, dynamic>> sendMessage(FormData data) async {
  try {
    final idUserField = data.fields.firstWhere((f) => f.key == 'idUser');
    final idUser = idUserField.value;

    final response = await _dio.post(
      "send_message_between_two_users/$idUser/comments",
      data: data,
      options: Options(
        headers: {
          "Content-Type": "multipart/form-data",
        },
      ),
    );

    return response.data as Map<String, dynamic>;
  } catch (e) {
    debugPrint("❌ Error en ChatService: $e");
    rethrow;
  }
}


}



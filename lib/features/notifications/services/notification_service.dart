import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';

import '../data/notification_model.dart';

class NotificationService {

  final Dio _dio = DioClient.getInstance();

  Future<List<NotificationModel>> fetchNotifications() async {
    try {
      final response = await _dio.get("notificaciones");

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => NotificationModel.fromJson(json)).toList();
      } else {
        throw Exception("Error al obtener notificaciones: ${response.statusCode}");
      }
    } on DioException catch (e) {
      throw Exception("Error en la petición: ${e.message}");
    }
  }

 
}

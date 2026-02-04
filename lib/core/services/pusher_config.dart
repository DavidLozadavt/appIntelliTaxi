// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/dio_client.dart';

import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class PusherConfig {
  late PusherChannelsFlutter _pusher;

  String APP_ID = "1859027";
  String API_KEY = "ffb1bc6e573141dd3f35";
  String SECRET = "e40628078fb3825a489f";
  String API_CLUSTER = "us2";

  Future<void> initPusher(onEvent, {channelName = "admin-vt"}) async {
    _pusher = PusherChannelsFlutter.getInstance();

    try {
      await _pusher.init(
        apiKey: API_KEY,
        cluster: API_CLUSTER,
        onConnectionStateChange: onConnectionStateChange,
        onError: onError,
        onSubscriptionSucceeded: onSubscriptionSucceeded,
        onEvent: onEvent,
        onSubscriptionError: onSubscriptionError,
        onDecryptionFailure: onDecryptionFailure,
        onMemberAdded: onMemberAdded,
        onMemberRemoved: onMemberRemoved,
        onAuthorizer: onAuthorizer,
        authEndpoint: "${AppConfig.baseUrl}auth/pusher",
      );

      await _pusher.connect();
      await _pusher.subscribe(channelName: channelName);

      log("trying to subscribe to : $channelName");
    } catch (e) {
      log("error in initialization: $e");
    }
  }

 Future<dynamic> onAuthorizer(
    String channelName, String socketId, dynamic options) async {
  log("Authorizing channel: $channelName with socketId: $socketId");

  try {
    final dio = DioClient.getInstance(); 

    final response = await dio.post(
      "auth/pusher",
      data: FormData.fromMap({
        "channel_name": channelName,
        "socket_id": socketId,
      }),
      options: Options(
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
      ),
    );

    log("Pusher auth response: ${response.data}");

    if (response.data is String) {
      return jsonDecode(response.data);
    }
    return response.data;
  } catch (e) {
    log("Error in onAuthorizer: $e");
    return {};
  }
}


  void disconnect() {
    _pusher.disconnect();
  }

  void onConnectionStateChange(dynamic currentState, dynamic previousState) {
    log("Connection: $currentState");
  }

  void onError(String message, int? code, dynamic e) {
    log("onError: $message code: $code exception: $e");
  }

  void onEvent(PusherEvent event) {
    log("onEvent: $event");
  }

  void onSubscriptionSucceeded(String channelName, dynamic data) {
    log("onSubscriptionSucceeded: $channelName data: $data");
    final me = _pusher.getChannel(channelName)?.me;
    log("Me: $me");
  }

  void onSubscriptionError(String message, dynamic e) {
    log("onSubscriptionError: $message Exception: $e");
  }

  void onDecryptionFailure(String event, String reason) {
    log("onDecryptionFailure: $event reason: $reason");
  }

  void onMemberAdded(String channelName, PusherMember member) {
    log("onMemberAdded: $channelName user: $member");
  }

  void onMemberRemoved(String channelName, PusherMember member) {
    log("onMemberRemoved: $channelName user: $member");
  }

  void onSubscriptionCount(String channelName, int subscriptionCount) {
    log("onSubscriptionCount: $channelName subscriptionCount: $subscriptionCount");
  }
}

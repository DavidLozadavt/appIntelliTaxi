import 'dart:convert';

import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';

/// Pusher: confirmación de solicitud y contraofertas globales.
class PasajeroPusherOffersController {
  static const _solicitudesChannel = 'solicitudes-servicio';
  static const _ofertasChannel = 'ofertas-globales';

  Future<void> subscribeRequestConfirmation({
    required void Function(Map<String, dynamic> data) onNuevaSolicitud,
  }) async {
    await PusherService.subscribeSecondary(_solicitudesChannel);
    for (final eventName in const ['nueva-solicitud', 'nueva_solicitud']) {
      PusherService.registerEventHandlerSecondary(
        '$_solicitudesChannel:$eventName',
        (data) {
          final parsed = _parseEvent(data);
          if (parsed != null) onNuevaSolicitud(parsed);
        },
      );
    }
  }

  Future<void> subscribeGlobalOffers({
    required void Function(Map<String, dynamic> offer) onNewOffer,
  }) async {
    await PusherService.subscribeSecondary(_ofertasChannel);
    PusherService.registerEventHandlerSecondary(
      '$_ofertasChannel:nueva-oferta',
      (data) {
        final parsed = _parseEvent(data);
        if (parsed != null) onNewOffer(parsed);
      },
    );
  }

  void unsubscribeAll({bool includeGlobalOffers = false}) {
    for (final eventName in const ['nueva-solicitud', 'nueva_solicitud']) {
      PusherService.unregisterEventHandlerSecondary(
        '$_solicitudesChannel:$eventName',
      );
    }
    PusherService.unsubscribeSecondary(_solicitudesChannel);

    if (includeGlobalOffers) {
      PusherService.unregisterEventHandlerSecondary(
        '$_ofertasChannel:nueva-oferta',
      );
      PusherService.unsubscribeSecondary(_ofertasChannel);
    }
  }

  static Map<String, dynamic>? _parseEvent(dynamic data) {
    try {
      if (data is String) {
        return Map<String, dynamic>.from(
          jsonDecode(data) as Map,
        );
      }
      if (data is Map) {
        return JsonPayloadHelper.parseAndMerge(data);
      }
    } catch (e) {
      AppLogger.e('Error parseando evento Pusher pasajero', tag: 'PusherOffers', error: e);
    }
    return null;
  }
}

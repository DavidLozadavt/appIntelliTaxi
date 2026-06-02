import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/map/intellitaxi_maps.dart';
import 'package:http/http.dart' as http;
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/features/pasajero/services/places_service.dart';
import 'package:intellitaxi/features/pasajero/services/ride_request_service.dart';
import 'package:intellitaxi/features/pasajero/services/routes_service.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';

enum AssistantStep {
  requestKind,
  dateTime,
  origin,
  /// Solo cuando el servicio es domicilio: detalle opcional del encargo.
  domicilioDescripcion,
  destinationPrompt,
  destinationEntry,
  summary,
}

class ChatLine {
  final String id;
  final bool isUser;
  final String text;

  ChatLine({required this.isUser, required this.text}) : id = const Uuid().v4();
}

class TravelAssistantController extends ChangeNotifier {
  TravelAssistantController({
    required this.passengerFirstName,
    required this.passengerUserId,
    this.passengerFullName,
    this.passengerPhone,
    PlacesService? placesService,
    RideRequestService? rideRequestService,
    RoutesService? routesService,
  })  : _places = placesService ?? PlacesService(),
        _rides = rideRequestService ?? RideRequestService(),
        _routes = routesService ?? RoutesService();

  final String passengerFirstName;
  /// ID de usuario (pasajero) para `taxi/solicitud-telefonica` (programados).
  final int passengerUserId;
  final String? passengerFullName;
  final String? passengerPhone;
  final PlacesService _places;
  final RideRequestService _rides;
  final RoutesService _routes;

  final List<ChatLine> messages = [];

  AssistantStep step = AssistantStep.requestKind;

  /// `taxi` o `domicilio` para el endpoint `taxi/solicitud`.
  String apiServiceType = 'taxi';
  bool isScheduled = false;
  /// Entrada directa "Domicilio" desde el inicio (sin paso taxi/domicilio intermedio).
  bool domicilioInmediato = false;
  DateTime? scheduledDateTime;

  TripLocation? origin;
  TripLocation? destination;
  bool skipDestination = false;

  final TextEditingController originSearchController = TextEditingController();
  final TextEditingController destinationSearchController =
      TextEditingController();
  final TextEditingController domicilioDescripcionController =
      TextEditingController();

  /// Texto guardado al salir del paso de descripción (para resumen y envío).
  String domicilioDescripcionTexto = '';

  /// Taxi inmediato con tipo domicilio, o flujo «Domicilio (ahora)».
  bool get esDomicilioServicio =>
      apiServiceType == 'domicilio' || domicilioInmediato;

  List<PlacePrediction> originPredictions = [];
  List<PlacePrediction> destinationPredictions = [];
  bool isSearchingOrigin = false;
  bool isSearchingDestination = false;
  bool isLoadingLocation = false;
  /// Resolviendo dirección escrita vía Places Text Search
  bool isConfirmingAddressSearch = false;
  bool isSubmitting = false;
  String? lastError;

  Timer? _originDebounce;
  Timer? _destDebounce;
  int _originReq = 0;
  int _destReq = 0;

  static const _popayanNotice =
      'Búsqueda limitada al perímetro urbano de Popayán.';

  void init() {
    messages.clear();
    messages.add(
      ChatLine(
        isUser: false,
        text:
            '¡Hola, $passengerFirstName! 👋 ¿Cómo deseas solicitar tu servicio?',
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _originDebounce?.cancel();
    _destDebounce?.cancel();
    originSearchController.dispose();
    destinationSearchController.dispose();
    domicilioDescripcionController.dispose();
    super.dispose();
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }

  void clearOriginSearchUi() {
    originSearchController.clear();
    originPredictions = [];
    notifyListeners();
  }

  void clearDestinationSearchUi() {
    destinationSearchController.clear();
    destinationPredictions = [];
    notifyListeners();
  }

  void onOriginQueryChanged() {
    final q = originSearchController.text.trim();
    _originDebounce?.cancel();
    if (q.length < 2) {
      originPredictions = [];
      isSearchingOrigin = false;
      notifyListeners();
      return;
    }
    isSearchingOrigin = true;
    notifyListeners();
    final id = ++_originReq;
    _originDebounce = Timer(const Duration(milliseconds: 350), () async {
      final preds = await _places.getAutocompletePredictions(q);
      if (id != _originReq) return;
      originPredictions = preds;
      isSearchingOrigin = false;
      notifyListeners();
    });
  }

  void onDestinationQueryChanged() {
    final q = destinationSearchController.text.trim();
    _destDebounce?.cancel();
    if (q.length < 2) {
      destinationPredictions = [];
      isSearchingDestination = false;
      notifyListeners();
      return;
    }
    isSearchingDestination = true;
    notifyListeners();
    final id = ++_destReq;
    _destDebounce = Timer(const Duration(milliseconds: 350), () async {
      final preds = await _places.getAutocompletePredictions(q);
      if (id != _destReq) return;
      destinationPredictions = preds;
      isSearchingDestination = false;
      notifyListeners();
    });
  }

  /// Usuario escribió origen y confirma sin tocar sugerencia: resuelve con búsqueda de texto (Popayán).
  Future<void> confirmOriginFromSearchText() async {
    final q = originSearchController.text.trim();
    if (q.length < 3) {
      lastError = 'Escribe al menos 3 caracteres o elige una sugerencia de la lista.';
      notifyListeners();
      return;
    }
    lastError = null;
    isConfirmingAddressSearch = true;
    notifyListeners();
    try {
      final results = await _places.searchPlaces(q);
      if (results.isEmpty) {
        lastError =
            'No encontramos esa dirección en el urbano de Popayán. Revisa el texto o elige una sugerencia.';
        return;
      }
      final r = results.first;
      origin = TripLocation.fromPlaceDetails(
        placeId: r.placeId,
        name: r.name.isNotEmpty ? r.name : q,
        address: r.address.isNotEmpty ? r.address : q,
        lat: r.lat,
        lng: r.lng,
      );
      originSearchController.removeListener(onOriginQueryChanged);
      originSearchController.text = origin!.name;
      originSearchController.addListener(onOriginQueryChanged);
      originPredictions = [];
      isSearchingOrigin = false;
      messages.add(ChatLine(isUser: true, text: 'Origen: ${origin!.address}'));
      _afterOriginRegistered();
    } finally {
      isConfirmingAddressSearch = false;
      notifyListeners();
    }
  }

  Future<void> pickOriginFromPrediction(PlacePrediction p) async {
    final details = await _places.resolvePrediction(p);
    if (details == null) {
      lastError =
          'Esa dirección está fuera del perímetro urbano de Popayán.';
      notifyListeners();
      return;
    }
    originSearchController.removeListener(onOriginQueryChanged);
    originSearchController.text = p.mainText;
    originSearchController.addListener(onOriginQueryChanged);
    origin = TripLocation.fromPlaceDetails(
      placeId: p.placeId,
      name: details.name,
      address: details.address,
      lat: details.lat,
      lng: details.lng,
    );
    originPredictions = [];
    isSearchingOrigin = false;
    messages.add(ChatLine(isUser: true, text: 'Origen: ${origin!.name}'));
    _afterOriginRegistered();
    notifyListeners();
  }

  void _afterOriginRegistered() {
    if (esDomicilioServicio) {
      domicilioDescripcionController.clear();
      domicilioDescripcionTexto = '';
      messages.add(
        ChatLine(
          isUser: false,
          text:
              'Describe brevemente el encargo (opcional): qué recoger, entregar o comprar.',
        ),
      );
      step = AssistantStep.domicilioDescripcion;
    } else {
      messages.add(
        ChatLine(
          isUser: false,
          text: 'Origen registrado. ¿Deseas agregar un destino?',
        ),
      );
      step = AssistantStep.destinationPrompt;
    }
  }

  void continueDomicilioDescripcion() {
    domicilioDescripcionTexto = domicilioDescripcionController.text.trim();
    if (domicilioDescripcionTexto.isNotEmpty) {
      messages.add(
        ChatLine(isUser: true, text: 'Detalle: $domicilioDescripcionTexto'),
      );
    }
    messages.add(
      ChatLine(
        isUser: false,
        text: 'Origen registrado. ¿Deseas agregar un destino?',
      ),
    );
    step = AssistantStep.destinationPrompt;
    notifyListeners();
  }

  Future<void> confirmDestinationFromSearchText() async {
    final q = destinationSearchController.text.trim();
    if (q.length < 3) {
      lastError = 'Escribe al menos 3 caracteres o elige una sugerencia de la lista.';
      notifyListeners();
      return;
    }
    lastError = null;
    isConfirmingAddressSearch = true;
    notifyListeners();
    try {
      final results = await _places.searchPlaces(q);
      if (results.isEmpty) {
        lastError =
            'No encontramos ese destino en el urbano de Popayán. Revisa el texto o elige una sugerencia.';
        return;
      }
      final r = results.first;
      destination = TripLocation.fromPlaceDetails(
        placeId: r.placeId,
        name: r.name.isNotEmpty ? r.name : q,
        address: r.address.isNotEmpty ? r.address : q,
        lat: r.lat,
        lng: r.lng,
      );
      skipDestination = false;
      destinationSearchController.removeListener(onDestinationQueryChanged);
      destinationSearchController.text = destination!.name;
      destinationSearchController.addListener(onDestinationQueryChanged);
      destinationPredictions = [];
      isSearchingDestination = false;
      messages.add(
        ChatLine(isUser: true, text: 'Destino: ${destination!.address}'),
      );
      _appendSummaryPrompt();
      step = AssistantStep.summary;
    } finally {
      isConfirmingAddressSearch = false;
      notifyListeners();
    }
  }

  Future<void> pickDestinationFromPrediction(PlacePrediction p) async {
    final details = await _places.resolvePrediction(p);
    if (details == null) {
      lastError =
          'Esa dirección está fuera del perímetro urbano de Popayán.';
      notifyListeners();
      return;
    }
    destinationSearchController.removeListener(onDestinationQueryChanged);
    destinationSearchController.text = p.mainText;
    destinationSearchController.addListener(onDestinationQueryChanged);
    destination = TripLocation.fromPlaceDetails(
      placeId: p.placeId,
      name: details.name,
      address: details.address,
      lat: details.lat,
      lng: details.lng,
    );
    skipDestination = false;
    destinationPredictions = [];
    isSearchingDestination = false;
    destinationSearchController.removeListener(onDestinationQueryChanged);
    messages.add(ChatLine(isUser: true, text: 'Destino: ${destination!.name}'));
    _appendSummaryPrompt();
    step = AssistantStep.summary;
    notifyListeners();
  }

  void selectRequestKind({required bool immediate}) {
    lastError = null;
    domicilioInmediato = false;
    apiServiceType = 'taxi';
    scheduledDateTime = null;
    if (immediate) {
      isScheduled = false;
      messages.add(ChatLine(isUser: true, text: 'Servicio inmediato'));
      messages.add(
        ChatLine(
          isUser: false,
          text:
              'Indica el punto de recogida: puedes usar tu ubicación o buscar una dirección.',
        ),
      );
      step = AssistantStep.origin;
      _wireOriginSearch();
    } else {
      isScheduled = true;
      messages.add(ChatLine(isUser: true, text: 'Servicio programado'));
      messages.add(
        ChatLine(
          isUser: false,
          text:
              'Elige la fecha y la hora en que necesitas el taxi (debe ser un momento futuro).',
        ),
      );
      step = AssistantStep.dateTime;
    }
    notifyListeners();
  }

  /// Tercera opción de inicio: envío a domicilio inmediato (sin elegir taxi vs domicilio otra vez).
  void selectDomicilioInmediato() {
    lastError = null;
    domicilioInmediato = true;
    isScheduled = false;
    scheduledDateTime = null;
    apiServiceType = 'domicilio';
    messages.add(
      ChatLine(isUser: true, text: 'Domicilio (ahora)'),
    );
    messages.add(
      ChatLine(
        isUser: false,
        text:
            'Indica desde dónde se recoge el envío: tu ubicación actual o una dirección concreta.',
      ),
    );
    step = AssistantStep.origin;
    _wireOriginSearch();
    notifyListeners();
  }

  Future<void> applyPickedDateTime(DateTime when) async {
    final l = when.toLocal();
    scheduledDateTime = DateTime(l.year, l.month, l.day, l.hour, l.minute);
    final formatted = DateFormat(
      "EEEE d MMM • hh:mm a",
      'es',
    ).format(scheduledDateTime!);
    messages.add(ChatLine(isUser: true, text: formatted));
    messages.add(
      ChatLine(
        isUser: false,
        text:
            '¿Desde dónde partes? Puedes usar tu ubicación o buscar una dirección.',
      ),
    );
    step = AssistantStep.origin;
    _wireOriginSearch();
    notifyListeners();
  }

  void _wireOriginSearch() {
    originSearchController.removeListener(onOriginQueryChanged);
    originSearchController.addListener(onOriginQueryChanged);
  }

  Future<bool> useCurrentLocationAsOrigin() async {
    lastError = null;
    isLoadingLocation = true;
    notifyListeners();
    try {
      final ok = await _ensureLocationPermission();
      if (!ok) {
        lastError = 'Activa el permiso de ubicación para usar este punto.';
        isLoadingLocation = false;
        notifyListeners();
        return false;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final addr = await _reverseGeocode(pos.latitude, pos.longitude);
      origin = TripLocation.currentLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        name: addr.$1,
        address: addr.$2,
      );
      originSearchController.removeListener(onOriginQueryChanged);
      originSearchController.text = origin!.name;
      originSearchController.addListener(onOriginQueryChanged);
      messages.add(ChatLine(isUser: true, text: 'Origen: ${origin!.address}'));
      _afterOriginRegistered();
      isLoadingLocation = false;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = 'No se pudo obtener la ubicación. Intenta de nuevo.';
      isLoadingLocation = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }
    return status.isGranted;
  }

  Future<(String, String)> _reverseGeocode(double lat, double lng) async {
    final fallback =
        ('Mi ubicación', 'Lat ${lat.toStringAsFixed(5)}, Lng ${lng.toStringAsFixed(5)}');
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'latlng=$lat,$lng&key=${AppConfig.googleMapsApiKey}&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return fallback;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK' || (data['results'] as List).isEmpty) {
        return fallback;
      }
      final results = data['results'] as List<dynamic>;
      final first = results.first as Map<String, dynamic>;
      final formatted =
          first['formatted_address']?.toString().trim() ?? fallback.$2;
      String? bestName;
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final value = item['formatted_address']?.toString().trim();
        if (value == null || value.isEmpty) continue;
        final seg = value.split(',').first.trim();
        if (seg.length >= 3) {
          bestName = seg;
          break;
        }
      }
      return (
        (bestName == null || bestName.isEmpty) ? 'Mi ubicación' : bestName,
        formatted.isEmpty ? fallback.$2 : formatted,
      );
    } catch (_) {
      return fallback;
    }
  }

  void chooseAddDestination(bool yes) {
    skipDestination = !yes;
    if (yes) {
      destination = null;
      messages.add(ChatLine(isUser: true, text: 'Sí, agregar destino'));
      messages.add(
        ChatLine(
          isUser: false,
          text: 'Busca o selecciona el destino:',
        ),
      );
      step = AssistantStep.destinationEntry;
      destinationSearchController.removeListener(onDestinationQueryChanged);
      destinationSearchController.addListener(onDestinationQueryChanged);
    } else {
      destination = null;
      messages.add(
        ChatLine(
          isUser: true,
          text: 'No, continuar sin destino',
        ),
      );
      _appendSummaryPrompt();
      step = AssistantStep.summary;
    }
    notifyListeners();
  }

  void _appendSummaryPrompt() {
    messages.add(
      ChatLine(
        isUser: false,
        text: '¿Todo está correcto? Listo para enviar el servicio.',
      ),
    );
  }

  void editBeforeSend() {
    lastError = null;
    destinationSearchController.removeListener(onDestinationQueryChanged);
    messages.add(
      ChatLine(
        isUser: true,
        text: 'Editar',
      ),
    );
    messages.add(
      ChatLine(
        isUser: false,
        text: domicilioInmediato
            ? 'Vamos a corregir origen, detalle y destino. Indica de nuevo el origen:'
            : isScheduled
                ? 'Vamos a ajustar fecha, origen y destino. Elige de nuevo la fecha y hora.'
                : 'Vamos a ajustar origen y destino. Indica el origen:',
      ),
    );
    origin = null;
    destination = null;
    skipDestination = false;
    originSearchController.clear();
    destinationSearchController.clear();
    domicilioDescripcionController.clear();
    domicilioDescripcionTexto = '';
    originPredictions = [];
    destinationPredictions = [];
    if (domicilioInmediato) {
      scheduledDateTime = null;
      step = AssistantStep.origin;
    } else if (isScheduled) {
      scheduledDateTime = null;
      step = AssistantStep.dateTime;
    } else {
      scheduledDateTime = null;
      step = AssistantStep.origin;
    }
    _wireOriginSearch();
    notifyListeners();
  }

  void restartChat() {
    originSearchController.removeListener(onOriginQueryChanged);
    destinationSearchController.removeListener(onDestinationQueryChanged);
    messages.clear();
    step = AssistantStep.requestKind;
    apiServiceType = 'taxi';
    isScheduled = false;
    domicilioInmediato = false;
    scheduledDateTime = null;
    origin = null;
    destination = null;
    skipDestination = false;
    lastError = null;
    originSearchController.clear();
    destinationSearchController.clear();
    domicilioDescripcionController.clear();
    domicilioDescripcionTexto = '';
    originPredictions = [];
    destinationPredictions = [];
    init();
  }

  String scheduledDisplayLabel() {
    if (scheduledDateTime == null) return 'Seleccionar fecha y hora';
    return DateFormat("EEEE d MMM • hh:mm a", 'es').format(scheduledDateTime!);
  }

  String destinationSummaryLine() {
    if (destination != null) return destination!.name;
    return 'Destino por definir';
  }

  Future<Map<String, dynamic>> submitRequest() async {
    if (origin == null) {
      throw StateError('Falta el origen');
    }
    if (isScheduled) {
      if (scheduledDateTime == null) {
        throw StateError('Falta la fecha u hora del servicio programado');
      }
      final dt = scheduledDateTime!.toLocal();
      final wall = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
      if (!wall.isAfter(DateTime.now())) {
        throw StateError(
          'La fecha y hora programadas deben ser posteriores al momento actual.',
        );
      }
    }

    lastError = null;
    isSubmitting = true;
    notifyListeners();

    RouteInfo? route;
    if (destination != null) {
      route = await _routes.getRoute(
        origin: LatLng(origin!.lat, origin!.lng),
        destination: LatLng(destination!.lat, destination!.lng),
      );
    }

    try {
      final Map<String, dynamic> response;
      if (isScheduled) {
        if (passengerUserId <= 0) {
          throw StateError(
            'No pudimos identificar tu cuenta. Cierra sesión y vuelve a entrar.',
          );
        }
        response = await _rides.requestProgramadoViaPhone(
          pasajeroId: passengerUserId,
          origin: origin!,
          destination: destination,
          scheduledAt: scheduledDateTime!,
          modality: 'taxi',
          distance: route?.distance,
          distanceValue: route?.distanceValue,
          duration: route?.duration,
          durationValue: route?.durationValue,
          estimatedPrice: 0,
          celular: passengerPhone,
          nombreCliente: passengerFullName,
          notasExtra: esDomicilioServicio && domicilioDescripcionTexto.isNotEmpty
              ? domicilioDescripcionTexto
              : null,
        );
      } else {
        response = await _rides.requestRide(
          origin: origin!,
          destination: destination,
          distance: route?.distance,
          distanceValue: route?.distanceValue,
          duration: route?.duration,
          durationValue: route?.durationValue,
          serviceType: apiServiceType,
          notas: esDomicilioServicio && domicilioDescripcionTexto.isNotEmpty
              ? domicilioDescripcionTexto
              : null,
        );
      }
      isSubmitting = false;
      notifyListeners();
      return response;
    } catch (e) {
      isSubmitting = false;
      lastError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  static String popayanNotice() => _popayanNotice;
}

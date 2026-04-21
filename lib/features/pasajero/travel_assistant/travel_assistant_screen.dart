import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/pasajero/presentation/pasajero_esperando_conductor_screen.dart';
import 'package:intellitaxi/features/pasajero/travel_assistant/travel_assistant_controller.dart';
import 'package:intellitaxi/features/pasajero/widgets/location_search_field.dart';
import 'package:intellitaxi/features/pasajero/widgets/waiting_for_driver_dialog.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Chat guiado para solicitar servicio (pasajero), alineado al diseño de referencia.
class TravelAssistantScreen extends StatefulWidget {
  const TravelAssistantScreen({super.key});

  @override
  State<TravelAssistantScreen> createState() => _TravelAssistantScreenState();
}

class _TravelAssistantScreenState extends State<TravelAssistantScreen> {
  late final TravelAssistantController _c;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final persona = auth.persona;
    final name = (persona?.nombre1 ?? 'Pasajero').trim();
    final fullName =
        '${persona?.nombre1 ?? ''} ${persona?.apellido1 ?? ''}'.trim();
    _c = TravelAssistantController(
      passengerFirstName: name,
      passengerUserId: auth.userId ?? 0,
      passengerFullName: fullName.isEmpty ? null : fullName,
      passengerPhone: persona?.celular,
    )..init();
    _c.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _c.removeListener(_scrollToBottom);
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      locale: const Locale('es', 'ES'),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (!mounted || time == null) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // Comparar con el instante actual (no con `now` capturado al abrir el calendario).
    if (!combined.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige una fecha y hora posteriores al momento actual.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _c.applyPickedDateTime(combined);
  }

  Future<void> _submit() async {
    if (_c.origin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica el origen antes de continuar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_c.isScheduled && _c.scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona fecha y hora para el servicio programado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isDelivery = _c.apiServiceType == 'domicilio';
    if (_c.isScheduled) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => Center(
          child: Card(
            color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Agendando tu servicio…',
                    style: Theme.of(dialogCtx).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WaitingForDriverDialog(isDelivery: isDelivery),
      );
    }
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      final response = await _c.submitRequest();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      if (_c.isScheduled) {
        final ok = response['success'] == true;
        final progId = response['servicio_programado_id'];
        if (ok && progId != null) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Servicio agendado'),
              content: Text(
                'Tu solicitud quedó registrada. Referencia: #$progId.\n'
                'El día acordado pasará al flujo operativo y podrá asignarse a un conductor.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message']?.toString() ??
                    'No se pudo confirmar el agendamiento.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final servicioId = _parseServicioId(response);
      if (servicioId != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PasajeroEsperandoConductorScreen(
              servicioId: servicioId,
              datosServicio: {
                'origen_lat': _c.origin!.lat,
                'origen_lng': _c.origin!.lng,
                'origen_address': _c.origin!.address,
                'destino_lat': _c.destination?.lat,
                'destino_lng': _c.destination?.lng,
                'destino_address':
                    _c.destination?.address ?? 'Destino no definido',
                'precio_ofrecido': 0,
              },
            ),
          ),
        );
        // No hacer Navigator.pop aquí: si la pantalla de espera hace
        // pushAndRemoveUntil al home, un pop extra puede quitar el [NavigationScreen]
        // recién colocado y dejar la app en negro o sin ruta válida.
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Respuesta sin id de servicio: ${response.toString().length > 120 ? "${response.toString().substring(0, 120)}..." : response}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      var msg = e.toString();
      if (msg.startsWith('StateError: ')) {
        msg = msg.substring('StateError: '.length);
      } else {
        msg = msg.replaceAll('Exception: ', '');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int? _parseServicioId(Map<String, dynamic> response) {
    try {
      if (response['solicitud_id'] != null) {
        return int.tryParse(response['solicitud_id'].toString());
      }
      if (response['servicio'] is Map<String, dynamic>) {
        final m = response['servicio'] as Map<String, dynamic>;
        return m['id'] as int?;
      }
      if (response['data'] is Map<String, dynamic>) {
        final m = response['data'] as Map<String, dynamic>;
        return m['id'] as int?;
      }
      if (response['servicio_id'] != null) {
        return int.tryParse(response['servicio_id'].toString());
      }
    } catch (e) {
      AppLogger.w('TravelAssistant: parse servicio id: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: cs.surfaceTint,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer.withValues(alpha: 0.65),
              child: Icon(
                Icons.directions_car_rounded,
                color: cs.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asistente de viajes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'En línea',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'restart') _c.restartChat();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'restart',
                child: Text('Reiniciar conversación'),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                    children: [
                      for (final m in _c.messages) _bubble(m),
                      if (_c.lastError != null) _errorBanner(_c.lastError!),
                      const SizedBox(height: 8),
                      _stepContent(),
                    ],
                  ),
                ),
                _bottomInput(),
              ],
            );
          },
        ),
    );
  }

  Widget _bubble(ChatLine m) {
    final cs = Theme.of(context).colorScheme;
    final align = m.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = m.isUser ? cs.primary : cs.surfaceContainerHighest;
    final fg = m.isUser ? cs.onPrimary : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.86,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!m.isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      cs.surfaceContainerHighest.withValues(alpha: 0.85),
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(m.isUser ? 18 : 6),
                      bottomRight: Radius.circular(m.isUser ? 6 : 18),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Text(
                      m.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: fg,
                            height: 1.35,
                            fontSize: 15,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _c.clearError,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: cs.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                          fontSize: 13,
                        ),
                  ),
                ),
                Icon(Icons.close, size: 18, color: cs.onErrorContainer.withValues(alpha: 0.65)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepContent() {
    switch (_c.step) {
      case AssistantStep.requestKind:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _requestKindCards(),
            const SizedBox(height: 12),
            _infoNotice(),
          ],
        );
      case AssistantStep.dateTime:
        return _dateTimeStepCard();
      case AssistantStep.origin:
        return _originStepCard();
      case AssistantStep.domicilioDescripcion:
        return _domicilioDescripcionCard();
      case AssistantStep.destinationPrompt:
        return _destinationChoiceRow();
      case AssistantStep.destinationEntry:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escribe el destino y elige una sugerencia, o usa «Usar dirección escrita».',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 10),
            LocationSearchField(
              controller: _c.destinationSearchController,
              label: 'Destino',
              icon: Icons.location_on_rounded,
              iconColor: AppColors.accent,
              predictions: _c.destinationPredictions,
              isSearching: _c.isSearchingDestination,
              onSelectPrediction: (p) => _c.pickDestinationFromPrediction(p),
              onClear: _c.clearDestinationSearchUi,
              onFieldSubmitted: (_) => _c.confirmDestinationFromSearchText(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _c.isConfirmingAddressSearch
                  ? null
                  : () => _c.confirmDestinationFromSearchText(),
              icon: _c.isConfirmingAddressSearch
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                _c.isConfirmingAddressSearch
                    ? 'Buscando…'
                    : 'Usar dirección escrita',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        );
      case AssistantStep.summary:
        return _summaryCard();
    }
  }

  Widget _requestKindCards() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget card({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color accent,
      required VoidCallback onTap,
    }) {
      return Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.outline),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          icon: Icons.bolt_rounded,
          title: 'Servicio inmediato',
          subtitle: 'Taxi para ahora: origen, destino opcional y envío.',
          accent: const Color(0xFF22C55E),
          onTap: () => _c.selectRequestKind(immediate: true),
        ),
        const SizedBox(height: 10),
        card(
          icon: Icons.event_available_rounded,
          title: 'Servicio programado',
          subtitle: 'Agenda fecha y hora para un taxi; luego origen y destino.',
          accent: const Color(0xFFA855F7),
          onTap: () => _c.selectRequestKind(immediate: false),
        ),
        const SizedBox(height: 10),
        card(
          icon: Icons.shopping_bag_outlined,
          title: 'Domicilio',
          subtitle: 'Envío o recogida a domicilio: detalle, origen y destino.',
          accent: const Color(0xFF0EA5E9),
          onTap: () => _c.selectDomicilioInmediato(),
        ),
      ],
    );
  }

  Widget _infoNotice() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              TravelAssistantController.popayanNotice(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontSize: 13,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTimeStepCard() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '1',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¿Cuándo necesitas el servicio?',
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.access_time_filled_rounded,
                  color: AppColors.accent),
              title: Text(
                _c.scheduledDateTime == null
                    ? 'Toca para elegir'
                    : DateFormat(
                        "EEEE d MMM • hh:mm a",
                        'es',
                      ).format(_c.scheduledDateTime!),
                style: tt.bodyLarge?.copyWith(color: cs.onSurface),
              ),
              trailing:
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              onTap: _pickDateTime,
            ),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Cambiar fecha y hora'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurface,
                side: BorderSide(color: cs.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _domicilioDescripcionCard() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes_rounded, color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Detalle del pedido (opcional)',
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Medicamento, paquete, compra en tienda, etc.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _c.domicilioDescripcionController,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(
                counterText: '',
                hintText:
                    'Ej.: recoger medicamento, traer pedido del restaurante…',
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _c.continueDomicilioDescripcion(),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _originStepCard() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _c.isScheduled ? '2' : '1',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¿Desde dónde partes?',
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _c.isLoadingLocation
                  ? null
                  : () async {
                      await _c.useCurrentLocationAsOrigin();
                    },
              icon: _c.isLoadingLocation
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Icon(Icons.my_location_rounded, color: cs.primary),
              label: const Text('Usar mi ubicación actual'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurface,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
                side: BorderSide(color: cs.outline),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Escribe la dirección y elige una sugerencia, o pulsa «Usar dirección escrita» para buscar el texto tal cual.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            LocationSearchField(
              controller: _c.originSearchController,
              label: 'Origen',
              icon: Icons.edit_location_alt_outlined,
              iconColor: Colors.green,
              predictions: _c.originPredictions,
              isSearching: _c.isSearchingOrigin,
              onSelectPrediction: (p) => _c.pickOriginFromPrediction(p),
              onClear: _c.clearOriginSearchUi,
              onFieldSubmitted: (_) => _c.confirmOriginFromSearchText(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _c.isConfirmingAddressSearch
                  ? null
                  : () => _c.confirmOriginFromSearchText(),
              icon: _c.isConfirmingAddressSearch
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                _c.isConfirmingAddressSearch
                    ? 'Buscando…'
                    : 'Usar dirección escrita',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _destinationChoiceRow() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              _c.isScheduled ? '3' : '2',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿Deseas agregar un destino?',
                style: tt.titleSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => _c.chooseAddDestination(true),
          icon: const Icon(Icons.pin_drop_rounded),
          label: const Text('Sí, agregar destino'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.onSurface,
            side: BorderSide(color: cs.outline),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => _c.chooseAddDestination(false),
          icon: const Icon(Icons.skip_next_rounded),
          label: const Text('No, continuar sin destino'),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tipo = _c.domicilioInmediato
        ? 'Domicilio'
        : (_c.isScheduled ? 'Taxi (programado)' : 'Taxi (inmediato)');
    final auth = context.watch<AuthProvider>();
    final cliente = '${auth.persona?.nombre1 ?? ''} ${auth.persona?.apellido1 ?? ''}'
        .trim();
    final tel = auth.persona?.celular?.trim();

    final modoColor =
        _c.isScheduled ? const Color(0xFFA855F7) : const Color(0xFF22C55E);

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_rounded, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resumen del servicio',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: modoColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: modoColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _c.isScheduled
                        ? 'Programado'
                        : (_c.domicilioInmediato
                            ? 'Domicilio'
                            : 'Inmediato'),
                    style: TextStyle(
                      color: modoColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _summaryRow(
              Icons.local_taxi_rounded,
              cs.onSurfaceVariant,
              'Modalidad',
              tipo,
            ),
            if (!_c.isScheduled)
              _summaryRow(
                Icons.schedule_rounded,
                modoColor,
                'Momento',
                'Inmediato (en cuanto se asigne conductor)',
              ),
            if (_c.isScheduled && _c.scheduledDateTime != null) ...[
              _summaryRow(
                Icons.calendar_today_rounded,
                modoColor,
                'Fecha programada',
                DateFormat('EEEE d MMM yyyy', 'es')
                    .format(_c.scheduledDateTime!),
              ),
              _summaryRow(
                Icons.access_time_filled_rounded,
                modoColor,
                'Hora programada',
                DateFormat('hh:mm a', 'es').format(_c.scheduledDateTime!),
              ),
            ],
            if (_c.esDomicilioServicio && _c.domicilioDescripcionTexto.isNotEmpty)
              _summaryRow(
                Icons.notes_rounded,
                cs.primary,
                'Detalle del pedido',
                _c.domicilioDescripcionTexto,
              ),
            _summaryRow(
              Icons.my_location_rounded,
              const Color(0xFF22C55E),
              'Origen',
              _c.origin?.address ?? '—',
            ),
            _summaryRow(
              Icons.location_on_rounded,
              AppColors.accent,
              'Destino',
              _c.destinationSummaryLine(),
            ),
            if (cliente.isNotEmpty)
              _summaryRow(
                Icons.person_outline_rounded,
                cs.onSurfaceVariant,
                'Cliente',
                cliente,
              ),
            if (tel != null && tel.isNotEmpty)
              _summaryRow(
                Icons.phone_android_rounded,
                cs.onSurfaceVariant,
                'Teléfono',
                tel,
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    IconData icon,
    Color iconColor,
    String label,
    String value,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomInput() {
    final cs = Theme.of(context).colorScheme;
    if (_c.step == AssistantStep.summary) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _c.isSubmitting ? null : () => _c.editBeforeSend(),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: cs.outline),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _c.isSubmitting ? null : _submit,
                  icon: _c.isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Iconsax.send_1_copy),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _c.isScheduled ? 'Agendar servicio' : 'Enviar servicio',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _c.isScheduled ? 'Confirmar hora' : 'Solicitar ahora',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onPrimary.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Un solo contexto de texto por paso: origen/destino/fecha usan sus propios campos.
    return const SizedBox.shrink();
  }
}

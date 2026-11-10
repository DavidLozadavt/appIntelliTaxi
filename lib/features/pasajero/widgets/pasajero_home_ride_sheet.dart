import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
import 'package:intellitaxi/features/pasajero/widgets/location_search_field.dart';
import 'package:intellitaxi/features/pasajero/widgets/ride_request_floating_cta.dart';
import 'package:intellitaxi/features/pasajero/widgets/service_type_selector.dart';

/// Bottom sheet de solicitud: taxi (solo recogida) o domicilio (recogida y destino).
class PasajeroHomeRideSheet extends StatelessWidget {
  const PasajeroHomeRideSheet({
    super.key,
    required this.scrollController,
    required this.serviceType,
    required this.pickupDisplayLabel,
    this.pickupStreetDetail,
    required this.originController,
    required this.destinationController,
    required this.originFocusNode,
    required this.destinationFocusNode,
    required this.originPredictions,
    required this.destinationPredictions,
    required this.isSearchingOrigin,
    required this.isSearchingDestination,
    required this.onToggleSheet,
    required this.onServiceTypeChanged,
    required this.onSelectOrigin,
    required this.onSelectDestination,
    required this.onClearOrigin,
    required this.onClearDestination,
    required this.editingPickup,
    required this.onEditPickup,
    this.locatingGps = false,
    required this.ctaLabel,
    this.ctaTrailing,
    required this.onCtaPressed,
    this.ctaLoading = false,
    this.ctaColor = AppColors.primary,
  });

  final ScrollController scrollController;
  final String serviceType;
  final String pickupDisplayLabel;
  final String? pickupStreetDetail;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final FocusNode originFocusNode;
  final FocusNode destinationFocusNode;
  final List<PlacePrediction> originPredictions;
  final List<PlacePrediction> destinationPredictions;
  final bool isSearchingOrigin;
  final bool isSearchingDestination;
  final VoidCallback onToggleSheet;
  final ValueChanged<String> onServiceTypeChanged;
  final Future<void> Function(PlacePrediction prediction) onSelectOrigin;
  final Future<void> Function(PlacePrediction prediction) onSelectDestination;
  final VoidCallback onClearOrigin;
  final VoidCallback onClearDestination;
  final bool editingPickup;
  final VoidCallback onEditPickup;
  final bool locatingGps;
  final String ctaLabel;
  final String? ctaTrailing;
  final VoidCallback? onCtaPressed;
  final bool ctaLoading;
  final Color ctaColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: onToggleSheet,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: _tripFormChildren(context),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                10 + MediaQuery.paddingOf(context).bottom,
              ),
              child: RideRequestFloatingCta(
                label: ctaLabel,
                trailing: ctaTrailing,
                onPressed: onCtaPressed,
                isLoading: ctaLoading,
                color: ctaColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tripFormChildren(BuildContext context) {
    return [
      ServiceTypeSelector(
        selectedType: serviceType,
        onTypeChanged: onServiceTypeChanged,
      ),
      if (locatingGps) ...[
        const SizedBox(height: 12),
        const Text(
          'Ubicando… espera un GPS de ≤ 30 m o mueve el pin a mano.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
      const SizedBox(height: 16),
      if (editingPickup) ...[
        LocationSearchField(
          controller: originController,
          label: 'Recogida en',
          hintText:
              'Ej.: Susana López de Valencia o Polideportivo vereda de Torres',
          icon: Icons.my_location,
          iconColor: AppColors.green,
          focusNode: originFocusNode,
          autofocus: true,
          predictions: originPredictions,
          isSearching: isSearchingOrigin,
          onSelectPrediction: onSelectOrigin,
          onClear: onClearOrigin,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onClearOrigin,
            icon: const Icon(Icons.gps_fixed, size: 16),
            label: const Text('Usar mi ubicación'),
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (serviceType != 'taxi')
        LocationSearchField(
          controller: destinationController,
          label: '¿Qué necesitas enviar?',
          hintText: '¿Qué enviamos?',
          icon: Icons.location_on,
          iconColor: AppColors.primary,
          focusNode: destinationFocusNode,
          predictions: destinationPredictions,
          isSearching: isSearchingDestination,
          onSelectPrediction: onSelectDestination,
          onClear: onClearDestination,
        ),
      if (!editingPickup) ...[
        if (serviceType != 'taxi') const SizedBox(height: 12),
        _pickupCard(context),
      ],
    ];
  }

  Widget _pickupCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = pickupStreetDetail?.trim();
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onEditPickup,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.my_location,
                  color: AppColors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECOGIDA EN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pickupDisplayLabel,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1C),
                      ),
                    ),
                    if (detail != null &&
                        detail.isNotEmpty &&
                        detail.toLowerCase() !=
                            pickupDisplayLabel.toLowerCase())
                      Text(
                        detail,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEditPickup,
                tooltip: 'Cambiar recogida',
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

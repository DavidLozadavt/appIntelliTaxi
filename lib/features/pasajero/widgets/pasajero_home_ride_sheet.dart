import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
import 'package:intellitaxi/features/pasajero/services/routes_service.dart';
import 'package:intellitaxi/features/pasajero/widgets/location_search_field.dart';
import 'package:intellitaxi/features/pasajero/widgets/ride_request_floating_cta.dart';
import 'package:intellitaxi/features/pasajero/widgets/route_info_card.dart';
import 'package:intellitaxi/features/pasajero/widgets/service_type_selector.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';

/// Bottom sheet de solicitud: taxi/domicilio, destino, recogida y CTA.
class PasajeroHomeRideSheet extends StatelessWidget {
  const PasajeroHomeRideSheet({
    super.key,
    required this.scrollController,
    required this.serviceType,
    required this.selectedOrigin,
    required this.selectedDestination,
    required this.selectedDestinationArea,
    required this.routeInfo,
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
    required this.recentDestinations,
    this.favoriteHome,
    this.favoriteWork,
    required this.destinationSummaryText,
    required this.onToggleSheet,
    required this.onServiceTypeChanged,
    required this.onSelectOrigin,
    required this.onSelectDestination,
    required this.onClearOrigin,
    required this.onClearDestination,
    required this.onRecentDestinationTap,
    required this.onSaveFavoriteDestination,
    required this.editingPickup,
    required this.onEditPickup,
    required this.ctaLabel,
    this.ctaTrailing,
    required this.onCtaPressed,
    this.ctaLoading = false,
    this.ctaColor = AppColors.primary,
  });

  final ScrollController scrollController;
  final String serviceType;
  final TripLocation? selectedOrigin;
  final TripLocation? selectedDestination;
  final String? selectedDestinationArea;
  final RouteInfo? routeInfo;
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
  final List<TripLocation> recentDestinations;
  final TripLocation? favoriteHome;
  final TripLocation? favoriteWork;
  final String Function(TripLocation destination) destinationSummaryText;
  final VoidCallback onToggleSheet;
  final ValueChanged<String> onServiceTypeChanged;
  final Future<void> Function(PlacePrediction prediction) onSelectOrigin;
  final Future<void> Function(PlacePrediction prediction) onSelectDestination;
  final VoidCallback onClearOrigin;
  final VoidCallback onClearDestination;
  final void Function(TripLocation location) onRecentDestinationTap;
  final Future<void> Function(String kind) onSaveFavoriteDestination;
  final bool editingPickup;
  final VoidCallback onEditPickup;
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
      const SizedBox(height: 16),
      if (editingPickup) ...[
        LocationSearchField(
          controller: originController,
          label: 'Recogida en',
          hintText: '¿Dónde te recogemos?',
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
      LocationSearchField(
        controller: destinationController,
        label: serviceType == 'taxi' ? '¿A dónde vas?' : '¿Qué necesitas enviar?',
        hintText: serviceType == 'taxi' ? '¿A dónde vamos?' : '¿Qué enviamos?',
        icon: Icons.location_on,
        iconColor: AppColors.primary,
        focusNode: destinationFocusNode,
        predictions: destinationPredictions,
        isSearching: isSearchingDestination,
        onSelectPrediction: onSelectDestination,
        onClear: onClearDestination,
      ),
      if (_shortcutChips().isNotEmpty) ...[
        const SizedBox(height: 10),
        _shortcutChipsRow(),
      ],
      if (!editingPickup) ...[
        const SizedBox(height: 12),
        _pickupCard(context),
      ],
      if (selectedDestination != null && routeInfo == null) ...[
        const SizedBox(height: 10),
        _selectedDestinationSummary(context),
      ],
      if (selectedDestination != null &&
          serviceType != 'taxi' &&
          routeInfo == null) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onSaveFavoriteDestination('home'),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Guardar Casa'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onSaveFavoriteDestination('work'),
                icon: const Icon(Icons.work_outline, size: 18),
                label: const Text('Guardar Trabajo'),
              ),
            ),
          ],
        ),
      ],
      if (routeInfo != null) ...[
        const SizedBox(height: 12),
        RouteInfoCard(routeInfo: routeInfo!),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
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
                        maxLines: 1,
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

  List<(IconData, String, TripLocation)> _shortcutChips() {
    final chips = <(IconData, String, TripLocation)>[];
    final seen = <String>{};

    void add(IconData icon, String label, TripLocation loc) {
      final key = loc.placeId ?? '${loc.lat.toStringAsFixed(4)},${loc.lng.toStringAsFixed(4)}';
      if (seen.contains(key)) return;
      seen.add(key);
      chips.add((icon, label, loc));
    }

    if (favoriteWork != null) add(Icons.work_outline, 'Trabajo', favoriteWork!);
    if (favoriteHome != null) add(Icons.home_outlined, 'Casa', favoriteHome!);
    for (final item in recentDestinations) {
      if (chips.length >= 4) break;
      add(Iconsax.location_copy, item.name, item);
    }
    return chips;
  }

  Widget _shortcutChipsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in _shortcutChips())
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.transparent,
                side: BorderSide(color: Colors.grey.shade300),
                avatar: Icon(chip.$1, size: 16, color: Colors.grey.shade700),
                label: Text(
                  chip.$2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => onRecentDestinationTap(chip.$3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectedDestinationSummary(BuildContext context) {
    final destination = selectedDestination;
    if (destination == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final area = selectedDestinationArea?.trim();
    final hasArea = area != null && area.isNotEmpty;
    final address = destination.address.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (hasArea) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Barrio: $area',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (address.isNotEmpty && address != destination.name) ...[
                  const SizedBox(height: 3),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

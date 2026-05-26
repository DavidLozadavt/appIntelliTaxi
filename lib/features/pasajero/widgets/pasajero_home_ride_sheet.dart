import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
import 'package:intellitaxi/features/pasajero/services/routes_service.dart';
import 'package:intellitaxi/features/pasajero/widgets/location_search_field.dart';
import 'package:intellitaxi/features/pasajero/widgets/route_info_card.dart';
import 'package:intellitaxi/features/pasajero/widgets/service_type_selector.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';

/// Bottom sheet de solicitud de viaje en home pasajero (arrastre + formulario).
class PasajeroHomeRideSheet extends StatelessWidget {
  const PasajeroHomeRideSheet({
    super.key,
    required this.scrollController,
    required this.sheetExtent,
    required this.serviceType,
    required this.selectedOrigin,
    required this.selectedDestination,
    required this.selectedDestinationArea,
    required this.routeInfo,
    required this.pickupDisplayLabel,
    this.pickupStreetDetail,
    required this.originController,
    required this.destinationController,
    required this.destinationFocusNode,
    required this.originPredictions,
    required this.destinationPredictions,
    required this.isSearchingOrigin,
    required this.isSearchingDestination,
    required this.recentDestinations,
    required this.destinationSummaryText,
    required this.onToggleSheet,
    required this.onOpenQuickRequest,
    required this.onServiceTypeChanged,
    required this.onSelectOrigin,
    required this.onSelectDestination,
    required this.onClearOrigin,
    required this.onClearDestination,
    required this.onRecentDestinationTap,
    required this.onSaveFavoriteDestination,
  });

  final ScrollController scrollController;
  final ValueNotifier<double> sheetExtent;
  final String serviceType;
  final TripLocation? selectedOrigin;
  final TripLocation? selectedDestination;
  final String? selectedDestinationArea;
  final RouteInfo? routeInfo;
  final String pickupDisplayLabel;
  final String? pickupStreetDetail;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final FocusNode destinationFocusNode;
  final List<PlacePrediction> originPredictions;
  final List<PlacePrediction> destinationPredictions;
  final bool isSearchingOrigin;
  final bool isSearchingDestination;
  final List<TripLocation> recentDestinations;
  final String Function(TripLocation destination) destinationSummaryText;
  final VoidCallback onToggleSheet;
  final VoidCallback onOpenQuickRequest;
  final ValueChanged<String> onServiceTypeChanged;
  final Future<void> Function(PlacePrediction prediction) onSelectOrigin;
  final Future<void> Function(PlacePrediction prediction) onSelectDestination;
  final VoidCallback onClearOrigin;
  final VoidCallback onClearDestination;
  final void Function(TripLocation location) onRecentDestinationTap;
  final Future<void> Function(String kind) onSaveFavoriteDestination;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: onToggleSheet,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: sheetExtent,
                    builder: (context, extent, _) {
                      final showFormOnly = extent >= 0.24;
                      if (showFormOnly) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._tripFormChildren(context),
                            const SizedBox(height: 88),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _minimizedContent(context),
                          const SizedBox(height: 72),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _minimizedContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final originText = pickupDisplayLabel;
    final originDetail = pickupStreetDetail?.trim();
    final hasDestination = selectedDestination != null;
    final destinationText = hasDestination
        ? destinationSummaryText(selectedDestination!)
        : (serviceType == 'taxi' ? '¿A dónde vas?' : '¿Qué necesitas enviar?');

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onOpenQuickRequest,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasDestination
                ? AppColors.primary.withValues(alpha: 0.25)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.primary.withValues(alpha: 0.12)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasDestination) ...[
              Text(
                destinationText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (routeInfo != null) ...[
                const SizedBox(height: 8),
                RouteInfoCard(routeInfo: routeInfo!, compact: true),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.my_location,
                    size: 14,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      originDetail != null && originDetail.isNotEmpty
                          ? 'Desde: $originText · $originDetail'
                          : 'Desde: $originText',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destinationText,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          originDetail != null && originDetail.isNotEmpty
                              ? 'Desde: $originText · $originDetail'
                              : 'Desde: $originText',
                          maxLines: 2,
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
                  Icon(
                    Icons.keyboard_arrow_up,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ],
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
      LocationSearchField(
        controller: destinationController,
        label: serviceType == 'taxi' ? '¿A dónde vas?' : '¿Qué necesitas enviar?',
        icon: Icons.location_on,
        iconColor: AppColors.primary,
        focusNode: destinationFocusNode,
        predictions: destinationPredictions,
        isSearching: isSearchingDestination,
        onSelectPrediction: onSelectDestination,
        onClear: onClearDestination,
      ),
      if (recentDestinations.isNotEmpty) ...[
        const SizedBox(height: 12),
        _recentDestinationChips(),
      ],
      const SizedBox(height: 14),
      LocationSearchField(
        controller: originController,
        label: 'Recogida en',
        icon: Icons.my_location,
        iconColor: AppColors.green,
        predictions: originPredictions,
        isSearching: isSearchingOrigin,
        onSelectPrediction: onSelectOrigin,
        onClear: onClearOrigin,
      ),
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
        const SizedBox(height: 14),
        RouteInfoCard(routeInfo: routeInfo!),
      ],
      const SizedBox(height: 16),
    ];
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

  Widget _recentDestinationChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recientes',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: recentDestinations
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(item.name),
                      avatar: const Icon(Icons.history, size: 16),
                      onPressed: () => onRecentDestinationTap(item),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

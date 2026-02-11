import 'package:flutter/material.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';
import 'package:intellitaxi/features/rides/services/places_service.dart';
import 'package:geolocator/geolocator.dart';

class RideRequestBottomSheet extends StatefulWidget {
  final Position? currentPosition;
  final Function(TripLocation origin, TripLocation destination) onConfirm;

  const RideRequestBottomSheet({
    super.key,
    this.currentPosition,
    required this.onConfirm,
  });

  @override
  State<RideRequestBottomSheet> createState() => _RideRequestBottomSheetState();
}

class _RideRequestBottomSheetState extends State<RideRequestBottomSheet>
    with SingleTickerProviderStateMixin {
  final PlacesService _placesService = PlacesService();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  TripLocation? _selectedOrigin;
  TripLocation? _selectedDestination;

  List<PlacePrediction> _originPredictions = [];
  List<PlacePrediction> _destinationPredictions = [];

  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;

  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  final double _minHeight = 0.35; // 35% de la pantalla
  final double _maxHeight = 0.9; // 90% de la pantalla
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    // Configurar ubicación actual como origen por defecto
    if (widget.currentPosition != null) {
      _selectedOrigin = TripLocation.currentLocation(
        lat: widget.currentPosition!.latitude,
        lng: widget.currentPosition!.longitude,
      );
      _originController.text = 'Mi ubicación actual';
    }

    // Animación de altura
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _heightAnimation = Tween<double>(
      begin: _minHeight,
      end: _maxHeight,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Listeners para búsqueda
    _originController.addListener(_onOriginChanged);
    _destinationController.addListener(_onDestinationChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _toggleHeight() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onOriginChanged() {
    if (_originController.text.isEmpty) {
      setState(() {
        _originPredictions = [];
        _isSearchingOrigin = false;
      });
      return;
    }

    setState(() => _isSearchingOrigin = true);

    _placesService
        .getAutocompletePredictions(_originController.text)
        .then((predictions) {
      if (mounted) {
        setState(() {
          _originPredictions = predictions;
          _isSearchingOrigin = false;
        });
      }
    });
  }

  void _onDestinationChanged() {
    if (_destinationController.text.isEmpty) {
      setState(() {
        _destinationPredictions = [];
        _isSearchingDestination = false;
      });
      return;
    }

    setState(() => _isSearchingDestination = true);

    _placesService
        .getAutocompletePredictions(_destinationController.text)
        .then((predictions) {
      if (mounted) {
        setState(() {
          _destinationPredictions = predictions;
          _isSearchingDestination = false;
        });
      }
    });
  }

  Future<void> _selectOrigin(PlacePrediction prediction) async {
    final details = await _placesService.getPlaceDetails(prediction.placeId);

    if (details != null && mounted) {
      setState(() {
        _selectedOrigin = TripLocation.fromPlaceDetails(
          placeId: prediction.placeId,
          name: details.name,
          address: details.address,
          lat: details.lat,
          lng: details.lng,
        );
        _originController.text = prediction.mainText;
        _originPredictions = [];
      });
    }
  }

  Future<void> _selectDestination(PlacePrediction prediction) async {
    final details = await _placesService.getPlaceDetails(prediction.placeId);

    if (details != null && mounted) {
      setState(() {
        _selectedDestination = TripLocation.fromPlaceDetails(
          placeId: prediction.placeId,
          name: details.name,
          address: details.address,
          lat: details.lat,
          lng: details.lng,
        );
        _destinationController.text = prediction.mainText;
        _destinationPredictions = [];
      });
    }
  }

  void _confirmTrip() {
    if (_selectedOrigin != null && _selectedDestination != null) {
      widget.onConfirm(_selectedOrigin!, _selectedDestination!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        return GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! < -5) {
              // Arrastrar hacia arriba
              if (!_isExpanded) _toggleHeight();
            } else if (details.primaryDelta! > 5) {
              // Arrastrar hacia abajo
              if (_isExpanded) _toggleHeight();
            }
          },
          child: Container(
            height: screenHeight * _heightAnimation.value,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle para arrastrar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Título
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        '¿A dónde vas?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                        ),
                        onPressed: _toggleHeight,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Campos de búsqueda
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Campo de origen
                      _buildLocationField(
                        controller: _originController,
                        label: 'Origen',
                        icon: Icons.my_location,
                        iconColor: Colors.green,
                        predictions: _originPredictions,
                        isSearching: _isSearchingOrigin,
                        onSelectPrediction: _selectOrigin,
                        onClear: () {
                          setState(() {
                            _originController.clear();
                            _selectedOrigin = null;
                            _originPredictions = [];
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // Campo de destino
                      _buildLocationField(
                        controller: _destinationController,
                        label: 'Destino',
                        icon: Icons.location_on,
                        iconColor: Colors.red,
                        predictions: _destinationPredictions,
                        isSearching: _isSearchingDestination,
                        onSelectPrediction: _selectDestination,
                        onClear: () {
                          setState(() {
                            _destinationController.clear();
                            _selectedDestination = null;
                            _destinationPredictions = [];
                          });
                        },
                      ),

                      const SizedBox(height: 24),

                      // Botón de confirmar
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _selectedOrigin != null &&
                                  _selectedDestination != null
                              ? _confirmTrip
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Continuar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Info de búsqueda limitada
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Búsqueda limitada a Popayán y alrededores',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required List<PlacePrediction> predictions,
    required bool isSearching,
    required Function(PlacePrediction) onSelectPrediction,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: label,
              prefixIcon: Icon(icon, color: iconColor),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        // Resultados de búsqueda
        if (isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),

        if (!isSearching && predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: predictions.length > 5 ? 5 : predictions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final prediction = predictions[index];
                return ListTile(
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: Colors.grey.shade600,
                  ),
                  title: Text(
                    prediction.mainText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    prediction.secondaryText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onTap: () => onSelectPrediction(prediction),
                );
              },
            ),
          ),
      ],
    );
  }
}

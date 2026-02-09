import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/features/conductor/conductor_home_page.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Página para seleccionar el vehículo antes de iniciar turno
class VehiculoSelectorPage extends StatefulWidget {
  const VehiculoSelectorPage({Key? key}) : super(key: key);

  @override
  State<VehiculoSelectorPage> createState() => _VehiculoSelectorPageState();
}

class _VehiculoSelectorPageState extends State<VehiculoSelectorPage> {
  List<Vehiculo> _vehiculos = [];
  bool _isLoading = true;
  Position? _currentPosition;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. Primero verificar permisos y obtener ubicación
    await _obtenerUbicacion();
    
    // 2. Luego cargar vehículos disponibles
    await _cargarVehiculos();
    
    setState(() => _isLoading = false);
  }

  Future<void> _obtenerUbicacion() async {
    try {
      // Verificar si el servicio está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'El GPS está desactivado. Actívalo para continuar.';
        });
        return;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Permisos de ubicación denegados';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'Permisos de ubicación denegados permanentemente. Actívalos en configuración.';
        });
        return;
      }

      // Obtener ubicación actual
      print('📍 Obteniendo ubicación del conductor...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
      });

      print('✅ Ubicación obtenida: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');
      setState(() {
        _errorMessage = 'Error obteniendo ubicación: ${e.toString()}';
      });
    }
  }

  Future<void> _cargarVehiculos() async {
    // TODO: Aquí deberías cargar los vehículos del conductor desde tu API
    // Por ahora uso datos de ejemplo
    setState(() {
      _vehiculos = [
        Vehiculo(id: 399, placa: 'ABC123', marca: 'Chevrolet', modelo: 'Spark'),
        // Agrega más vehículos si el conductor tiene múltiples
      ];
    });
  }

  void _seleccionarVehiculo(Vehiculo vehiculo) {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No se pudo obtener tu ubicación'),
        ),
      );
      return;
    }

    // Navegar a la página principal del conductor con el vehículo seleccionado
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ConductorHomePage(
          idVehiculo: vehiculo.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Vehículo'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Verificando ubicación y vehículos...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Iconsax.info_circle_copy,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _initialize();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Información de ubicación
                    if (_currentPosition != null)
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Iconsax.tick_circle_copy,
                                      color: Colors.green),
                                  SizedBox(width: 10),
                                  Text(
                                    '✅ Ubicación obtenida',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              Text(
                                'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    const Text(
                      'Selecciona tu vehículo:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    // Lista de vehículos
                    ..._vehiculos.map((vehiculo) {
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Iconsax.car_copy,
                                color: Colors.white),
                          ),
                          title: Text(
                            vehiculo.placa,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text('${vehiculo.marca} ${vehiculo.modelo}'),
                          trailing: const Icon(Iconsax.arrow_right_3_copy),
                          onTap: () => _seleccionarVehiculo(vehiculo),
                        ),
                      );
                    }).toList(),
                  ],
                ),
    );
  }
}

/// Modelo simple de vehículo
class Vehiculo {
  final int id;
  final String placa;
  final String marca;
  final String modelo;

  Vehiculo({
    required this.id,
    required this.placa,
    required this.marca,
    required this.modelo,
  });
}

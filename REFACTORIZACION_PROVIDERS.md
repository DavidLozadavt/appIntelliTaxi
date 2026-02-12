# 📚 Guía de Refactorización: Lógica de Vistas a Providers

## 🎯 Objetivo

Esta guía te ayudará a refactorizar tu código de Flutter para separar la lógica de negocio de las vistas (UI), utilizando el patrón Provider. Esto hace que tu código sea más:

- ✅ **Mantenible**: La lógica está centralizada y es fácil de encontrar
- ✅ **Testeable**: Puedes probar la lógica sin necesidad de widgets
- ✅ **Reutilizable**: Múltiples widgets pueden usar la misma lógica
- ✅ **Escalable**: Es más fácil agregar nuevas funcionalidades

---

## 📦 Providers Creados

### 1. **ConductorHomeProvider**
**Ubicación**: `lib/features/conductor/providers/conductor_home_provider.dart`

**Responsabilidades**:
- ✅ Gestión de ubicación GPS del conductor
- ✅ Manejo de turnos (iniciar/finalizar)
- ✅ Gestión de vehículos disponibles
- ✅ Conexión a Pusher para solicitudes en tiempo real
- ✅ Manejo de solicitudes de servicio
- ✅ Estado online/offline del conductor

**Uso básico**:
```dart
// En tu widget
class HomeConductor extends StatefulWidget {
  @override
  State<HomeConductor> createState() => _HomeConductorState();
}

class _HomeConductorState extends State<HomeConductor> {
  @override
  void initState() {
    super.initState();
    // Inicializar el provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConductorHomeProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConductorHomeProvider>(
      builder: (context, provider, child) {
        // Usar el estado del provider
        if (provider.isLoadingLocation) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        return Scaffold(
          body: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                provider.currentPosition!.latitude,
                provider.currentPosition!.longitude,
              ),
              zoom: 15,
            ),
          ),
          // Botón para iniciar turno
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              if (provider.isOnline) {
                await provider.finalizarTurno();
              } else {
                // Seleccionar vehículo primero
                if (provider.vehiculoSeleccionado != null) {
                  await provider.iniciarTurno(
                    provider.vehiculoSeleccionado!.id,
                  );
                }
              }
            },
            child: Icon(
              provider.isOnline ? Icons.stop : Icons.play_arrow,
            ),
          ),
        );
      },
    );
  }
}
```

---

### 2. **DocumentosProvider**
**Ubicación**: `lib/features/conductor/providers/documentos_provider.dart`

**Responsabilidades**:
- ✅ Carga de documentos del conductor
- ✅ Actualización de documentos (imagen, fecha de vigencia)
- ✅ Cálculo de porcentaje de completitud
- ✅ Detección de documentos vencidos o por vencer

**Uso básico**:
```dart
class DocumentosScreen extends StatefulWidget {
  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final conductorId = authProvider.user?.id;
    
    if (conductorId != null) {
      context.read<DocumentosProvider>().cargarDocumentos(conductorId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mis Documentos')),
      body: Consumer<DocumentosProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          // Mostrar porcentaje de completitud
          final porcentaje = provider.porcentajeCompletitud;
          
          return Column(
            children: [
              // Indicador de progreso
              LinearProgressIndicator(
                value: porcentaje,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  porcentaje >= 1.0 ? Colors.green : Colors.orange,
                ),
              ),
              
              Text(
                '${provider.documentosVigentes}/${provider.totalDocumentos} documentos vigentes',
              ),

              // Lista de documentos
              Expanded(
                child: ListView.builder(
                  itemCount: provider.documentos.length,
                  itemBuilder: (context, index) {
                    final documento = provider.documentos[index];
                    return ListTile(
                      title: Text(documento.nombreDocumento),
                      subtitle: Text(
                        documento.estadoVigencia ?? 'VIGENTE',
                      ),
                      onTap: () async {
                        // Actualizar documento
                        final archivo = await provider.seleccionarImagen();
                        if (archivo != null) {
                          final authProvider = context.read<AuthProvider>();
                          await provider.actualizarDocumento(
                            documentoId: documento.id,
                            conductorId: authProvider.user!.id,
                            archivo: archivo,
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

---

### 3. **ServicioActivoProvider**
**Ubicación**: `lib/features/conductor/providers/servicio_activo_provider.dart`

**Responsabilidades**:
- ✅ Tracking GPS del servicio activo
- ✅ Cambio de estados del servicio (aceptado → en_camino → llegué → en_curso → finalizado)
- ✅ Dibujo de rutas en el mapa
- ✅ Gestión de marcadores
- ✅ Extracción de información del pasajero

**Uso básico**:
```dart
class ConductorServicioActivoScreen extends StatefulWidget {
  final Map<String, dynamic> servicio;
  final int conductorId;

  const ConductorServicioActivoScreen({
    required this.servicio,
    required this.conductorId,
  });

  @override
  State<ConductorServicioActivoScreen> createState() => 
      _ConductorServicioActivoScreenState();
}

class _ConductorServicioActivoScreenState 
    extends State<ConductorServicioActivoScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicioActivoProvider>().inicializar(
        servicio: widget.servicio,
        conductorId: widget.conductorId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServicioActivoProvider>(
      builder: (context, provider, child) {
        final proximaAccion = provider.getProximaAccion();

        return Scaffold(
          body: Stack(
            children: [
              // Mapa con marcadores y rutas
              GoogleMap(
                markers: provider.markers,
                polylines: provider.polylines,
                initialCameraPosition: CameraPosition(
                  target: provider.miUbicacion ?? LatLng(0, 0),
                  zoom: 15,
                ),
              ),

              // Información del pasajero
              Positioned(
                top: 50,
                left: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          provider.getNombrePasajero(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (provider.getTelefonoPasajero() != null)
                          Text(provider.getTelefonoPasajero()!),
                      ],
                    ),
                  ),
                ),
              ),

              // Botón de acción
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: ElevatedButton(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          final success = await provider.cambiarEstado(
                            proximaAccion['proximoEstado'],
                          );
                          
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Estado actualizado'),
                              ),
                            );
                          }
                        },
                  child: provider.isLoading
                      ? CircularProgressIndicator()
                      : Text(proximaAccion['texto'] ?? 'ACCIÓN'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

### 4. **HistorialServiciosProvider**
**Ubicación**: `lib/features/conductor/providers/historial_servicios_provider.dart`

**Responsabilidades**:
- ✅ Carga del historial de servicios
- ✅ Aplicación de filtros (todos, completados, cancelados)
- ✅ Carga de estadísticas del conductor

**Uso básico**:
```dart
class HistorialServiciosScreen extends StatefulWidget {
  @override
  State<HistorialServiciosScreen> createState() => 
      _HistorialServiciosScreenState();
}

class _HistorialServiciosScreenState extends State<HistorialServiciosScreen> {
  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final conductorId = authProvider.user?.id;
    
    if (conductorId != null) {
      final provider = context.read<HistorialServiciosProvider>();
      provider.cargarHistorial(conductorId: conductorId);
      provider.cargarEstadisticas(conductorId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HistorialServiciosProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Historial de Servicios'),
            actions: [
              // Filtros
              PopupMenuButton<String>(
                onSelected: (filtro) {
                  final authProvider = context.read<AuthProvider>();
                  provider.cambiarFiltro(filtro);
                  provider.cargarHistorial(
                    conductorId: authProvider.user!.id,
                    filtro: filtro,
                  );
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'todos', child: Text('Todos')),
                  PopupMenuItem(value: 'completados', child: Text('Completados')),
                  PopupMenuItem(value: 'cancelados', child: Text('Cancelados')),
                ],
              ),
            ],
          ),
          body: provider.isLoading
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: provider.servicios.length,
                  itemBuilder: (context, index) {
                    final servicio = provider.servicios[index];
                    return ListTile(
                      title: Text('Servicio #${servicio.id}'),
                      subtitle: Text(servicio.estado),
                      trailing: Text('\$${servicio.precio}'),
                    );
                  },
                ),
        );
      },
    );
  }
}
```

---

### 5. **PasajeroHomeProvider**
**Ubicación**: `lib/features/rides/providers/pasajero_home_provider.dart`

**Responsabilidades**:
- ✅ Gestión de ubicación del pasajero
- ✅ Búsqueda de direcciones (origen y destino)
- ✅ Cálculo de rutas y precios
- ✅ Gestión de marcadores en el mapa

---

## 🔄 Patrón de Refactorización

### Antes (❌ Lógica en la vista)
```dart
class MiScreen extends StatefulWidget {
  @override
  State<MiScreen> createState() => _MiScreenState();
}

class _MiScreenState extends State<MiScreen> {
  List<Dato> _datos = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final datos = await MiServicio().obtenerDatos();
      setState(() {
        _datos = datos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: _datos.length,
      itemBuilder: (context, index) {
        return ListTile(title: Text(_datos[index].titulo));
      },
    );
  }
}
```

### Después (✅ Lógica en Provider)

**1. Crear el Provider**:
```dart
// lib/features/mi_feature/providers/mi_provider.dart
class MiProvider extends ChangeNotifier {
  final MiServicio _servicio = MiServicio();

  List<Dato> _datos = [];
  bool _isLoading = false;
  String? _error;

  List<Dato> get datos => _datos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> cargarDatos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _datos = await _servicio.obtenerDatos();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

**2. Registrar en main.dart**:
```dart
MultiProvider(
  providers: [
    // ... otros providers
    ChangeNotifierProvider(
      create: (_) => MiProvider(),
      lazy: true,
    ),
  ],
  child: MyApp(),
)
```

**3. Usar en la vista**:
```dart
class MiScreen extends StatefulWidget {
  @override
  State<MiScreen> createState() => _MiScreenState();
}

class _MiScreenState extends State<MiScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar datos al inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MiProvider>().cargarDatos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MiProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(child: Text('Error: ${provider.error}'));
        }

        return ListView.builder(
          itemCount: provider.datos.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(provider.datos[index].titulo),
            );
          },
        );
      },
    );
  }
}
```

---

## 🎨 Mejores Prácticas

### 1. **Usar `Consumer` vs `context.watch`**

```dart
// ✅ Bueno: Solo reconstruye el Consumer
Consumer<MiProvider>(
  builder: (context, provider, child) {
    return Text(provider.dato);
  },
)

// ⚠️ Reconstruye todo el widget
class MiWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MiProvider>();
    return Text(provider.dato);
  }
}
```

### 2. **Usar `context.read` para acciones**

```dart
// ✅ Para ejecutar métodos sin escuchar cambios
ElevatedButton(
  onPressed: () {
    context.read<MiProvider>().ejecutarAccion();
  },
  child: Text('Acción'),
)

// ❌ No usar watch para acciones
ElevatedButton(
  onPressed: () {
    context.watch<MiProvider>().ejecutarAccion(); // ❌
  },
  child: Text('Acción'),
)
```

### 3. **Lazy Loading de Providers**

```dart
// ✅ Providers que no se necesitan inmediatamente
ChangeNotifierProvider(
  create: (_) => MiProvider(),
  lazy: true, // Solo se crea cuando se usa
)

// ⚠️ Providers globales necesarios desde el inicio
ChangeNotifierProvider(
  create: (_) => AuthProvider(),
  lazy: false, // Se crea al inicio
)
```

### 4. **Manejo de Errores**

```dart
// En el Provider
Future<void> cargarDatos() async {
  try {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _datos = await _servicio.obtenerDatos();
    
    _isLoading = false;
    notifyListeners();
  } catch (e) {
    _error = e.toString();
    _isLoading = false;
    notifyListeners();
    
    // Opcional: re-lanzar el error si necesitas manejarlo en la UI
    rethrow;
  }
}

// En la Vista
try {
  await context.read<MiProvider>().cargarDatos();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Datos cargados')),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

---

## 📝 Checklist de Refactorización

Cuando refactorices una pantalla a providers, sigue estos pasos:

- [ ] 1. Identificar toda la lógica de negocio en el widget
- [ ] 2. Crear un nuevo Provider en `lib/features/[feature]/providers/`
- [ ] 3. Mover la lógica al Provider (métodos async, setState, etc.)
- [ ] 4. Agregar getters para exponer el estado
- [ ] 5. Llamar a `notifyListeners()` después de cambiar el estado
- [ ] 6. Registrar el Provider en `main.dart`
- [ ] 7. Refactorizar el widget para usar `Consumer` o `context.watch`
- [ ] 8. Inicializar datos en `initState` usando `WidgetsBinding.instance.addPostFrameCallback`
- [ ] 9. Probar la funcionalidad
- [ ] 10. Eliminar código duplicado del widget

---

## 🚀 Próximos Pasos

1. **Refactorizar pantallas restantes**: Aplica este patrón a otras pantallas con mucha lógica
2. **Testing**: Crear tests unitarios para los providers (más fácil que testear widgets)
3. **Optimización**: Usar `Selector` para reconstruir solo partes específicas
4. **Estado complejo**: Considerar migrar a Riverpod para casos más avanzados

---

## 📚 Recursos Adicionales

- [Provider Package](https://pub.dev/packages/provider)
- [Flutter Architecture Samples](https://github.com/brianegan/flutter_architecture_samples)
- [State Management en Flutter](https://docs.flutter.dev/development/data-and-backend/state-mgmt/intro)

---

✨ **¡Listo!** Ahora tienes una arquitectura más limpia y mantenible.

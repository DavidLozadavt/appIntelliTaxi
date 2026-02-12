# 🔄 Ejemplo de Refactorización: DocumentosScreen

Este documento muestra **paso a paso** cómo refactorizar `documentos_screen.dart` para usar el `DocumentosProvider`.

---

## 📋 Estado Actual (Antes)

La pantalla `documentos_screen.dart` tiene toda esta lógica mezclada con la UI:

```dart
class _DocumentosScreenState extends State<DocumentosScreen> {
  final ConductorService _conductorService = ConductorService();
  List<DocumentoConductor> _documentos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();  // ❌ Lógica en la vista
  }

  Future<void> _cargarDocumentos() async {  // ❌ Lógica en la vista
    try {
      setState(() => _isLoading = true);
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final conductorId = authProvider.user?.id;
      
      if (conductorId == null) return;
      
      final documentos = await _conductorService.getDocumentosConductor(conductorId);
      
      setState(() {
        _documentos = documentos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcular porcentaje - ❌ Lógica en la vista
    final totalDocumentos = _documentos.length;
    final documentosVigentes = _documentos.where((doc) {
      final estado = doc.estadoVigencia?.toUpperCase() ?? 'VIGENTE';
      return estado == 'VIGENTE';
    }).length;
    final porcentaje = totalDocumentos > 0
        ? (documentosVigentes / totalDocumentos)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: Text('Mis Documentos')),
      body: _isLoading  // ❌ Estado interno
          ? Center(child: CircularProgressIndicator())
          : ListView(...),
    );
  }
}
```

### ❌ Problemas:
1. Lógica de negocio mezclada con UI
2. Difícil de testear
3. No reutilizable
4. Estado interno complejo
5. Muchos `setState()`

---

## ✅ Estado Refactorizado (Después)

### Paso 1: El Provider ya está creado

```dart
// lib/features/conductor/providers/documentos_provider.dart
class DocumentosProvider extends ChangeNotifier {
  final ConductorService _conductorService = ConductorService();

  List<DocumentoConductor> _documentos = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<DocumentoConductor> get documentos => _documentos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // ✅ Lógica centralizada
  double get porcentajeCompletitud {
    if (_documentos.isEmpty) return 0.0;
    final documentosVigentes = _documentos.where((doc) {
      final estado = doc.estadoVigencia?.toUpperCase() ?? 'VIGENTE';
      return estado == 'VIGENTE';
    }).length;
    return documentosVigentes / _documentos.length;
  }

  int get documentosVigentes {
    return _documentos.where((doc) {
      final estado = doc.estadoVigencia?.toUpperCase() ?? 'VIGENTE';
      return estado == 'VIGENTE';
    }).length;
  }

  int get totalDocumentos => _documentos.length;

  // ✅ Método de carga limpio
  Future<void> cargarDocumentos(int conductorId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final documentos = await _conductorService.getDocumentosConductor(conductorId);

      _documentos = documentos;
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

### Paso 2: Refactorizar la Vista

```dart
// lib/features/conductor/presentation/documentos_screen_refactored.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/features/conductor/providers/documentos_provider.dart';

class DocumentosScreenRefactored extends StatefulWidget {
  const DocumentosScreenRefactored({super.key});

  @override
  State<DocumentosScreenRefactored> createState() => 
      _DocumentosScreenRefactoredState();
}

class _DocumentosScreenRefactoredState extends State<DocumentosScreenRefactored> {
  @override
  void initState() {
    super.initState();
    // ✅ Cargar datos después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final conductorId = authProvider.user?.id;
      
      if (conductorId != null) {
        context.read<DocumentosProvider>().cargarDocumentos(conductorId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Documentos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // ✅ Usar el provider para recargar
              final authProvider = context.read<AuthProvider>();
              final conductorId = authProvider.user?.id;
              
              if (conductorId != null) {
                context.read<DocumentosProvider>().cargarDocumentos(conductorId);
              }
            },
          ),
        ],
      ),
      body: Consumer<DocumentosProvider>(
        builder: (context, provider, child) {
          // ✅ Manejo de estados desde el provider
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error: ${provider.error}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authProvider = context.read<AuthProvider>();
                      final conductorId = authProvider.user?.id;
                      if (conductorId != null) {
                        provider.cargarDocumentos(conductorId);
                      }
                    },
                    child: Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (provider.documentos.isEmpty) {
            return _buildEmptyState(isDark);
          }

          // ✅ Usar datos del provider
          return RefreshIndicator(
            onRefresh: () async {
              final authProvider = context.read<AuthProvider>();
              final conductorId = authProvider.user?.id;
              if (conductorId != null) {
                await provider.cargarDocumentos(conductorId);
              }
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ✅ Indicador de progreso usando getters del provider
                _buildProgressIndicator(
                  provider.porcentajeCompletitud,
                  provider.documentosVigentes,
                  provider.totalDocumentos,
                  isDark,
                ),
                const SizedBox(height: 24),
                
                // Lista de documentos
                ...provider.documentos.map((doc) {
                  return _buildDocumentoCard(doc, isDark);
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(
    double porcentaje,
    int completados,
    int total,
    bool isDark,
  ) {
    final color = porcentaje >= 1.0
        ? Colors.green
        : porcentaje >= 0.7
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Progreso de Documentación',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Indicador circular
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: porcentaje,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(porcentaje * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          '$completados/$total',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
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
  }

  Widget _buildDocumentoCard(DocumentoConductor documento, bool isDark) {
    // Implementación del card...
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(documento.nombreDocumento),
        subtitle: Text(documento.estadoVigencia ?? 'VIGENTE'),
        trailing: Icon(Icons.chevron_right),
        onTap: () {
          // Editar documento
          _mostrarEditarDocumento(documento);
        },
      ),
    );
  }

  Future<void> _mostrarEditarDocumento(DocumentoConductor documento) async {
    // Implementación...
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No tienes documentos registrados',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
```

---

## 📊 Comparación

| Aspecto | Antes (❌) | Después (✅) |
|---------|-----------|-------------|
| **Líneas de código en el widget** | ~900 líneas | ~400 líneas |
| **Lógica de negocio** | En la vista | En el provider |
| **Testeable** | Difícil | Fácil |
| **Reutilizable** | No | Sí |
| **Mantenibilidad** | Baja | Alta |
| **setState calls** | Múltiples | 0 (en la vista) |
| **Separación de responsabilidades** | No | Sí |

---

## 🎯 Beneficios Obtenidos

### 1. **Vista más limpia**
```dart
// Antes: ❌
if (_isLoading) return CircularProgressIndicator();

// Después: ✅
if (provider.isLoading) return CircularProgressIndicator();
```

### 2. **Lógica centralizada**
```dart
// Antes: ❌ Calcular en build()
final porcentaje = _documentos.where(...).length / _documentos.length;

// Después: ✅ Getter en el provider
provider.porcentajeCompletitud
```

### 3. **Facilidad de testing**
```dart
// Puedes testear el provider sin widgets
void main() {
  test('cargarDocumentos carga correctamente', () async {
    final provider = DocumentosProvider();
    await provider.cargarDocumentos(1);
    
    expect(provider.isLoading, false);
    expect(provider.documentos, isNotEmpty);
  });
}
```

### 4. **Reutilización**
```dart
// Puedes usar el mismo provider en múltiples pantallas
class OtraPantalla extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final documentosProvider = context.watch<DocumentosProvider>();
    
    return Text(
      'Documentos vigentes: ${documentosProvider.documentosVigentes}'
    );
  }
}
```

---

## 🚀 Cómo Aplicar Esta Refactorización

### Paso 1: Crear el archivo refactorizado
```bash
# Copiar el archivo original
cp documentos_screen.dart documentos_screen_refactored.dart
```

### Paso 2: Refactorizar gradualmente
1. Reemplazar `setState` con `notifyListeners` en el provider
2. Mover métodos async al provider
3. Usar `Consumer` o `context.watch` en la vista
4. Eliminar variables de estado internas

### Paso 3: Probar
```bash
flutter run
```

### Paso 4: Reemplazar el archivo original
```bash
# Una vez verificado que funciona
mv documentos_screen.dart documentos_screen_old.dart
mv documentos_screen_refactored.dart documentos_screen.dart
```

---

## 📝 Checklist de Refactorización Aplicada

- [✅] Provider creado en `lib/features/conductor/providers/documentos_provider.dart`
- [✅] Lógica de carga movida al provider
- [✅] Cálculos (porcentaje) movidos a getters
- [✅] Estado interno eliminado del widget
- [✅] `Consumer` implementado para reactividad
- [✅] Manejo de errores centralizado
- [✅] RefreshIndicator usando el provider
- [✅] Documentación actualizada

---

## 🎓 Lecciones Aprendidas

1. **Siempre usar `WidgetsBinding.instance.addPostFrameCallback`** para cargar datos en `initState`
2. **Consumer vs context.watch**: Usar Consumer para partes específicas
3. **Getters calculados**: Mejor que recalcular en `build()`
4. **Manejo de errores**: El provider debe exponer el estado de error
5. **Loading states**: Manejarlos de forma consistente

---

✨ **¡Refactorización completada!** El código ahora es más limpio, mantenible y testeable.

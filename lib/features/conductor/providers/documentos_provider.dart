import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intellitaxi/features/conductor/data/documento_conductor_model.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';

/// Provider para gestionar la lógica de documentos del conductor
/// Incluye: carga de documentos, actualización, cálculo de vigencia
class DocumentosProvider extends ChangeNotifier {
  final ConductorService _conductorService = ConductorService();
  final ImagePicker _imagePicker = ImagePicker();

  // Estado
  List<DocumentoConductor> _documentos = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<DocumentoConductor> get documentos => _documentos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Porcentaje de completitud de documentos (0.0 a 1.0)
  double get porcentajeCompletitud {
    if (_documentos.isEmpty) return 0.0;

    final documentosVigentes = _documentos.where((doc) {
      final estado = doc.estadoVigencia?.toUpperCase() ?? 'VIGENTE';
      return estado == 'VIGENTE';
    }).length;

    return documentosVigentes / _documentos.length;
  }

  /// Cantidad de documentos vigentes
  int get documentosVigentes {
    return _documentos.where((doc) {
      final estado = doc.estadoVigencia?.toUpperCase() ?? 'VIGENTE';
      return estado == 'VIGENTE';
    }).length;
  }

  /// Total de documentos
  int get totalDocumentos => _documentos.length;

  /// Verifica si hay documentos por vencer (próximos 30 días)
  bool get tieneDocumentosPorVencer {
    return _documentos.any((doc) {
      if (doc.fechaVigencia == null) return false;
      final fechaVigencia = DateTime.parse(doc.fechaVigencia!);
      final diasRestantes = fechaVigencia.difference(DateTime.now()).inDays;
      return diasRestantes > 0 && diasRestantes <= 30;
    });
  }

  /// Verifica si hay documentos vencidos
  bool get tieneDocumentosVencidos {
    return _documentos.any((doc) {
      final estado = doc.estadoVigencia?.toUpperCase() ?? 'VIGENTE';
      return estado == 'VENCIDO';
    });
  }

  /// Carga los documentos del conductor
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
      print('❌ Error cargando documentos: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selecciona una imagen desde la galería o cámara
  Future<File?> seleccionarImagen({bool desdeGaleria = true}) async {
    try {
      final XFile? imagen = await _imagePicker.pickImage(
        source: desdeGaleria ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (imagen != null) {
        return File(imagen.path);
      }
      return null;
    } catch (e) {
      print('❌ Error seleccionando imagen: $e');
      return null;
    }
  }

  /// Actualiza un documento con nueva imagen y/o fecha de vigencia
  Future<bool> actualizarDocumento({
    required int documentoId,
    required int conductorId,
    File? archivo,
    DateTime? fechaVigencia,
  }) async {
    try {
      // Convertir DateTime a String en formato yyyy-MM-dd
      String? fechaStr;
      if (fechaVigencia != null) {
        fechaStr = '${fechaVigencia.year}-${fechaVigencia.month.toString().padLeft(2, '0')}-${fechaVigencia.day.toString().padLeft(2, '0')}';
      }

      await _conductorService.actualizarDocumento(
        idDocumento: documentoId,
        filePath: archivo?.path ?? '',
        fechaVigencia: fechaStr ?? '',
      );

      // Recargar documentos después de actualizar
      await cargarDocumentos(conductorId);

      return true;
    } catch (e) {
      print('❌ Error actualizando documento: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Limpia el estado de error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

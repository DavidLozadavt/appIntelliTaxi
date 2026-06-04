import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/data/documento_conductor_model.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final ConductorService _conductorService = ConductorService();
  List<DocumentoConductor> _documentos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
  }

  Future<void> _cargarDocumentos() async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final conductorId = authProvider.user?.persona.id;

      if (conductorId == null) return;

      final documentos = await _conductorService.getDocumentosConductor(
        conductorId,
      );

      setState(() {
        _documentos = documentos;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.d(' Error cargando documentos: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar documentos: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _mostrarEditarDocumento(DocumentoConductor documento) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditarDocumentoSheet(documento: documento),
    );

    if (resultado == true) {
      _cargarDocumentos();
    }
  }

  Future<void> _abrirDocumento(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _mostrarErrorAbrirDocumento();
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened && mounted) {
      _mostrarErrorAbrirDocumento();
    }
  }

  void _mostrarErrorAbrirDocumento() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir el documento'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calcular porcentaje de documentos cargados
    final totalDocumentos = _documentos.length;
    final documentosCargados = _documentos
        .where((doc) => doc.estaCargado)
        .length;
    final porcentaje = totalDocumentos > 0
        ? (documentosCargados / totalDocumentos)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Documentos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh_copy),
            onPressed: _cargarDocumentos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _documentos.isEmpty
          ? _buildEmptyState(isDark)
          : RefreshIndicator(
              onRefresh: _cargarDocumentos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Indicador de progreso circular
                  _buildProgressIndicator(
                    porcentaje,
                    documentosCargados,
                    totalDocumentos,
                    isDark,
                  ),
                  const SizedBox(height: 24),
                  // Lista de documentos
                  ...List.generate(
                    _documentos.length,
                    (index) => _buildDocumentoCard(_documentos[index], isDark),
                  ),
                ],
              ),
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
        ? AppColors.green
        : porcentaje >= 0.7
        ? Colors.orange
        : Colors.red;

    return Card(
      elevation: 0,
      // color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Círculo de progreso
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Círculo de fondo
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 8,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  // Círculo de progreso
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: porcentaje,
                      strokeWidth: 8,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  // Porcentaje en el centro
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(porcentaje * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        '$completados/$total',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Información
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        porcentaje >= 1.0
                            ? Iconsax.shield_tick_copy
                            : porcentaje >= 0.7
                            ? Iconsax.warning_2_copy
                            : Iconsax.danger_copy,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          porcentaje >= 1.0
                              ? 'Documentos cargados'
                              : porcentaje >= 0.7
                              ? 'Revisa tus documentos'
                              : 'Actualiza urgentemente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    porcentaje >= 1.0
                        ? 'Tus documentos están cargados. Revisa las alertas si falta vigencia.'
                        : 'Tienes ${total - completados} documento(s) que necesita atención.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (porcentaje < 1.0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Iconsax.info_circle_copy,
                          size: 14,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Toca un documento para actualizarlo',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.document_copy,
            size: 80,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes documentos registrados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentoCard(DocumentoConductor documento, bool isDark) {
    final diasRestantes =
        documento.diasRestantesCalculados ?? documento.diasRestantes;
    final estadoVigencia = documento.estadoVigencia?.toUpperCase() ?? 'VIGENTE';
    final estaNoCargado = !documento.estaCargado;
    final estaSinFecha =
        documento.estaCargado &&
        documento.requiereVigencia &&
        estadoVigencia == 'SIN_FECHA_VIGENCIA';
    final estaCargadoSinVigencia =
        documento.estaCargado && !documento.requiereVigencia;
    final estadoLabel = estaNoCargado
        ? 'NO CARGADO'
        : estaCargadoSinVigencia
        ? 'CARGADO'
        : estaSinFecha
        ? 'SIN FECHA'
        : estadoVigencia;
    final vigenciaLabel = documento.requiereVigencia
        ? documento.fechaVigenciaDisplay ??
            'Sin ${documento.etiquetaFecha.toLowerCase()}'
        : documento.fechaVigenciaDisplay ??
            'No requiere vigencia';
    final mostrarMensajeAlerta =
        documento.mensajeAlerta != null && !estaCargadoSinVigencia;

    // Lógica de colores según el backend:
    // VENCIDO: dias_restantes < 0 -> ROJO
    // POR VENCER: dias_restantes <= 15 -> NARANJA
    // VIGENTE: dias_restantes > 15 -> VERDE
    Color estadoColor;
    IconData estadoIcon;
    double progreso;

    if (estaNoCargado) {
      estadoColor = Colors.grey;
      estadoIcon = Icons.upload_file_outlined;
      progreso = 0.0;
    } else if (estaCargadoSinVigencia) {
      estadoColor = AppColors.green;
      estadoIcon = Icons.check_circle;
      progreso = 1.0;
    } else if (estaSinFecha) {
      estadoColor = Colors.orange;
      estadoIcon = Icons.event_busy_outlined;
      progreso = 0.5;
    } else if (documento.requiereVigencia &&
        (estadoVigencia == 'VENCIDO' ||
            (diasRestantes != null && diasRestantes < 0))) {
      estadoColor = Colors.red;
      estadoIcon = Icons.error;
      progreso = 0.0; // Sin progreso cuando está vencido
    } else if (documento.requiereVigencia &&
        (estadoVigencia == 'POR VENCER' ||
            (diasRestantes != null && diasRestantes <= 15))) {
      estadoColor = Colors.orange;
      estadoIcon = Icons.warning_amber;
      // Progreso proporcional de 0 a 15 días
      progreso = diasRestantes != null
          ? (diasRestantes / 15).clamp(0.0, 1.0)
          : 0.5;
    } else {
      // VIGENTE (más de 15 días)
      estadoColor = AppColors.green;
      estadoIcon = Icons.check_circle;
      progreso = 1.0; // Completo cuando está vigente
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      // color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _mostrarEditarDocumento(documento),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Círculo de progreso con icono
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Círculo de fondo
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 5,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        // Círculo de progreso coloreado
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: progreso,
                            strokeWidth: 5,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              estadoColor,
                            ),
                          ),
                        ),
                        // Icono en el centro
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: estadoColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Iconsax.document_text_copy,
                            color: estadoColor,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          documento.tipoDocumento.tituloDocumento,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(estadoIcon, size: 14, color: estadoColor),
                            const SizedBox(width: 4),
                            Text(
                              estadoLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: estadoColor,
                              ),
                            ),
                          ],
                        ),
                        if (diasRestantes != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            diasRestantes > 0
                                ? '$diasRestantes días restantes'
                                : 'Vencido',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Iconsax.edit_copy, color: AppColors.accent, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Iconsax.calendar_copy,
                    size: 16,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      documento.requiereVigencia
                          ? '${documento.etiquetaFecha}: $vigenciaLabel'
                          : documento.fechaVigenciaDisplay != null
                          ? '${documento.etiquetaFecha}: ${documento.fechaVigenciaDisplay}'
                          : 'No requiere vigencia',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              if (mostrarMensajeAlerta) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: estadoColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.info_circle_copy,
                        size: 14,
                        color: estadoColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          documento.mensajeAlerta!,
                          style: TextStyle(
                            fontSize: 12,
                            color: estadoColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (documento.rutaUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _abrirDocumento(documento.rutaUrl),
                    icon: const Icon(Iconsax.eye_copy, size: 18),
                    label: const Text('Ver documento'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EditarDocumentoSheet extends StatefulWidget {
  final DocumentoConductor documento;

  const EditarDocumentoSheet({super.key, required this.documento});

  @override
  State<EditarDocumentoSheet> createState() => _EditarDocumentoSheetState();
}

class _EditarDocumentoSheetState extends State<EditarDocumentoSheet> {
  final ConductorService _conductorService = ConductorService();
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;
  DateTime? _selectedDate;
  bool _isUploading = false;

  Future<void> _abrirDocumento() async {
    final uri = Uri.tryParse(widget.documento.rutaUrl);
    if (uri == null) {
      _mostrarErrorAbrirDocumento();
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      _mostrarErrorAbrirDocumento();
    }
  }

  void _mostrarErrorAbrirDocumento() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir el documento'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.documento.fechaVigenciaDisplay != null) {
      try {
        _selectedDate = DateTime.parse(widget.documento.fechaVigenciaDisplay!);
      } catch (e) {
        AppLogger.d('Error parsing date: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedFile = File(image.path);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate != null && _selectedDate!.isAfter(now)
        ? _selectedDate!
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _actualizarDocumento() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona el archivo del documento'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (widget.documento.requiereVigencia && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha de vigencia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _conductorService.actualizarDocumento(
        idDocumento: widget.documento.id,
        idTipoDocumento: widget.documento.idTipoDocumento,
        idConductor: widget.documento.idConductor,
        filePath: _selectedFile!.path,
        fechaVigencia: _selectedDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_selectedDate!),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Iconsax.document_upload_copy,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Actualizar Documento',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.documento.tipoDocumento.tituloDocumento,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Archivo actual
                  if (widget.documento.rutaUrl.isNotEmpty) ...[
                    Text(
                      'Documento actual:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_outlined,
                              color: AppColors.accent,
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget
                                      .documento
                                      .tipoDocumento
                                      .tituloDocumento,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  !widget.documento.requiereVigencia
                                      ? (widget.documento.fechaVigenciaDisplay ==
                                              null
                                          ? 'Documento cargado'
                                          : '${widget.documento.etiquetaFecha}: ${widget.documento.fechaVigenciaDisplay}')
                                      : widget.documento.fechaVigenciaDisplay ==
                                            null
                                      ? 'Cargado sin fecha de vigencia'
                                      : '${widget.documento.etiquetaFecha}: ${widget.documento.fechaVigenciaDisplay}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Ver documento',
                            onPressed: _abrirDocumento,
                            icon: const Icon(Iconsax.eye_copy),
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Seleccionar nuevo archivo
                  Text(
                    'Nuevo documento:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: _selectedFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedFile!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.gallery_add_copy,
                                  size: 60,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Toca para seleccionar imagen',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (widget.documento.requiereVigencia) ...[
                    // Fecha de vigencia
                    Text(
                      'Fecha de vigencia:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.calendar_1_copy,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDate != null
                                  ? DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_selectedDate!)
                                  : 'Seleccionar fecha',
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedDate != null
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Iconsax.info_circle_copy,
                            color: AppColors.green,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Este documento no requiere fecha de vigencia.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Botón actualizar
                  ElevatedButton(
                    onPressed: _isUploading ? null : _actualizarDocumento,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isUploading
                        ? const AppBrandLoaderCompact(
                            ringSize: 20,
                            theme: AppLoaderTheme.dark,
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.tick_circle_copy),
                              SizedBox(width: 8),
                              Text(
                                'Actualizar Documento',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

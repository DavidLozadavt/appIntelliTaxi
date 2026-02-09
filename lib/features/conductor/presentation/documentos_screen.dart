import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/features/conductor/data/documento_conductor_model.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
      final conductorId = authProvider.user?.id;

      if (conductorId == null) return;

      final documentos = await _conductorService.getDocumentosConductor(
        conductorId,
      );

      setState(() {
        _documentos = documentos;
        _isLoading = false;
      });
    } catch (e) {
      print('⚠️ Error cargando documentos: $e');
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calcular porcentaje de completitud
    final totalDocumentos = _documentos.length;
    final documentosVigentes = _documentos.where((doc) {
      final estado = doc.estadoVigencia?.toUpperCase() ?? 'VIGENTE';
      return estado == 'VIGENTE';
    }).length;
    final porcentaje = totalDocumentos > 0
        ? (documentosVigentes / totalDocumentos)
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
          ? const Center(child: CircularProgressIndicator())
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
                    documentosVigentes,
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
                              ? 'Documentos completos'
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
                        ? 'Todos tus documentos están vigentes y al día.'
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

    Color estadoColor;
    IconData estadoIcon;

    if (estadoVigencia == 'VENCIDO') {
      estadoColor = Colors.red;
      estadoIcon = Icons.error;
    } else if (estadoVigencia == 'POR VENCER') {
      estadoColor = Colors.orange;
      estadoIcon = Icons.warning_amber;
    } else {
      estadoColor = Colors.green;
      estadoIcon = Icons.check_circle;
    }

    // Calcular progreso basado en días restantes (asumiendo 365 días máximo)
    final maxDias = 365;
    final progreso = diasRestantes != null
        ? (diasRestantes / maxDias).clamp(0.0, 1.0)
        : (estadoVigencia == 'VIGENTE' ? 1.0 : 0.0);

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
                            strokeWidth: 4,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        // Círculo de progreso
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: progreso,
                            strokeWidth: 4,
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
                            color: estadoColor.withOpacity(0.15),
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
                              estadoVigencia,
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
                      'Vigencia: ${documento.fechaVigencia ?? 'No especificada'}',
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
              if (documento.mensajeAlerta != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: estadoColor.withOpacity(0.3),
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

  @override
  void initState() {
    super.initState();
    if (widget.documento.fechaVigencia != null) {
      try {
        _selectedDate = DateTime.parse(widget.documento.fechaVigencia!);
      } catch (e) {
        print('Error parsing date: $e');
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
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
    if (_selectedFile == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un archivo y una fecha de vigencia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _conductorService.actualizarDocumento(
        idDocumento: widget.documento.id,
        filePath: _selectedFile!.path,
        fechaVigencia: DateFormat('yyyy-MM-dd').format(_selectedDate!),
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
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
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
                              color: Colors.white.withOpacity(0.9),
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
                      ),
                      child: Image.network(
                        widget.documento.rutaUrl,
                        height: 150,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Iconsax.document_copy, size: 100),
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
                          color: AppColors.accent.withOpacity(0.5),
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
                          color: AppColors.accent.withOpacity(0.3),
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
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intellitaxi/features/conductor/data/documento_vehiculo_model.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:intellitaxi/features/conductor/presentation/propietarios_vehiculo_screen.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class MisVehiculosScreen extends StatefulWidget {
  const MisVehiculosScreen({super.key});

  @override
  State<MisVehiculosScreen> createState() => _MisVehiculosScreenState();
}

class _MisVehiculosScreenState extends State<MisVehiculosScreen> {
  final ConductorService _service = ConductorService();
  bool _isLoading = true;
  String? _error;
  final Set<int> _expandedVehiculos = <int>{};

  List<VehiculoConductor> _vehiculos = [];
  final Map<int, List<DocumentoVehiculo>> _docsByVehiculo = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final vehiculos = await _service.getVehiculosConductor();
      final Map<int, List<DocumentoVehiculo>> docsMap = {};

      for (final v in vehiculos) {
        try {
          docsMap[v.id] = await _service.getDocumentosVehiculo(v.id);
        } catch (_) {
          docsMap[v.id] = [];
        }
      }

      if (!mounted) return;
      setState(() {
        _vehiculos = vehiculos;
        _docsByVehiculo
          ..clear()
          ..addAll(docsMap);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _estaBloqueado(VehiculoConductor vehiculo) {
    final docs = _docsByVehiculo[vehiculo.id] ?? const <DocumentoVehiculo>[];
    return docs.any((d) => d.estaVencido) ||
        !vehiculo.puedeOperarPorVinculacion;
  }

  Future<void> _editarDocumentoVehiculo(DocumentoVehiculo doc) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditarDocumentoVehiculoSheet(documento: doc),
    );
    if (ok == true) {
      await _cargar();
    }
  }

  void _verPropietarios(VehiculoConductor vehiculo) {
    final idAfiliacion = vehiculo.asignacionPrincipal?.idAfiliacion;
    if (idAfiliacion == null || idAfiliacion == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este vehículo no tiene afiliación registrada'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropietariosVehiculoScreen(vehiculo: vehiculo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Vehículos'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _vehiculos.isEmpty
          ? const Center(child: Text('No tienes vehículos asignados'))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildResumenGlobal(),
                  const SizedBox(height: 12),
                  ..._vehiculos.map(_buildVehiculoCard),
                ],
              ),
            ),
    );
  }

  Widget _buildResumenGlobal() {
    final bloqueados = _vehiculos.where(_estaBloqueado).length;
    if (bloqueados == 0) {
      return Card(
        color: AppColors.green.withValues(alpha: 0.12),
        child: const ListTile(
          leading: Icon(Icons.verified, color: AppColors.green),
          title: Text('Todos tus vehículos están habilitados'),
        ),
      );
    }
    return Card(
      color: Colors.red.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Icon(Icons.block, color: Colors.red),
        title: Text('$bloqueados vehículo(s) bloqueado(s)'),
        subtitle: const Text(
          'Si un vehículo tiene documentos vencidos o vinculación no activa no puede operar',
        ),
      ),
    );
  }

  Widget _buildVehiculoCard(VehiculoConductor vehiculo) {
    final docs = _docsByVehiculo[vehiculo.id] ?? const <DocumentoVehiculo>[];
    final bloqueado = _estaBloqueado(vehiculo);
    final vinculacionActiva = vehiculo.puedeOperarPorVinculacion;
    final expanded = _expandedVehiculos.contains(vehiculo.id);
    final isPrincipal =
        _vehiculos.isNotEmpty && _vehiculos.first.id == vehiculo.id;
    final titulo = [
      vehiculo.marca?.marca ?? '',
      vehiculo.modelo?.modelo ?? '',
    ].where((e) => e.trim().isNotEmpty).join(' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bloqueado
              ? Colors.red.withValues(alpha: 0.35)
              : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            if (expanded) {
              _expandedVehiculos.remove(vehiculo.id);
            } else {
              _expandedVehiculos.add(vehiculo.id);
            }
          });
        },
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Container(
                height: 218,
                color: Colors.grey.shade200,
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child:
                            vehiculo.rutaUrl != null &&
                                vehiculo.rutaUrl!.isNotEmpty
                            ? Image.network(
                                vehiculo.rutaUrl!,
                                fit: BoxFit.contain,
                                width: 230,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.directions_car, size: 84),
                              )
                            : const Icon(Icons.directions_car, size: 84),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).cardColor.withValues(alpha: 0.94),
                        border: Border(
                          top: BorderSide(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _verPropietarios(vehiculo),
                              icon: const Icon(Icons.person_outline, size: 17),
                              label: const Text('Propietarios'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: bloqueado ? Colors.red : AppColors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  bloqueado ? 'BLOQUEADO' : 'ACTIVO',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPrincipal ? 'VEHÍCULO PRINCIPAL' : 'VEHÍCULO ASIGNADO',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    titulo.isEmpty ? vehiculo.nombreCompleto : titulo,
                    style: const TextStyle(
                      fontSize: 32 / 1.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: Colors.grey.shade300, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildMetaItem('PLACA', vehiculo.placa)),
                      Expanded(
                        child: _buildMetaItem(
                          'COMBUSTIBLE',
                          (vehiculo.tipoCombustible ?? '').trim().isEmpty
                              ? 'No definido'
                              : vehiculo.tipoCombustible!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildVinculacionInfo(vehiculo, vinculacionActiva),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Documentos (${docs.length})',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade700,
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 8),
                    if (docs.isEmpty)
                      const ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.description_outlined),
                        title: Text(
                          'Sin documentos registrados para este vehículo',
                        ),
                      )
                    else
                      ...docs.map(_buildDocTile),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28 / 1.6,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildVinculacionInfo(
    VehiculoConductor vehiculo,
    bool vinculacionActiva,
  ) {
    final color = vinculacionActiva ? AppColors.green : Colors.orange;
    final observacion = vehiculo.observacionVinculacion;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            vinculacionActiva
                ? Icons.verified_user_outlined
                : Icons.warning_amber_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vinculación: ${vehiculo.estadoVinculacion}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (observacion != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    observacion,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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

  Widget _buildDocTile(DocumentoVehiculo doc) {
    final vencido = doc.estaVencido;
    final porVencer = doc.estaPorVencer;
    final color = vencido
        ? Colors.red
        : porVencer
        ? Colors.orange
        : AppColors.green;

    String estado = 'Vigente';
    if (vencido) estado = 'Vencido';
    if (porVencer) estado = 'Por vencer';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.badge_outlined, color: color),
      title: Text(doc.tituloDocumento),
      subtitle: Text('Vigencia: ${doc.fechaVigencia ?? 'No definida'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            estado,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Editar documento',
            onPressed: () => _editarDocumentoVehiculo(doc),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _EditarDocumentoVehiculoSheet extends StatefulWidget {
  final DocumentoVehiculo documento;

  const _EditarDocumentoVehiculoSheet({required this.documento});

  @override
  State<_EditarDocumentoVehiculoSheet> createState() =>
      _EditarDocumentoVehiculoSheetState();
}

class _EditarDocumentoVehiculoSheetState
    extends State<_EditarDocumentoVehiculoSheet> {
  final ConductorService _service = ConductorService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _fechaController = TextEditingController();
  File? _archivo;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _fechaController.text = widget.documento.fechaVigenciaDisplay ?? '';
  }

  @override
  void dispose() {
    _fechaController.dispose();
    super.dispose();
  }

  Future<void> _pickArchivo() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) return;
    setState(() => _archivo = File(file.path));
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final current =
        DateTime.tryParse(_fechaController.text) ??
        now.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondary: AppColors.secondary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    _fechaController.text = DateFormat('yyyy-MM-dd').format(picked);
    setState(() {});
  }

  Future<void> _guardar() async {
    if (_archivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el archivo del documento')),
      );
      return;
    }
    if (_fechaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de vigencia')),
      );
      return;
    }

    try {
      setState(() => _guardando = true);
      await _service.actualizarDocumentoVehiculo(
        idDocumento: widget.documento.id,
        filePath: _archivo!.path,
        fechaVigencia: _fechaController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento actualizado correctamente'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkCard : Colors.white;
    final mutedSurface = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Actualizar documento',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.documento.tituloDocumento,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
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
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Documento actual',
                    style: TextStyle(
                      color: secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: mutedSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: AppColors.primary,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.documento.tituloDocumento,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: primaryText,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Vigencia: ${widget.documento.fechaVigenciaDisplay ?? 'No definida'}',
                                style: TextStyle(color: secondaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Nuevo archivo',
                    style: TextStyle(
                      color: secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _guardando ? null : _pickArchivo,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 176,
                      decoration: BoxDecoration(
                        color: mutedSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: _archivo == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: AppColors.primary,
                                  size: 44,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Seleccionar archivo',
                                  style: TextStyle(
                                    color: primaryText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Toca para cargar una nueva imagen',
                                  style: TextStyle(color: secondaryText),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_archivo!, fit: BoxFit.contain),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Fecha de vigencia',
                    style: TextStyle(
                      color: secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _fechaController,
                    readOnly: true,
                    onTap: _guardando ? null : _pickFecha,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: mutedSurface,
                      prefixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.primary,
                      ),
                      suffixIcon: const Icon(Icons.keyboard_arrow_down),
                      hintText: 'Seleccionar fecha',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.45,
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _guardando ? 'Guardando...' : 'Guardar cambios',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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

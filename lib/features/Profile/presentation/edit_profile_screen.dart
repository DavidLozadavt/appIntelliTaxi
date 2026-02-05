import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/data/auth_model.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  final Persona persona;
  final User user;

  const EditProfileScreen({
    super.key,
    required this.persona,
    required this.user,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _identificacionController = TextEditingController();
  final _emailController = TextEditingController();
  final _celularController = TextEditingController();
  final _direccionController = TextEditingController();

  DateTime? _selectedDate;
  String _selectedSexo = 'M';
  int _selectedTipoId = 1;
  File? _selectedImage;
  bool _isLoading = false;
  String? _currentPhotoUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    _nombreController.text = widget.persona.nombre1;
    _apellidoController.text = widget.persona.apellido1;
    _emailController.text = widget.user.email;
    _celularController.text = widget.persona.celular ?? '';
    _direccionController.text = widget.persona.direccion ?? '';
    _currentPhotoUrl = widget.persona.rutaFotoUrl;

    // Cargar identificación
    _identificacionController.text = widget.persona.identificacion ?? '';

    // Cargar tipo de identificación
    _selectedTipoId = widget.persona.idTipoIdentificacion ?? 1;

    // Cargar sexo
    _selectedSexo = widget.persona.sexo ?? 'M';

    // Cargar fecha de nacimiento
    if (widget.persona.fechaNac != null &&
        widget.persona.fechaNac!.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(widget.persona.fechaNac!);
      } catch (e) {
        _selectedDate = null;
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _identificacionController.dispose();
    _emailController.dispose();
    _celularController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Iconsax.camera_copy),
              title: const Text('Tomar Foto'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 85,
                );
                if (image != null) {
                  setState(() {
                    _selectedImage = File(image.path);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery_copy),
              title: const Text('Elegir de Galería'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 85,
                );
                if (image != null) {
                  setState(() {
                    _selectedImage = File(image.path);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona tu fecha de nacimiento'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final success = await authProvider.updateProfile(
        personaId: widget.persona.id,
        identificacion: _identificacionController.text.trim(),
        nombre1: _nombreController.text.trim(),
        apellido1: _apellidoController.text.trim(),
        fechaNac: _formatDate(_selectedDate!),
        direccion: _direccionController.text.trim(),
        email: _emailController.text.trim(),
        celular: _celularController.text.trim(),
        sexo: _selectedSexo,
        idTipoIdentificacion: _selectedTipoId,
        fotoPath: _selectedImage?.path,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil actualizado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Retornar true para indicar actualización exitosa
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [AppColors.darkBackground, AppColors.darkSurface]
                    : [Colors.white, Colors.grey.shade50],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Iconsax.arrow_left_copy),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Editar Perfil',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Photo selector
                          Center(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.accent,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.accent.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: _selectedImage != null
                                        ? ClipOval(
                                            child: Image.file(
                                              _selectedImage!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : _currentPhotoUrl != null
                                        ? ClipOval(
                                            child: Image.network(
                                              _currentPhotoUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Icon(
                                                    Iconsax.user_copy,
                                                    size: 40,
                                                    color: Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Icon(
                                            Iconsax.user_copy,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.darkSurface
                                              : Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: const Icon(
                                        Iconsax.camera_copy,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Toca para cambiar foto',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Nombre
                          _buildTextField(
                            controller: _nombreController,
                            label: 'Nombre',
                            icon: Iconsax.user_copy,
                            validator: (value) =>
                                value!.isEmpty ? 'Ingrese su nombre' : null,
                          ),

                          const SizedBox(height: 16),

                          // Apellido
                          _buildTextField(
                            controller: _apellidoController,
                            label: 'Apellido',
                            icon: Iconsax.user_copy,
                            validator: (value) =>
                                value!.isEmpty ? 'Ingrese su apellido' : null,
                          ),

                          const SizedBox(height: 16),

                          // Tipo de identificación y número
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildDropdown(
                                  value: _selectedTipoId,
                                  items: const [
                                    {'value': 1, 'label': 'CC'},
                                    {'value': 2, 'label': 'TI'},
                                    {'value': 3, 'label': 'PAS'},
                                    {'value': 4, 'label': 'CE'},
                                    {'value': 5, 'label': 'NIT'},
                                    {'value': 6, 'label': 'RC'},
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTipoId = value!;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 4,
                                child: _buildTextField(
                                  controller: _identificacionController,
                                  label: 'Identificación',
                                  icon: Iconsax.card_copy,
                                  keyboardType: TextInputType.number,
                                  validator: (value) => value!.isEmpty
                                      ? 'Ingrese su identificación'
                                      : null,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Fecha de nacimiento
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: _buildDateField(),
                          ),

                          const SizedBox(height: 16),

                          // Sexo
                          _buildSexoSelector(),

                          const SizedBox(height: 16),

                          // Email
                          _buildTextField(
                            controller: _emailController,
                            label: 'Correo Electrónico',
                            icon: Iconsax.sms_copy,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value!.isEmpty) return 'Ingrese su email';
                              if (!value.contains('@')) return 'Email inválido';
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Celular
                          _buildTextField(
                            controller: _celularController,
                            label: 'Celular',
                            icon: Iconsax.mobile_copy,
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                                value!.isEmpty ? 'Ingrese su celular' : null,
                          ),

                          const SizedBox(height: 16),

                          // Dirección
                          _buildTextField(
                            controller: _direccionController,
                            label: 'Dirección',
                            icon: Iconsax.location_copy,
                            validator: (value) =>
                                value!.isEmpty ? 'Ingrese su dirección' : null,
                          ),

                          const SizedBox(height: 32),

                          // Update button
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                shadowColor: AppColors.accent.withOpacity(0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Iconsax.tick_circle_copy,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Guardar Cambios',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.accent),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark ? AppColors.darkCard : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDateField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.calendar_copy, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDate == null
                    ? 'Fecha de Nacimiento'
                    : _formatDate(_selectedDate!),
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedDate == null
                      ? (isDark ? Colors.white60 : Colors.black45)
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            Icon(
              Iconsax.arrow_down_1_copy,
              color: isDark ? Colors.white60 : Colors.black45,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required int value,
    required List<Map<String, dynamic>> items,
    required void Function(int?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<int>(
        value: value,
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark ? AppColors.darkCard : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        dropdownColor: isDark ? AppColors.darkCard : Colors.white,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        icon: Icon(
          Iconsax.arrow_down_1_copy,
          color: isDark ? Colors.white60 : Colors.black45,
        ),
        isExpanded: true,
        items: items.map((item) {
          return DropdownMenuItem<int>(
            value: item['value'] as int,
            child: Text(
              item['label'] as String,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSexoSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSexoOption('M', 'Masculino', Iconsax.man_copy),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSexoOption('F', 'Femenino', Iconsax.woman_copy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSexoOption(String value, String label, IconData icon) {
    final isSelected = _selectedSexo == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSexo = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

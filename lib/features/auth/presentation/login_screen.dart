import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:intellitaxi/features/app_update/services/app_update_service.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  String _presentableError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '').trim();
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        final deviceToken = await FirebaseMessaging.instance.getToken();

        final success = await authProvider.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          deviceToken ?? "",
          rememberMe: _rememberMe,
        );

        if (!mounted) return;
        if (success) {
          final updateResult = await AppUpdateService.instance.checkForUpdate();
          if (!mounted || updateResult.shouldBlock) return;
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_presentableError(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadSavedCredentials() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final creds = await authProvider.getSavedCredentials();
    if (!mounted) return;
    if (creds != null) {
      setState(() {
        _emailController.text = creds['email'] ?? '';
        _passwordController.text = creds['password'] ?? '';
        _rememberMe = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.18);
    final inputFillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.02);

    InputDecoration buildInputDecoration({
      required String label,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandWine, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  ColorFiltered(
                    colorFilter: isDark
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.srcOver,
                          )
                        : const ColorFilter.mode(
                            AppColors.brandWine,
                            BlendMode.modulate,
                          ),
                    child: Image.asset(
                      'assets/images/logoTaxbel.webp',
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '¡Bienvenido!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Inicia sesión para continuar',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: buildInputDecoration(
                      label: 'Usuario',
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Ingrese su usuario' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    decoration: buildInputDecoration(
                      label: 'Contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) =>
                        value!.isEmpty ? 'Ingrese su contraseña' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value!;
                              });
                            },
                          ),
                          const Text('Recuérdame'),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(fontSize: 13),
                              maxLines: 2,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandWine,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: authProvider.isLoading
                          ? const AppLoadingIndicator(
                              size: 22,
                              strokeWidth: 2.4,
                              color: Colors.white,
                            )
                          : const Text(
                              'Ingresar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('¿Aún no tienes una cuenta? '),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text('Crear cuenta'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

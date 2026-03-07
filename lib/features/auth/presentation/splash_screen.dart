import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _typewriterController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  String _displayedText = "";
  final String _fullText = "Bienvenido a IntelliTaxi";
  Timer? _typewriterStartTimer;
  Timer? _typewriterTimer;
  Timer? _navigationWatchdogTimer;
  int _currentTypewriterIndex = 0;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Animación principal del logo
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Animación de brillo pulsante
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.7, end: 0.9).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Animación de texto escribiéndose
    _typewriterController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _controller.forward();

    // Iniciar animación de texto después del logo
    _typewriterStartTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _startTypewriter();
    });

    // Evita quedarse bloqueado en splash si falla cualquier async de inicio.
    _navigationWatchdogTimer = Timer(const Duration(seconds: 8), () {
      _navigateToLogin();
    });

    _checkLogin();
  }

  void _startTypewriter() {
    if (!mounted) return;

    if (!_typewriterController.isAnimating &&
        _typewriterController.status == AnimationStatus.dismissed) {
      _typewriterController.forward();
    }

    _typewriterTimer?.cancel();
    _currentTypewriterIndex = 0;
    _displayedText = "";

    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted || _currentTypewriterIndex >= _fullText.length) {
        timer.cancel();
        return;
      }

      setState(() {
        _displayedText += _fullText[_currentTypewriterIndex];
      });
      _currentTypewriterIndex++;
    });
  }

  Future<void> _checkLogin() async {
    final sw = Stopwatch()..start();
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getSavedToken().timeout(
        const Duration(seconds: 3),
      );
      debugPrint('⏱️ [Splash] token en ${sw.elapsedMilliseconds}ms');

      await Future.delayed(const Duration(seconds: 4));
      if (!mounted || _hasNavigated) return;

      if (token != null) {
        await authProvider.loadUserFromStorage().timeout(
          const Duration(seconds: 3),
        );
        debugPrint(
          '✅ [Splash] user cargado en ${sw.elapsedMilliseconds}ms, yendo home',
        );
        _navigateToHome();
      } else {
        debugPrint('ℹ️ [Splash] sin token en ${sw.elapsedMilliseconds}ms');
        _navigateToLogin();
      }
    } catch (_) {
      debugPrint('⚠️ [Splash] fallback login en ${sw.elapsedMilliseconds}ms');
      _navigateToLogin();
    } finally {
      sw.stop();
    }
  }

  void _navigateToHome() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _navigationWatchdogTimer?.cancel();
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _navigateToLogin() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _navigationWatchdogTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _typewriterStartTimer?.cancel();
    _typewriterTimer?.cancel();
    _navigationWatchdogTimer?.cancel();
    _controller.dispose();
    _typewriterController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Widget _buildSplashContent(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo con efectos épicos
        FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandWine.withValues(
                          alpha: _glowAnimation.value * 0.2,
                        ),
                        blurRadius: 20 * _glowAnimation.value,
                        spreadRadius: 8 * _glowAnimation.value,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logoTaxbel.webp',
                    height: size.height * 0.25,
                    color: isDark ? null : AppColors.brandWine,
                    colorBlendMode: isDark ? null : BlendMode.modulate,
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Texto escribiéndose con efectos
        AnimatedBuilder(
          animation: _typewriterController,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: const [
                  AppColors.brandWineLight,
                  AppColors.brandWine,
                  AppColors.brandWineDark,
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Column(
                children: [
                  Text(
                    _displayedText,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: AppColors.brandWine.withValues(alpha: 0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Cursor parpadeante
                  if (_displayedText.length < _fullText.length)
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _glowAnimation.value,
                          child: Container(
                            width: 3,
                            height: 35,
                            color: Colors.orange,
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 50),

        // Progress bar animado
        FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            width: size.width * 0.6,
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black12,
                  ),
                ),
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange,
                            Colors.deepOrange,
                            Colors.orange,
                          ],
                          stops: [0.0, _glowAnimation.value, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.transparent,
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 30),

        // Texto adicional con fade
        FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            "Cargando experiencia...",
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Center(child: _buildSplashContent(context))),
    );
  }
}

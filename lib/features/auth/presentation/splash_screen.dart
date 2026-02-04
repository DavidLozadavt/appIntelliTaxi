import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:provider/provider.dart';
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
    Future.delayed(const Duration(milliseconds: 800), () {
      _startTypewriter();
    });

    _checkLogin();
  }

  void _startTypewriter() {
    _typewriterController.forward();
    int currentIndex = 0;

    void typeNextChar() {
      if (currentIndex < _fullText.length && mounted) {
        setState(() {
          _displayedText += _fullText[currentIndex];
        });
        currentIndex++;
        Future.delayed(const Duration(milliseconds: 100), typeNextChar);
      }
    }

    typeNextChar();
  }

  Future<void> _checkLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getSavedToken();
    await Future.delayed(const Duration(seconds: 4));
    if (token != null) {
      await authProvider.loadUserFromStorage();
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _typewriterController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Widget _buildSplashContent(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
                        color: Colors.orange.withOpacity(
                          _glowAnimation.value * 0.2,
                        ),
                        blurRadius: 20 * _glowAnimation.value,
                        spreadRadius: 8 * _glowAnimation.value,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/erp_logo.png',
                    height: size.height * 0.25,
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
                  Colors.orange,
                  Colors.deepOrange,
                  Colors.orangeAccent,
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
                          color: Colors.orange.withOpacity(0.2),
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
                            color: Colors.orange.withOpacity(0.3),
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

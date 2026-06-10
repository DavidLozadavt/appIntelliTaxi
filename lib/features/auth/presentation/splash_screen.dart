import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/optimized_text_styles.dart';
import 'package:intellitaxi/core/bootstrap/session_preload.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_pending_fcm.dart';
import 'package:intellitaxi/main.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/app_update/services/app_update_service.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/auth/services/auth_service.dart';
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
  final String _fullText = "Bienvenido a TaxbelUrbano";
  Timer? _typewriterStartTimer;
  Timer? _typewriterTimer;
  Timer? _navigationWatchdogTimer;
  int _currentTypewriterIndex = 0;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.7, end: 0.9).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _typewriterController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _controller.forward();

    _typewriterStartTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _startTypewriter();
    });

    _navigationWatchdogTimer = Timer(const Duration(seconds: 12), () {
      unawaited(_navigationWatchdogFallback());
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
      await ConductorPendingFcm.ensureLoaded();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final minBrand = Future<void>.delayed(
        ConductorPendingFcm.hasPending
            ? const Duration(milliseconds: 120)
            : RuntimePerfFlags.splashMinDisplay,
      );
      final sessionFuture = SessionPreload.ensureReady();

      AppUpdateCheckResult updateResult = const AppUpdateCheckResult(
        updateAvailable: false,
        shouldBlock: false,
      );
      try {
        updateResult = await AppUpdateService.instance
            .checkForUpdate()
            .timeout(RuntimePerfFlags.splashUpdateCheckTimeout);
      } on TimeoutException {
        if (kDebugMode) {
          debugPrint('⏱️ [Splash] update check timeout → home sin bloquear');
        }
      }

      if (!mounted || _hasNavigated) return;
      if (updateResult.shouldBlock) {
        _navigationWatchdogTimer?.cancel();
        return;
      }

      final snapshot = await sessionFuture;
      await minBrand;

      if (!mounted || _hasNavigated) return;

      if (snapshot.canOpenHome) {
        await authProvider.hydrateFromSnapshot(snapshot);
        try {
          await AuthService.instance
              .ensureValidSession()
              .timeout(const Duration(seconds: 12));
        } on TimeoutException {
          if (kDebugMode) {
            debugPrint('⏱️ [Splash] refresh proactivo timeout');
          }
        }
        final updated = await AuthService.instance.getSavedUserData();
        if (updated != null) {
          authProvider.applyRefreshedSession(updated);
        }
        if (kDebugMode) {
          debugPrint(
            '🚀 [Splash] home en ${sw.elapsedMilliseconds}ms (sesión precargada)',
          );
        }
        _navigateToHome();
        return;
      }

      if (snapshot.hasToken && !snapshot.hasUser) {
        await authProvider.loadUserFromStorage().timeout(
          const Duration(seconds: 3),
        );
        if (authProvider.user != null) {
          if (kDebugMode) {
            debugPrint('🚀 [Splash] home en ${sw.elapsedMilliseconds}ms');
          }
          _navigateToHome();
          return;
        }
      }

      if (kDebugMode) {
        debugPrint('ℹ️ [Splash] login en ${sw.elapsedMilliseconds}ms');
      }
      _navigateToLogin();
    } catch (_) {
      if (kDebugMode) {
        debugPrint('⚠️ [Splash] fallback login en ${sw.elapsedMilliseconds}ms');
      }
      _navigateToLogin();
    } finally {
      sw.stop();
    }
  }

  Future<void> _navigationWatchdogFallback() async {
    if (!mounted || _hasNavigated) return;
    try {
      final snapshot = await SessionPreload.ensureReady().timeout(
        const Duration(seconds: 3),
      );
      if (!mounted || _hasNavigated) return;
      if (snapshot.canOpenHome) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.hydrateFromSnapshot(snapshot);
        if (!mounted || _hasNavigated) return;
        _navigateToHome();
        return;
      }
    } catch (_) {
      // Continuar al login.
    }
    if (!mounted || _hasNavigated) return;
    _navigateToLogin();
  }

  void _navigateToHome() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _navigationWatchdogTimer?.cancel();
    Navigator.pushReplacementNamed(context, '/home').then((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        unawaited(ConductorPendingFcm.flush(ctx));
      }
    });
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
                    style: OptimizedTextStyles.poppins(
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
                  if (_displayedText.length < _fullText.length)
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _glowAnimation.value,
                          child: Container(
                            width: 3,
                            height: 35,
                            color: AppColors.brandWine,
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
                            AppColors.brandWineLight,
                            AppColors.brandWine,
                            AppColors.brandWineDark,
                          ],
                          stops: [0.0, _glowAnimation.value, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandWine.withValues(alpha: 0.3),
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
        FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            "Cargando experiencia...",
            style: OptimizedTextStyles.poppins(
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

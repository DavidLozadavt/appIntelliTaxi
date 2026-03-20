import 'dart:async';
import 'dart:ui';
import 'package:intellitaxi/core/services/connectivity_provider.dart';
import 'package:intellitaxi/core/theme/theme_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/core/theme/optimized_text_styles.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/performance_monitor_service.dart';

import 'package:intellitaxi/features/chat/providers/chat_provider.dart';
import 'package:intellitaxi/features/chat/presentation/chat_screen.dart';
import 'package:intellitaxi/features/conductor/presentation/documentos_screen.dart';
import 'package:intellitaxi/features/conductor/presentation/historial_servicios_conductor_screen.dart';
import 'package:intellitaxi/features/conductor/presentation/mis_vehiculos_screen.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/providers/documentos_provider.dart';
import 'package:intellitaxi/features/sanciones/providers/sancion_provider.dart';
import 'package:intellitaxi/features/entregas/presentation/entregas_screen.dart';
import 'package:intellitaxi/features/sanciones/presentation/sanciones_screen.dart';
// import 'package:intellitaxi/features/conductor/providers/historial_servicios_provider.dart';
import 'package:intellitaxi/features/conductor/providers/servicio_activo_provider.dart';
import 'package:intellitaxi/features/pasajero/presentation/historial_servicios_pasajero_screen.dart';
import 'package:intellitaxi/features/rides/presentation/historial_calificaciones_screen.dart';
// import 'package:intellitaxi/features/pasajero/providers/pasajero_home_provider.dart';
import 'package:intellitaxi/features/home/presentation/no_connection_screen.dart';

import 'package:intellitaxi/features/notifications/providers/notification_provider.dart';
import 'package:intellitaxi/features/notifications/presentation/notification_screen.dart';

import 'package:intellitaxi/firebase_msg.dart' show FirebaseMsg;
import 'package:intellitaxi/firebase_options.dart' show DefaultFirebaseOptions;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/home/presentation/navigation_screen.dart';
import 'features/onboarding/presentation/initial_screen.dart';
import 'config/pusher_config.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Cargar variables de entorno
      await dotenv.load(fileName: ".env");

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Optimizaciones de rendimiento
      _setupPerformanceOptimizations();
      PerformanceMonitorService.initialize();

      runApp(const MyApp());

      // Tareas no críticas: ejecutar después del primer frame para evitar jank de arranque.
      unawaited(OptimizedTextStyles.precacheAllFonts());
      unawaited(_bootstrapRuntimeServices());
    },
    (error, stackTrace) {
      if (kDebugMode) {
        AppLogger.e(
          'Uncaught zone error',
          tag: 'Main',
          error: error,
          stackTrace: stackTrace,
        );
      }
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        // En release/profile evitamos costo de logs masivos en runtime.
        if (kDebugMode) {
          parent.print(zone, line);
        }
      },
    ),
  );
}

Future<void> _bootstrapRuntimeServices() async {
  try {
    await FirebaseMsg().initFCM().timeout(const Duration(seconds: 8));
  } catch (e, st) {
    AppLogger.e(
      'No se pudo inicializar FCM en segundo plano de arranque',
      tag: 'Bootstrap',
      error: e,
      stackTrace: st,
    );
  }

  try {
    await PusherService.initialize().timeout(const Duration(seconds: 8));
  } catch (e, st) {
    AppLogger.e(
      'No se pudo inicializar Pusher en segundo plano de arranque',
      tag: 'Bootstrap',
      error: e,
      stackTrace: st,
    );
  }
}

/// Entrypoint requerido por `flutter_overlay_window`.
/// Evita el error "Could not resolve main entrypoint function" en el isolate secundario.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(),
      ),
    ),
  );
}

void _setupPerformanceOptimizations() {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 120;
  imageCache.maximumSizeBytes = 80 << 20; // 80MB

  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
    AppLogger.e(
      'FlutterError capturado',
      tag: 'Flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e(
      'Error no controlado en PlatformDispatcher',
      tag: 'Flutter',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  // Limitar la tasa de refresco si no es necesario 120Hz
  // SchedulerBinding.instance.addPostFrameCallback((_) {
  //   SchedulerBinding.instance.platformDispatcher.onReportTimings = (timings) {};
  // });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Providers globales
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // Providers lazy (se cargan cuando se necesitan)
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => ChatProvider(), lazy: true),

        // Providers del conductor
        ChangeNotifierProvider(
          create: (_) => ConductorHomeProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => DocumentosProvider(), lazy: true),
        // TODO: Descomentar cuando se creen los modelos necesarios
        // ChangeNotifierProvider(
        //   create: (_) => HistorialServiciosProvider(),
        //   lazy: true,
        // ),
        ChangeNotifierProvider(
          create: (_) => ServicioActivoProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => SancionProvider(), lazy: true),

        // Providers del pasajero
        // TODO: Descomentar cuando se implementen métodos en RoutesService
        // ChangeNotifierProvider(
        //   create: (_) => PasajeroHomeProvider(),
        //   lazy: true,
        // ),
      ],

      child: Consumer2<ConnectivityProvider, ThemeProvider>(
        builder: (context, connectivity, themeProvider, _) {
          if (!connectivity.isOnline) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('es', 'ES'),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('es', 'ES')],
              home: const NoConnectionScreen(),
            );
          }
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'ERP VT',
            locale: const Locale('es', 'ES'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('es', 'ES')],
            // Optimizaciones de performance
            showPerformanceOverlay: false,
            checkerboardRasterCacheImages: false,
            checkerboardOffscreenLayers: false,
            theme: ThemeData(
              brightness: Brightness.light,
              useMaterial3: true,
              textTheme: GoogleFonts.poppinsTextTheme(),
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                tertiary: AppColors.accent,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              textTheme: GoogleFonts.poppinsTextTheme(
                ThemeData(brightness: Brightness.dark).textTheme,
              ),
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primaryDark,
                secondary: AppColors.accent,
                tertiary: AppColors.secondary,
                surface: AppColors.darkSurface,
                error: AppColors.error,
                onPrimary: AppColors.darkOnPrimary,
                onSecondary: AppColors.darkOnSecondary,
                onSurface: AppColors.darkOnSurface,
                onError: AppColors.darkOnError,
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: const InitialScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/home': (_) => const NavigationScreen(),
              '/notifications': (_) => const NotificationScreen(),
              '/mis-documentos': (_) => const DocumentosScreen(),
              '/mis-vehiculos': (_) => const MisVehiculosScreen(),
              '/historial-conductor': (_) =>
                  const HistorialServiciosConductorScreen(),
              '/historial-pasajero': (_) =>
                  const HistorialServiciosPasajeroScreen(),
              '/calificaciones-conductor': (context) {
                final auth = context.read<AuthProvider>();
                return HistorialCalificacionesScreen(
                  idUsuario: auth.user!.id,
                  tipoCalificacion: 'CONDUCTOR',
                  nombreUsuario: auth.user!.nombreCompleto,
                );
              },
              '/calificaciones-pasajero': (context) {
                final auth = context.read<AuthProvider>();
                return HistorialCalificacionesScreen(
                  idUsuario: auth.user!.id,
                  tipoCalificacion: 'PASAJERO',
                  nombreUsuario: auth.user!.nombreCompleto,
                );
              },
              '/chat': (_) => const ChatScreen(),
              '/mis-sanciones': (_) => const SancionesScreen(),
              '/entregas': (_) => const EntregasScreen(),
              // '/vinculaciones-propietario': (_) => TransportePropietario(),
            },
          );
        },
      ),
    );
  }
}

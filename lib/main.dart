import 'package:intellitaxi/core/services/connectivity_provider.dart';
import 'package:intellitaxi/core/theme/theme_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/core/theme/optimized_text_styles.dart';

import 'package:intellitaxi/features/chat/logic/chat_provider.dart';
import 'package:intellitaxi/features/chat/presentation/chat_screen.dart';
import 'package:intellitaxi/features/home/presentation/no_connection_screen.dart';

import 'package:intellitaxi/features/notifications/logic/notification_provider.dart';
import 'package:intellitaxi/features/notifications/presentation/notification_screen.dart';

import 'package:intellitaxi/test_iconsax_screen.dart';
import 'package:intellitaxi/firebase_msg.dart' show FirebaseMsg;
import 'package:intellitaxi/firebase_options.dart' show DefaultFirebaseOptions;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/navigation_screen.dart';
import 'features/onboarding/presentation/initial_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseMsg().initFCM();

  // Optimizaciones de rendimiento
  _setupPerformanceOptimizations();

  // Pre-cachear fuentes para mejorar rendimiento inicial
  await OptimizedTextStyles.precacheAllFonts();

  runApp(const MyApp());
}

void _setupPerformanceOptimizations() {
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
          lazy: true, // Optimizado: solo se carga cuando se necesita
        ),

        ChangeNotifierProvider(create: (_) => ChatProvider(), lazy: true),

        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                tertiary: AppColors.accent,
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
              '/home': (_) => const NavigationScreen(),
              '/notifications': (_) => const NotificationScreen(),

              '/chat': (_) => const ChatScreen(),
              // '/vinculaciones-propietario': (_) => TransportePropietario(),
              '/test-iconsax': (_) => const TestIconsaxScreen(),
            },
          );
        },
      ),
    );
  }
}

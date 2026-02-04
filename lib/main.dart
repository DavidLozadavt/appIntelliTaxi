import 'package:intellitaxi/core/services/connectivity_provider.dart';
import 'package:intellitaxi/core/theme/theme_provider.dart';

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

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/navigation_screen.dart';
import 'features/onboarding/presentation/initial_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseMsg().initFCM();

  runApp(const MyApp());
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
          lazy: false,
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
            theme: ThemeData(
              brightness: Brightness.light,
              useMaterial3: true,
              textTheme: GoogleFonts.poppinsTextTheme(),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFC502),
                primary: const Color(0xFFFFC502),
                secondary: const Color(0xFFFFDC4A),
                tertiary: const Color(0xFFFF6605),
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              textTheme: GoogleFonts.poppinsTextTheme(
                ThemeData(brightness: Brightness.dark).textTheme,
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFC502),
                primary: const Color(0xFFFFC502),
                secondary: const Color(0xFFFFDC4A),
                tertiary: const Color(0xFFFF6605),
                brightness: Brightness.dark,
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

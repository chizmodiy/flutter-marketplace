import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zeno/pages/auth_page.dart';
import 'package:zeno/pages/general_page.dart';

import 'package:zeno/pages/product_detail_page.dart';
import 'package:zeno/pages/admin_login_page.dart';
import 'package:zeno/pages/admin_dashboard_page.dart';
import 'package:zeno/pages/admin_dashboard_guard.dart';
import 'pages/profile_page.dart';
import 'services/favorites_service.dart';
import 'package:zeno/pages/pin_recovery_phone_page.dart'; // Import new PIN recovery pages
import 'package:zeno/pages/pin_recovery_otp_page.dart';
import 'package:zeno/pages/pin_reset_page.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture logs early so print/debugPrint are stored for copying.
  AppLogger.install();

  // First initialize Supabase
  await Supabase.initialize(
    url: 'https://wcczieoznbopcafdatpk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjY3ppZW96bmJvcGNhZmRhdHBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzNTc2MTEsImV4cCI6MjA2NjkzMzYxMX0.1OdLDVnzHx9ghZ7D8X2P_lpZ7XvnPtdEKN4ah_guUJ0',
  );

  // Then initialize other services that depend on Supabase
  await FavoritesService().init();

  AppLogger.runWithPrintCapture(() {
    runApp(const AuthStateListener()); // Wrap MyApp with AuthStateListener
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // На вебі використовуємо поточний шлях як initialRoute, щоб працювали прямі переходи /admin
    final String initial = Uri.base.path.isEmpty ? '/' : Uri.base.path;
    return MaterialApp(
      title: 'Zeno',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor:
            Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            mouseCursor: MaterialStateProperty.all(SystemMouseCursors.click),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            mouseCursor: MaterialStateProperty.all(SystemMouseCursors.click),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            mouseCursor: MaterialStateProperty.all(SystemMouseCursors.click),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            mouseCursor: MaterialStateProperty.all(SystemMouseCursors.click),
          ),
        ),
      ),
      initialRoute: initial,
      routes: {
        '/': (context) => const GeneralPage(),
        '/auth': (context) => const AuthPage(),
        '/profile': (context) => const ProfilePage(),
        '/admin': (context) => const AdminLoginPage(),
        '/pin-recovery-phone': (context) =>
            const PinRecoveryPhonePage(), // New route
        '/pin-recovery-otp': (context) =>
            const PinRecoveryOtpPage(phoneNumber: ''), // New route
        '/pin-reset': (context) => const PinResetPage(), // New route
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/admin/dashboard') {
          return MaterialPageRoute(
            builder: (context) => const AdminDashboardGuard(),
          );
        }

        final user = Supabase.instance.client.auth.currentUser;
        final isLoggedIn = user != null;

        if (settings.name == '/auth' ||
            settings.name == '/admin' ||
            settings.name == '/pin-recovery-phone' ||
            settings.name == '/pin-recovery-otp' ||
            settings.name == '/pin-reset') {
          return MaterialPageRoute(
            builder: (context) => _getPage(settings.name!),
          );
        }

        if (!isLoggedIn &&
            settings.name != '/auth' &&
            settings.name != '/product-detail') {
          return MaterialPageRoute(builder: (context) => const AuthPage());
        }

        // Handle product-detail page separately due to arguments
        if (settings.name == '/product-detail') {
          print('DEBUG (Main): Navigating to product-detail page');
          final args = settings.arguments as Map<String, dynamic>;
          print('DEBUG (Main): Product ID from arguments: ${args['id']}');
          return MaterialPageRoute(
            builder: (context) {
              print(
                'DEBUG (Main): Building ProductDetailPage with productId: ${args['id']}',
              );
              try {
                final page = ProductDetailPage(productId: args['id']!);
                print('DEBUG (Main): ProductDetailPage created successfully');
                return page;
              } catch (e) {
                print('ERROR (Main): Failed to create ProductDetailPage: $e');
                return Scaffold(
                  body: Center(child: Text('Error creating page: $e')),
                );
              }
            },
          );
        }

        // For all other routes, proceed to the defined route or general page
        return MaterialPageRoute(
          builder: (context) => _getPage(settings.name ?? '/'),
        );
      },
    );
  }

  Widget _getPage(String name) {
    switch (name) {
      case '/':
        return const GeneralPage();
      case '/auth':
        return const AuthPage();
      case '/profile':
        return const ProfilePage();
      case '/admin':
        return const AdminLoginPage();
      case '/admin/dashboard':
        return const AdminDashboardPage();
      case '/pin-recovery-phone': // New case
        return const PinRecoveryPhonePage();
      case '/pin-recovery-otp': // New case
        // Note: PinRecoveryOtpPage requires phoneNumber, which is typically passed as argument
        // For direct route access, it might need a default or error handling
        return const PinRecoveryOtpPage(
          phoneNumber: '',
        ); // Providing an empty string as a fallback
      case '/pin-reset': // New case
        return const PinResetPage();
      default:
        return const GeneralPage(); // Fallback
    }
  }
}

class AuthStateListener extends StatefulWidget {
  const AuthStateListener({super.key});

  @override
  State<AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<AuthStateListener> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userDeleted ||
          event == AuthChangeEvent.signedIn) {
        // Навігатор доступний після build, тому використовуємо WidgetsBinding.instance.addPostFrameCallback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (event == AuthChangeEvent.signedOut ||
              event == AuthChangeEvent.userDeleted) {
            // Перенаправлення на сторінку входу при виході або видаленні користувача
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/auth', (route) => false);
          } else if (event == AuthChangeEvent.signedIn) {
            // Якщо користувач увійшов, перенаправлення на головну сторінку
            // Перевіряємо, чи ми вже не на головній, щоб уникнути зайвої навігації
            if (ModalRoute.of(context)?.settings.name == '/auth') {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}

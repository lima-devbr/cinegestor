import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'controllers/room_controller.dart';
import 'controllers/theme_controller.dart';
import 'pages/login_page.dart';
import 'pages/room_selection_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/history_page.dart';
import 'pages/staging_page.dart';
import 'pages/defect_summary_page.dart';
import 'pages/user_management_page.dart';
import 'widgets/auth_gate.dart';
import 'theme/app_theme.dart';

bool isFirebaseInitialized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;

    // Passo 3: Ativa persistência em cache local ilimitado para reduzir custos e requisições
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase init fallback (modo local ativo): $e');
    isFirebaseInitialized = false;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()..initTheme()),
        ChangeNotifierProvider(create: (_) => AuthController()..initSession()),
        ChangeNotifierProvider(create: (_) => RoomController()..loadRooms()),
      ],
      child: const GineGestorApp(),
    ),
  );
}

class GineGestorApp extends StatelessWidget {
  const GineGestorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final roomController = Provider.of<RoomController>(context);
    final themeController = Provider.of<ThemeController>(context);

    return MaterialApp(
      title: 'CineGestor',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      initialRoute: '/',
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const AuthGate(),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => LoginPage(authController: authController),
            );
          case '/rooms':
            return MaterialPageRoute(
              builder: (_) => RoomSelectionPage(roomController: roomController),
            );
          case '/maintenance':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => MaintenancePage(
                roomId: args['roomId'],
                room: args['room'],
                roomController: roomController,
              ),
            );
          case '/history':
            return MaterialPageRoute(
              builder: (_) => const HistoryPage(),
            );
          case '/staging':
            return MaterialPageRoute(
              builder: (_) => const StagingPage(),
            );
          case '/defects':
            final initialType = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (_) => DefectSummaryPage(initialProblemType: initialType),
            );
          case '/users':
            return MaterialPageRoute(
              builder: (_) => const UserManagementPage(),
            );
          default:
            return null;
        }
      },
    );
  }
}

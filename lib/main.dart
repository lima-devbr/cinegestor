import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/room_controller.dart';
import 'pages/login_page.dart';
import 'pages/room_selection_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/history_page.dart';
import 'pages/staging_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
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

    return MaterialApp(
      title: 'CineGestor',
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
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
          default:
            return null;
        }
      },
    );
  }
}

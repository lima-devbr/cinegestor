import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/room_controller.dart';
import '../pages/login_page.dart';
import '../pages/room_selection_page.dart';
import 'apple_surfaces.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final roomController = Provider.of<RoomController>(context);

    // Se ainda está verificando a sessão salva, exibe splash minimalista estilo Apple
    if (!auth.isSessionInitialized) {
      return Scaffold(
        backgroundColor: AppleColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppleColors.accentBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.theaters_rounded,
                    size: 36,
                    color: AppleColors.accentBlue,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppleColors.accentBlue),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Se o usuário está autenticado, vai direto para as salas
    if (auth.isAuthenticated) {
      return RoomSelectionPage(roomController: roomController);
    }

    // Caso contrário, exibe o Login
    return LoginPage(authController: auth);
  }
}

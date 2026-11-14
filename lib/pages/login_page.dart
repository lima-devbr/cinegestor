import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/app_user.dart';
import '../widgets/apple_surfaces.dart';

class LoginPage extends StatefulWidget {
  final AuthController authController;

  const LoginPage({super.key, required this.authController});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    // Materialize: escala sutil + opacidade juntas (§12)
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillQuickLogin(AppUser user) {
    setState(() {
      _emailController.text = user.email;
      _passwordController.text = '123';
      _errorMessage = null;
    });
  }

  Future<void> _tryLogin() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = await widget.authController.login(email, password);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!success) {
        _errorMessage =
            widget.authController.errorMessage ?? 'Credenciais inválidas.';
      } else {
        _errorMessage = null;
        Navigator.pushReplacementNamed(context, '/rooms');
      }
    });
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.operacao:
        return AppleColors.systemAmber;
      case UserRole.assistente:
        return AppleColors.systemCyan;
      case UserRole.encarregado:
        return AppleColors.systemGreen;
      case UserRole.gerente:
        return AppleColors.accentBlue;
    }
  }

  Widget _buildQuickLoginChip(AppUser user) {
    final roleColor = _getRoleColor(user.role);
    final isSelected = _emailController.text == user.email;

    return ApplePressable(
      pressedScale: 0.95,
      onPressed: () => _fillQuickLogin(user),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? roleColor.withValues(alpha: 0.22)
              : AppleColors.surfaceElevated.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? roleColor.withValues(alpha: 0.7)
                : AppleColors.glassBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: roleColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '${user.role.shortName} • ${user.name.split(" ")[0]}',
              style: TextStyle(
                color: isSelected
                    ? AppleColors.textPrimary
                    : AppleColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.background,
      body: Stack(
        children: [
          // Luzes ambientes sutis ao fundo (Profundidade espacial - §12)
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppleColors.accentIndigo.withValues(alpha: 0.24),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -80,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppleColors.accentBlue.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AppleGlassCard(
                        elevated: true,
                        blurSigma: 28,
                        borderRadius: 24,
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Emblema minimalista estilo macOS/iOS
                            Center(
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppleColors.accentBlue,
                                      AppleColors.accentIndigo,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppleColors.accentBlue.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.event_seat_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'CineGestor',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Gestão Inteligente de Salas & Manutenção',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 28),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: AppleColors.textPrimary,
                                fontSize: 14.5,
                              ),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.alternate_email_rounded,
                                  color: AppleColors.textSecondary,
                                  size: 19,
                                ),
                                labelText: 'E-mail corporativo',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              onSubmitted: (_) => _tryLogin(),
                              style: const TextStyle(
                                color: AppleColors.textPrimary,
                                fontSize: 14.5,
                              ),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppleColors.textSecondary,
                                  size: 19,
                                ),
                                labelText: 'Senha',
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppleColors.systemRed.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppleColors.systemRed.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: AppleColors.systemRed,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: AppleColors.textPrimary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ApplePressable(
                              onPressed: _isLoading ? null : _tryLogin,
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF1E90FF),
                                      AppleColors.accentBlue,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppleColors.accentBlue.withValues(
                                        alpha: 0.32,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Continuar',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            const Text(
                              'ACESSO RÁPIDO POR PERFIL (SENHA: 123)',
                              style: TextStyle(
                                color: AppleColors.textTertiary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: AuthController.mockUsers
                                  .where((u) => u.id != 'admin')
                                  .map(_buildQuickLoginChip)
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

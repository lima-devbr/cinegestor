import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Paleta semântica inspirada no Apple Human Interface Guidelines (Dark Mode)
class AppleColors {
  // Camadas de profundidade (Materials & Depth - §12)
  static const Color background = Color(0xFF090A0F);
  static const Color backgroundSecondary = Color(0xFF11131A);
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceElevated = Color(0xFF2C2C2E);
  static const Color surfaceHighlight = Color(0xFF3A3A3C);

  // Vidro translúcido e bordas especulares
  static const Color glassFill = Color(0xB81C1C1E);
  static const Color glassElevatedFill = Color(0xCC252529);
  static const Color glassBorder = Color(0x1FFFFFFF);
  static const Color glassTopHighlight = Color(0x33FFFFFF);

  // Cores de sistema vibrantes (Vibrancy sobre superfícies escuras)
  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentIndigo = Color(0xFF5E5CE6);
  static const Color systemGreen = Color(0xFF30D158);
  static const Color systemAmber = Color(0xFFFFD60A);
  static const Color systemOrange = Color(0xFFFF9F0A);
  static const Color systemRed = Color(0xFFFF453A);
  static const Color systemCyan = Color(0xFF64D2FF);
  static const Color systemPurple = Color(0xFFBF5AF2);

  // Hierarquia tipográfica com contraste calibrado
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA1A1A6);
  static const Color textTertiary = Color(0xFF6E6E73);
}

/// Componente interativo com resposta imediata no pointer-down (§1),
/// física de mola criticamente amortecida e interrompível (§3 e §4),
/// feedback háptico sincronizado (§13) e suporte a movimento reduzido (§14).
class ApplePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double pressedScale;
  final bool enableHaptics;
  final HitTestBehavior behavior;

  const ApplePressable({
    super.key,
    required this.child,
    this.onPressed,
    this.pressedScale = 0.97,
    this.enableHaptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<ApplePressable> createState() => _ApplePressableState();
}

class _ApplePressableState extends State<ApplePressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Mola criticamente amortecida (damping ratio = 1.0, response ~0.3s) — §4
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 520.0,
    ratio: 1.0,
  );

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target, {double velocity = 0.0}) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = target;
      return;
    }
    // Sempre parte do valor atual em tela (_controller.value) para garantir
    // interrompibilidade limpa sem saltos (§3)
    final simulation = SpringSimulation(
      _spring,
      _controller.value,
      target,
      velocity,
    );
    _controller.animateWith(simulation);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _animateTo(widget.pressedScale);
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _animateTo(1.0);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _animateTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onPressed == null) return widget.child;

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Listener(
      behavior: widget.behavior,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = _controller.value.clamp(0.85, 1.08);
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: _isPressed ? 0.88 : 1.0,
              child: reduceMotion
                  ? child
                  : Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: child,
                    ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Superfície translúcida estilo macOS/iOS (Materials & Depth - §12)
/// com desfoque gaussiano, borda iluminada no topo e sombra contextual.
class AppleGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? tintColor;
  final Color? borderColor;
  final double blurSigma;
  final VoidCallback? onTap;
  final bool elevated;

  const AppleGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.tintColor,
    this.borderColor,
    this.blurSigma = 18,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = tintColor ??
        (elevated ? AppleColors.glassElevatedFill : AppleColors.glassFill);
    final border = borderColor ?? AppleColors.glassBorder;

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.42 : 0.26),
            blurRadius: elevated ? 24 : 14,
            offset: Offset(0, elevated ? 10 : 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: border, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.01),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return ApplePressable(
        onPressed: onTap,
        child: card,
      );
    }
    return card;
  }
}

/// Badge/Pill semântico de alto contraste com ponto luminoso (Vibrancy - §12)
class AppleStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool showDot;

  const AppleStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

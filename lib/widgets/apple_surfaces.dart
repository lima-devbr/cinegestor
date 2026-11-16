import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Paleta semântica inspirada no Apple Human Interface Guidelines (Dark & Light Mode)
class AppleColors {
  static bool isDark = true;

  // Camadas de profundidade (Materials & Depth - §12)
  static Color get background =>
      isDark ? const Color(0xFF090A0F) : const Color(0xFFF2F2F7);
  static Color get backgroundSecondary =>
      isDark ? const Color(0xFF11131A) : const Color(0xFFE5E5EA);
  static Color get surface =>
      isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  static Color get surfaceElevated =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  static Color get surfaceHighlight =>
      isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);

  // Vidro translúcido e bordas especulares
  static Color get glassFill =>
      isDark ? const Color(0xB81C1C1E) : const Color(0xD9FFFFFF);
  static Color get glassElevatedFill =>
      isDark ? const Color(0xCC252529) : const Color(0xF2FFFFFF);
  static Color get glassBorder =>
      isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000);
  static Color get glassTopHighlight =>
      isDark ? const Color(0x33FFFFFF) : const Color(0xFFFFFFFF);

  // Cores de sistema vibrantes (calibradas para contraste em Dark e Light)
  static Color get accentBlue =>
      isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  static Color get accentIndigo =>
      isDark ? const Color(0xFF5E5CE6) : const Color(0xFF5856D6);
  static Color get systemGreen =>
      isDark ? const Color(0xFF30D158) : const Color(0xFF248A3D);
  static Color get systemAmber =>
      isDark ? const Color(0xFFFFD60A) : const Color(0xFFD97706);
  static Color get systemOrange =>
      isDark ? const Color(0xFFFF9F0A) : const Color(0xFFE66A00);
  static Color get systemRed =>
      isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
  static Color get systemCyan =>
      isDark ? const Color(0xFF64D2FF) : const Color(0xFF0082B3);
  static Color get systemPurple =>
      isDark ? const Color(0xFFBF5AF2) : const Color(0xFF8944AB);

  // Hierarquia tipográfica com contraste calibrado
  static Color get textPrimary =>
      isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA1A1A6) : const Color(0xFF636366);
  static Color get textTertiary =>
      isDark ? const Color(0xFF6E6E73) : const Color(0xFF8E8E93);
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
/// Otimizada para GPU mobile: aplica BackdropFilter apenas em barras/modais
/// flutuantes (`enableBlur: true`), mantendo 60/120fps em listas longas.
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
  final bool enableBlur;

  const AppleGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.tintColor,
    this.borderColor,
    this.blurSigma = 16,
    this.onTap,
    this.elevated = false,
    this.enableBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppleColors.isDark;
    final bg = tintColor ??
        (isDark
            ? (elevated ? const Color(0xF0222226) : const Color(0xE81C1C1E))
            : (elevated ? const Color(0xFAFFFFFF) : const Color(0xF2FFFFFF)));
    final border = borderColor ?? AppleColors.glassBorder;

    final innerContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.055),
                  Colors.white.withValues(alpha: 0.01),
                ]
              : [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.70),
                ],
        ),
      ),
      child: child,
    );

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark
                  ? (elevated ? 0.36 : 0.20)
                  : (elevated ? 0.09 : 0.045),
            ),
            blurRadius: elevated ? 18 : 10,
            offset: Offset(0, elevated ? 8 : 4),
          ),
        ],
      ),
      child: enableBlur
          ? ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: innerContainer,
              ),
            )
          : innerContainer,
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

/// Termômetro visual da sala baseado em porcentagem de poltronas em atenção
/// e presença de poltronas interditadas (Encosto Solto / Assento Solto):
/// - Verde: 0% a 5% de pendências usuais (e 0 interditadas)
/// - Amarelo: 5,1% a 12% de pendências usuais
/// - Laranja: 12,1% a 20% de pendências usuais (ou 1-2 interditadas)
/// - Vermelho: > 20% de pendências usuais (ou 3+ interditadas)
class AppleThermometerBar extends StatelessWidget {
  final int usualDefectSeats;
  final int blockingSeats;
  final int stagingCount;
  final int totalSeats;

  const AppleThermometerBar({
    super.key,
    required this.usualDefectSeats,
    this.blockingSeats = 0,
    this.stagingCount = 0,
    required this.totalSeats,
  });

  static double calculateHeat({
    required int usualDefectSeats,
    required int blockingSeats,
    required int stagingCount,
    required int totalSeats,
  }) {
    final total = totalSeats > 0 ? totalSeats : 1;
    final affectedSeats = usualDefectSeats + blockingSeats + (stagingCount * 0.5);
    final pct = (affectedSeats / total) * 100.0;

    double pctHeat;
    if (pct <= 0.0) {
      pctHeat = 0.0;
    } else if (pct <= 5.0) {
      // 0% a 5% -> faixa Verde (0.05 a 0.25)
      pctHeat = 0.05 + (pct / 5.0) * 0.20;
    } else if (pct <= 12.0) {
      // 5.1% a 12% -> faixa Amarela (0.25 a 0.55)
      pctHeat = 0.25 + ((pct - 5.0) / 7.0) * 0.30;
    } else if (pct <= 20.0) {
      // 12.1% a 20% -> faixa Laranja (0.55 a 0.85)
      pctHeat = 0.55 + ((pct - 12.0) / 8.0) * 0.30;
    } else {
      // Acima de 20% -> faixa Vermelha (0.85 a 1.0)
      pctHeat = (0.85 + ((pct - 20.0) / 10.0) * 0.15).clamp(0.85, 1.0);
    }

    // Se houver cadeiras interditadas (Encosto Solto / Assento Solto), puxa o termômetro:
    // 1-2 interditadas = no mínimo Laranja (0.65 - 0.78)
    // 3+ interditadas = Vermelho (0.90 - 1.0)
    double blockingHeat = 0.0;
    if (blockingSeats >= 3) {
      blockingHeat = (0.90 + (blockingSeats - 3) * 0.03).clamp(0.90, 1.0);
    } else if (blockingSeats == 2) {
      blockingHeat = 0.78;
    } else if (blockingSeats == 1) {
      blockingHeat = 0.65;
    }

    return pctHeat > blockingHeat ? pctHeat : blockingHeat;
  }

  static Color colorForHeat(double heat) {
    if (heat <= 0.25) return AppleColors.systemGreen;
    if (heat <= 0.55) {
      return Color.lerp(
        AppleColors.systemGreen,
        AppleColors.systemAmber,
        (heat - 0.25) / 0.30,
      )!;
    }
    if (heat <= 0.85) {
      return Color.lerp(
        AppleColors.systemAmber,
        AppleColors.systemOrange,
        (heat - 0.55) / 0.30,
      )!;
    }
    return Color.lerp(
      AppleColors.systemOrange,
      AppleColors.systemRed,
      ((heat - 0.85) / 0.15).clamp(0.0, 1.0),
    )!;
  }

  @override
  Widget build(BuildContext context) {
    final heat = calculateHeat(
      usualDefectSeats: usualDefectSeats,
      blockingSeats: blockingSeats,
      stagingCount: stagingCount,
      totalSeats: totalSeats,
    );
    final currentColor = colorForHeat(heat);
    final fillFraction = heat == 0.0 ? 1.0 : heat.clamp(0.14, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6,
        width: double.infinity,
        color: AppleColors.surfaceElevated,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fillFraction,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: heat == 0.0
                  ? LinearGradient(
                      colors: [
                        AppleColors.systemGreen.withValues(alpha: 0.7),
                        AppleColors.systemGreen,
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        AppleColors.systemGreen,
                        if (heat > 0.28) AppleColors.systemAmber,
                        if (heat > 0.58) AppleColors.systemOrange,
                        currentColor,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

OverlayEntry? _activeTopNoticeEntry;
Timer? _activeTopNoticeTimer;

/// Exibe uma notificação flutuante no TOPO da tela (estilo iOS Dynamic Island / Banner)
void showTopNotice(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isWarning = false,
}) {
  _activeTopNoticeTimer?.cancel();
  _activeTopNoticeEntry?.remove();
  _activeTopNoticeEntry = null;

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final Color accentColor = isError
      ? AppleColors.systemRed
      : isWarning
          ? AppleColors.systemAmber
          : AppleColors.systemGreen;

  final IconData icon = isError
      ? Icons.error_outline_rounded
      : isWarning
          ? Icons.pending_actions_rounded
          : Icons.check_circle_rounded;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final topPadding = MediaQuery.of(ctx).padding.top + 10;
      return Positioned(
        top: topPadding,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, -16 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () {
                    _activeTopNoticeTimer?.cancel();
                    entry.remove();
                    if (_activeTopNoticeEntry == entry) {
                      _activeTopNoticeEntry = null;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppleColors.isDark
                          ? const Color(0xF5242428)
                          : const Color(0xFAFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: AppleColors.isDark ? 0.45 : 0.14,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: accentColor, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: AppleColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _activeTopNoticeEntry = entry;
  overlay.insert(entry);

  _activeTopNoticeTimer = Timer(const Duration(milliseconds: 2800), () {
    if (_activeTopNoticeEntry == entry) {
      entry.remove();
      _activeTopNoticeEntry = null;
    }
  });
}

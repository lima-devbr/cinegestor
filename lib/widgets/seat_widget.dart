import 'package:flutter/material.dart';
import 'package:cinegestor/models/seat.dart';
import 'package:cinegestor/widgets/apple_surfaces.dart';

class SeatWidget extends StatelessWidget {
  final Seat seat;
  final String? exceptionType;
  final bool isSelected;

  const SeatWidget({
    super.key,
    required this.seat,
    this.exceptionType,
    this.isSelected = false,
  });

  Color _getSeatBaseColor() {
    if (isSelected) {
      return AppleColors.accentBlue;
    }
    if (seat.hasDefect) {
      return AppleColors.systemRed;
    }
    if (seat.hasStaging) {
      return AppleColors.systemAmber;
    }
    switch (seat.type) {
      case 'Disability':
        return AppleColors.systemCyan;
      case 'Companion':
        return AppleColors.systemOrange;
      case 'Obese':
        return AppleColors.systemPurple;
    }
    if (exceptionType != null) {
      return AppleColors.systemOrange;
    }
    // Verde esmeralda profundo e calmo para assentos operacionais,
    // destacando imediatamente assentos vermelhos/âmbar com defeito (§12 e §16)
    return const Color(0xFF248A3D);
  }

  Color _getTextColor() {
    if (isSelected || seat.hasDefect) {
      return Colors.white;
    }
    if (seat.hasStaging ||
        seat.type == 'Disability' ||
        seat.type == 'Companion') {
      return const Color(0xFF11131A);
    }
    return const Color(0xFFF5F5F7);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _getSeatBaseColor();
    final hasAlert = seat.hasDefect || seat.hasStaging;

    return AnimatedScale(
      scale: isSelected ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.all(3.5),
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(9),
            topRight: Radius.circular(9),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(baseColor, Colors.white, 0.14)!,
              baseColor,
              Color.lerp(baseColor, Colors.black, 0.22)!,
            ],
          ),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : hasAlert
                    ? Colors.white.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.18),
            width: isSelected ? 2.0 : (hasAlert ? 1.4 : 0.8),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppleColors.accentBlue.withValues(alpha: 0.55),
                blurRadius: 10,
                spreadRadius: 1,
              )
            else if (seat.hasDefect)
              BoxShadow(
                color: AppleColors.systemRed.withValues(alpha: 0.45),
                blurRadius: 8,
              )
            else if (seat.hasStaging)
              BoxShadow(
                color: AppleColors.systemAmber.withValues(alpha: 0.35),
                blurRadius: 6,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Detalhe sutil de encosto superior da poltrona
            Positioned(
              top: 2,
              left: 5,
              right: 5,
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${seat.row}${seat.number}',
                style: TextStyle(
                  color: _getTextColor(),
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

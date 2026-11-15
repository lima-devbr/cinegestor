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
    // 1. Defeito crítico que interdita a poltrona (Encosto Solto / Assento Solto) -> Vermelho
    if (seat.hasBlockingDefect) {
      return AppleColors.systemRed;
    }
    // 2. Defeito usual que merece atenção mas continua operacional (Capas, Número, PC, Mola) -> Laranja
    if (seat.hasDefect) {
      return AppleColors.systemOrange;
    }
    // 3. Em triagem pela operação -> Amarelo
    if (seat.hasStaging) {
      return AppleColors.systemAmber;
    }
    switch (seat.type) {
      case 'Disability':
        return AppleColors.systemCyan;
      case 'Companion':
        return AppleColors.accentIndigo;
      case 'Obese':
        return AppleColors.systemPurple;
    }
    if (exceptionType != null) {
      return AppleColors.accentIndigo;
    }
    return const Color(0xFF248A3D);
  }

  Color _getTextColor() {
    if (isSelected || seat.hasBlockingDefect) {
      return Colors.white;
    }
    if (seat.hasDefect ||
        seat.hasStaging ||
        seat.type == 'Disability') {
      return const Color(0xFF11131A);
    }
    return const Color(0xFFF5F5F7);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _getSeatBaseColor();
    final hasAlert = seat.hasBlockingDefect || seat.hasDefect || seat.hasStaging;

    return Container(
      margin: const EdgeInsets.all(3.0),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(9),
          topRight: Radius.circular(9),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
        border: Border.all(
          color: isSelected
              ? Colors.white
              : hasAlert
                  ? Colors.white.withValues(alpha: 0.78)
                  : Colors.white.withValues(alpha: 0.16),
          width: isSelected ? 2.2 : (hasAlert ? 1.5 : 0.8),
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppleColors.accentBlue.withValues(alpha: 0.65),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 2,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            '${seat.row}${seat.number}',
            style: TextStyle(
              color: _getTextColor(),
              fontWeight: FontWeight.w700,
              fontSize: 9.5,
              height: 1.0,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

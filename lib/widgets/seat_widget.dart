import 'package:flutter/material.dart';
import 'package:cinegestor/models/seat.dart';

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

  Color _getSeatColor() {
    if (isSelected) {
      return Colors.deepPurpleAccent;
    }
    // Defeito confirmado / ativo tem prioridade (vermelho)
    if (seat.hasDefect) {
      return Colors.redAccent;
    }
    // Demanda em triagem / staging da operação (amarelo/âmbar pulsante)
    if (seat.hasStaging) {
      return Colors.amberAccent.shade400;
    }
    switch (seat.type) {
      case 'Disability':
        return Colors.lightBlueAccent;
      case 'Companion':
        return Colors.orangeAccent;
      case 'Obese':
        return Colors.amber;
    }
    if (exceptionType != null) {
      return Colors.orangeAccent;
    }
    return Colors.greenAccent.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: _getSeatColor(),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? Colors.white
              : seat.hasStaging
                  ? Colors.white70
                  : Colors.black26,
          width: isSelected || seat.hasStaging ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '${seat.row}${seat.number}',
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : seat.hasStaging
                  ? Colors.black87
                  : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

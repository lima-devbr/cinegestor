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
    if (seat. hasDefect) {
      return Colors.redAccent;
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
          color: isSelected ? Colors.white : Colors.black26,
          width: isSelected ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '${seat.row}${seat.number}',
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

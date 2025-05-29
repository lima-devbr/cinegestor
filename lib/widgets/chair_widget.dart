import 'package:flutter/material.dart';

class ChairWidget extends StatelessWidget {
  final String label;
  final String? tipo;
  final bool isSelected;
  final VoidCallback? onTap;

  const ChairWidget({
    super.key,
    required this.label,
    this.tipo,
    this.isSelected = false,
    this.onTap,
  });

  Color _getChairColor() {
    if (isSelected) {
      return Colors.deepPurpleAccent;
    }
    switch (tipo) {
      case 'cadeiraObeso':
        return Colors.orangeAccent;
      case 'defeito':
        return Colors.redAccent;
      default:
        return Colors.greenAccent.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        width: tipo == 'cadeiraObeso' ? 60 : 30,
        height: 30,
        decoration: BoxDecoration(
          color: _getChairColor(),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.black26,
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
} 
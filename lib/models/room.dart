import 'seat.dart';
class Room {
  final String id;
  final String nome;
  final List<String> rows;
  final int colsDefault;
  final Map<String, int> colsByRow;
  final Map<String, int> spacingBetweenRows;
  final Map<String, List<int>> aislesByRow;
  final Map<String, String> excecoes;


  Room({
    required this.id,
    required this.nome,
    required this.rows,
    required this.colsDefault,
    required this.colsByRow,
    required this.spacingBetweenRows,
    required this.aislesByRow,
    required this.excecoes,
  
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      nome: json['nome'],
      rows: List<String>.from(json['rows']),
      colsDefault: json['colsDefault'],
      colsByRow: Map<String, int>.from(json['colsByRow']),
      spacingBetweenRows: Map<String, int>.from(json['spacingBetweenRows']),
      aislesByRow: Map<String, List<int>>.fromEntries(
        (json['aislesByRow'] as Map<String, dynamic>).entries.map(
          (e) => MapEntry(e.key, List<int>.from(e.value)),
        ),
      ),
      excecoes: Map<String, String>.from(json['excecoes']),
    );
  }

  Map<String, Seat> seats = {};

    Seat? getSeat(String row, int number) {
    final seatId = '$row$number';
    return seats[seatId];
  }
}

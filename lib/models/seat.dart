class Seat {
  final String row;
  final int number;
  bool  hasDefect; // indica se está com problema

  Seat({
    required this.row,
    required this.number,
    this. hasDefect = false,
  });

  String get id => '$row$number';

  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'number': number,
      ' hasDefect':  hasDefect,
    };
  }

  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      row: json['row'],
      number: json['number'],
       hasDefect: json[' hasDefect'] ?? false,
    );
  }
}

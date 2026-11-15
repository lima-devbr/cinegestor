class Seat {
  final String row;
  final int number;
  final int? line;
  final int? column;
  final String type; // 'Regular', 'Disability', 'Companion', 'Obese'
  bool hasDefect; // indica se está com pendência usual (continua operacional, laranja)
  bool hasBlockingDefect; // indica se está interditada/insegura (Encosto/Assento solto, vermelho)
  bool hasStaging; // indica se está em triagem/análise (solicitação pendente, amarelo)

  Seat({
    required this.row,
    required this.number,
    this.line,
    this.column,
    this.type = 'Regular',
    this.hasDefect = false,
    this.hasBlockingDefect = false,
    this.hasStaging = false,
  });

  String get id => '$row$number';

  String? get typeLabel {
    switch (type) {
      case 'Disability':
        return 'Cadeirante';
      case 'Companion':
        return 'Acompanhante';
      case 'Obese':
        return 'Obeso';
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'number': number,
      'line': line,
      'column': column,
      'type': type,
      'hasDefect': hasDefect,
      'hasStaging': hasStaging,
    };
  }

  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      row: json['row'],
      number: json['number'],
      line: json['line'],
      column: json['column'],
      type: json['type'] ?? 'Regular',
      hasDefect: json['hasDefect'] ?? json[' hasDefect'] ?? false,
      hasStaging: json['hasStaging'] ?? false,
    );
  }
}

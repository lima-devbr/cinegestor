import 'seat.dart';

class GridLabel {
  final String label;
  final int line;
  final int column;

  const GridLabel({
    required this.label,
    required this.line,
    required this.column,
  });

  factory GridLabel.fromJson(Map<String, dynamic> json) {
    return GridLabel(
      label: json['label'].toString(),
      line: json['line'] as int,
      column: json['column'] as int,
    );
  }
}

class Room {
  final String id;
  final String nome;
  final String? theaterId;
  final String? theaterName;
  final List<String> rows;
  final int colsDefault;
  final Map<String, int> colsByRow;
  final Map<String, int> spacingBetweenRows;
  final Map<String, List<int>> aislesByRow;
  final Map<String, String> excecoes;

  // Campos de layout em Grid (padrão Ingresso.com)
  final int boundsLines;
  final int boundsColumns;
  final List<GridLabel> gridLabels;
  final int? stageLine;

  bool get isGridLayout => boundsLines > 0 && boundsColumns > 0;

  String get theaterShortName {
    if (theaterName == null || theaterName!.isEmpty) return '';
    return theaterName!
        .replaceAll('Campo Grande', 'CG')
        .replaceAll('Shopping', 'Shop.');
  }

  String get displayName {
    if (theaterShortName.isNotEmpty) {
      return '$theaterShortName • $nome';
    }
    return nome;
  }

  int get totalSeats {
    if (seats.isNotEmpty) return seats.length;
    return rows.fold(0, (sum, row) {
      final cols = colsByRow[row] ?? colsDefault;
      final aisles = aislesByRow[row]?.length ?? 0;
      return sum + (cols - aisles);
    });
  }

  Room({
    required this.id,
    required this.nome,
    this.theaterId,
    this.theaterName,
    required this.rows,
    required this.colsDefault,
    required this.colsByRow,
    required this.spacingBetweenRows,
    required this.aislesByRow,
    required this.excecoes,
    this.boundsLines = 0,
    this.boundsColumns = 0,
    this.gridLabels = const [],
    this.stageLine,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    // Detecta se é o formato de grid da Ingresso.com (possui 'lines' e 'bounds')
    if (json.containsKey('lines') && json.containsKey('bounds')) {
      return Room.fromGridJson(json);
    }

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

  factory Room.fromGridJson(Map<String, dynamic> json) {
    final locationName = (json['theaterLocationName'] ?? json['nome'] ?? 'Sala').toString();
    final extractedId = json['id']?.toString() ??
        RegExp(r'\d+').firstMatch(locationName)?.group(0) ??
        locationName;

    final bounds = json['bounds'] as Map<String, dynamic>? ?? {};
    final stage = json['stage'] as Map<String, dynamic>?;
    final stageUpperLeft = stage?['upperLeft'] as Map<String, dynamic>?;

    final labelsList = (json['labels'] as List<dynamic>? ?? [])
        .map((l) => GridLabel.fromJson(l as Map<String, dynamic>))
        .toList();

    final Map<String, Seat> parsedSeats = {};
    final Map<String, String> parsedExcecoes = {};
    final List<String> rowOrder = [];

    for (final lineObj in (json['lines'] as List<dynamic>? ?? [])) {
      final lineMap = lineObj as Map<String, dynamic>;
      final seatsList = lineMap['seats'] as List<dynamic>? ?? [];
      for (final seatJson in seatsList) {
        final sMap = seatJson as Map<String, dynamic>;
        String row = (sMap['row'] ?? '').toString().toUpperCase();
        int number = sMap['number'] is int ? sMap['number'] as int : 0;

        if (row.isEmpty || number == 0) {
          final rawLabel = (sMap['label'] ?? '').toString().trim().toUpperCase();
          final parts = rawLabel.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) row = parts[0];
          if (parts.length > 1) number = int.tryParse(parts[1]) ?? 0;
        }

        if (row.isNotEmpty && !rowOrder.contains(row)) {
          rowOrder.add(row);
        }

        final seatType = (sMap['type'] ?? 'Regular').toString();
        final seat = Seat(
          row: row,
          number: number,
          line: sMap['line'] as int?,
          column: sMap['column'] as int?,
          type: seatType,
        );
        parsedSeats[seat.id] = seat;

        if (seatType != 'Regular') {
          parsedExcecoes[seat.id] = seat.typeLabel ?? seatType;
        }
      }
    }

    final room = Room(
      id: extractedId,
      nome: locationName,
      theaterId: json['theaterBoxOfficeId']?.toString(),
      theaterName: json['theaterName']?.toString(),
      rows: rowOrder,
      colsDefault: 0,
      colsByRow: const {},
      spacingBetweenRows: const {},
      aislesByRow: const {},
      excecoes: parsedExcecoes,
      boundsLines: (bounds['lines'] as int?) ?? 0,
      boundsColumns: (bounds['columns'] as int?) ?? 0,
      gridLabels: labelsList,
      stageLine: stageUpperLeft?['line'] as int?,
    );
    room.seats = parsedSeats;
    return room;
  }

  Map<String, Seat> seats = {};

  Seat? getSeat(String row, int number) {
    final seatId = '$row$number';
    return seats[seatId];
  }
}

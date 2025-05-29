// lib/models/assento.dart
enum TipoAssento {
  normal,
  acessibilidade,
  acompanhante,
}

class Assento {
  final String id;
  final String row;
  final int col;
  TipoAssento tipo;
  bool isDefeituoso;

  Assento({
    required this.id,
    required this.row,
    required this.col,
    this.tipo = TipoAssento.normal,
    this.isDefeituoso = false,
  });

  factory Assento.fromExcecao(String row, int col, String? tipo) {
    TipoAssento tipoAssento = TipoAssento.normal;
    if (tipo == "acessibilidade") {
      tipoAssento = TipoAssento.acessibilidade;
    } else if (tipo == "acompanhante") {
      tipoAssento = TipoAssento.acompanhante;
    }
    return Assento(
      id: "$row$col",
      row: row,
      col: col,
      tipo: tipoAssento,
    );
  }
}

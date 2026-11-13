class StockSede {
  final String sede;
  final String tipoSanguineo;
  final int cantidad;

  StockSede({
    required this.sede,
    required this.tipoSanguineo,
    required this.cantidad,
  });

  factory StockSede.fromMap(Map<String, dynamic> map) {
    return StockSede(
      sede: map['sede'] as String,
      tipoSanguineo: map['tipo_sanguineo'] as String,
      cantidad: map['cantidad'] as int,
    );
  }
  Map<String, dynamic> toMap() => {
    'sede': sede,
    'tipo_sanguineo': tipoSanguineo,
    'cantidad': cantidad,
  };
}
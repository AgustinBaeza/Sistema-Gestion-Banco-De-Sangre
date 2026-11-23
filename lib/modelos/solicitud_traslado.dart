import 'bolsa_sangre.dart';

class NivelesStockReferencia {
  final int stockMinimo;
  final int stockOptimo;
  final int stockMaximo;

  const NivelesStockReferencia({
    required this.stockMinimo,
    required this.stockOptimo,
    required this.stockMaximo,
  });

  /// Unidades disponibles por encima del stock mínimo (límite máximo trasladable)
  int excedenteSobreMinimo(int stockActual) =>
      (stockActual - stockMinimo).clamp(0, stockActual);

  /// Unidades excedentes por encima del stock óptimo
  int excedenteSobreOptimo(int stockActual) =>
      (stockActual - stockOptimo).clamp(0, stockActual);
}

class SolicitudTraslado {
  final int? id;
  final String sedeOrigen;
  final String sedeDestino;
  final TipoSanguineo tipoSanguineo;
  final int cantidad;
  final int stockMinimo;
  final int stockOptimo;
  final int stockMaximo;
  final String estado;
  final bool notificacionEnviada;
  final DateTime fechaCreacion;

  const SolicitudTraslado({
    this.id,
    required this.sedeOrigen,
    required this.sedeDestino,
    required this.tipoSanguineo,
    required this.cantidad,
    required this.stockMinimo,
    required this.stockOptimo,
    required this.stockMaximo,
    this.estado = 'pendiente',
    this.notificacionEnviada = true,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sede_origen': sedeOrigen,
        'sede_destino': sedeDestino,
        'tipo_sanguineo': tipoSanguineo.name,
        'cantidad': cantidad,
        'stock_minimo': stockMinimo,
        'stock_optimo': stockOptimo,
        'stock_maximo': stockMaximo,
        'estado': estado,
        'notificacion_enviada': notificacionEnviada ? 1 : 0,
        'fecha_creacion': fechaCreacion.toIso8601String(),
      };

  factory SolicitudTraslado.fromMap(Map m) {
    final rawTipo = m['tipo_sanguineo'] as String;
    final tipo = TipoSanguineo.values.firstWhere(
      (t) => t.name == rawTipo || t.etiqueta == rawTipo,
      orElse: () => TipoSanguineo.values.byName(rawTipo),
    );

    return SolicitudTraslado(
      id: m['id'] as int?,
      sedeOrigen: m['sede_origen'] as String,
      sedeDestino: m['sede_destino'] as String,
      tipoSanguineo: tipo,
      cantidad: m['cantidad'] as int,
      stockMinimo: m['stock_minimo'] as int,
      stockOptimo: m['stock_optimo'] as int,
      stockMaximo: m['stock_maximo'] as int,
      estado: (m['estado'] as String?) ?? 'pendiente',
      notificacionEnviada: ((m['notificacion_enviada'] as int?) ?? 1) == 1,
      fechaCreacion: DateTime.parse(m['fecha_creacion'] as String),
    );
  }
}
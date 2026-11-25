import 'package:flutter/painting.dart';
import 'bolsa_sangre.dart';
import 'stock_sede.dart';

enum NivelStock {
  critico("Crítico", Color(0xFFB91C1C), Color(0xFFFDE8E8)),
  bajo("Bajo", Color(0xFFB45309), Color(0xFFFEF3C7)),
  normal("Normal", Color(0xFF15803D), Color(0xFFDCFCE7)),
  abundante("Abundante", Color(0xFF1D4ED8), Color(0xFFDBEAFE));

  const NivelStock(this.etiqueta, this.color, this.fondo);
  final String etiqueta;
  final Color color;
  final Color fondo;

  /// Umbrales en unidades vigentes por sede y tipo
  static const maxCritico = 1;
  static const maxBajo = 4;
  static const minAbundante = 15;

  static NivelStock de(int cantidad) {
    if (cantidad <= maxCritico) return critico;
    if (cantidad <= maxBajo) return bajo;
    if (cantidad >= minAbundante) return abundante;
    return normal;
  }
}

class EvaluacionStock {
  final TipoSanguineo tipo;
  final String sede;
  final int cantidad;

  const EvaluacionStock(this.tipo, this.sede, this.cantidad);

  NivelStock get nivel => NivelStock.de(cantidad);
  bool get enFalta => nivel == NivelStock.critico || nivel == NivelStock.bajo;
}

/// Cruza cada tipo con cada sede. Las combinaciones sin bolsas quedan en 0,
/// porque que no haya unidades tambien es una falta.
List<EvaluacionStock> evaluarStock(
  List<StockSede> filas,
  List<String> sedes,
  List<TipoSanguineo> tipos,
) => [
  for (final t in tipos)
    for (final s in sedes)
      EvaluacionStock(
        t,
        s,
        filas
            .where((f) => f.sede == s && f.tipoSanguineo == t.name)
            .fold(0, (suma, f) => suma + f.cantidad),
      ),
];
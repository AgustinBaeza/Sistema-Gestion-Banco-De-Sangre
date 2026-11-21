import "bolsa_sangre.dart";

enum EstadoVencimiento {
  disponible("Disponible"),
  proximaAVencer("Próxima a vencer"),
  vencida("Vencida (No apta)");

  const EstadoVencimiento(this.etiqueta);
  final String etiqueta;
}

class UnidadOrdenada {
  final BolsaSangre bolsa;
  final EstadoVencimiento estado;
  final int diasRestantes;
  final bool esApta;
  final String detalleEstado;

  const UnidadOrdenada({
    required this.bolsa,
    required this.estado,
    required this.diasRestantes,
    required this.esApta,
    required this.detalleEstado,
  });

  // Calcula cuantos dias quedan y revisa si la bolsa esta disponible, por vencer o ya vencida
  factory UnidadOrdenada.evaluar(
    BolsaSangre bolsa, {
    DateTime? fechaReferencia,
    int diasAlerta = 7,
  }) {
    final umbral = diasAlerta < 0 ? 0 : diasAlerta;
    final ref = soloFecha(fechaReferencia ?? fechaHoy());
    final vence = soloFecha(bolsa.fechaVencimiento);
    final ingreso = soloFecha(bolsa.fechaIngreso);

    // Si vienen datos raros, como volumen <= 0 o fechas al reves, la marcamos como no apta para que no se caiga
    if (bolsa.volumenMl <= 0 || !vence.isAfter(ingreso)) {
      return UnidadOrdenada(
        bolsa: bolsa,
        estado: EstadoVencimiento.vencida,
        diasRestantes: 0,
        esApta: false,
        detalleEstado: "Unidad inválida (No apta)",
      );
    }

    final diferenciaDias = vence.difference(ref).inDays;

    // Si da 0 o negativo es porque ya vencio; dejamos diasRestantes en 0 para no mostrar numeros negativos
    if (diferenciaDias <= 0) {
      final diasPasados = diferenciaDias.abs();
      final textoVencida = diasPasados == 0
          ? "Vence hoy (No apta)"
          : "Vencida hace $diasPasados ${diasPasados == 1 ? 'día' : 'días'} (No apta)";

      return UnidadOrdenada(
        bolsa: bolsa,
        estado: EstadoVencimiento.vencida,
        diasRestantes: 0,
        esApta: false,
        detalleEstado: textoVencida,
      );
    }

    if (diferenciaDias <= umbral) {
      return UnidadOrdenada(
        bolsa: bolsa,
        estado: EstadoVencimiento.proximaAVencer,
        diasRestantes: diferenciaDias,
        esApta: true,
        detalleEstado:
            "Vence en $diferenciaDias ${diferenciaDias == 1 ? 'día' : 'días'}",
      );
    }

    return UnidadOrdenada(
      bolsa: bolsa,
      estado: EstadoVencimiento.disponible,
      diasRestantes: diferenciaDias,
      esApta: true,
      detalleEstado: "Vence en $diferenciaDias días",
    );
  }
}

// Ordena las bolsas por fecha de vencimiento (primero las que vencen antes).
// Las vencidas o no aptas quedan al final para no mezclarlas con las disponibles.
List<UnidadOrdenada> ordenarUnidadesPorVencimiento(
  List<BolsaSangre> bolsas, {
  DateTime? fechaReferencia,
  int diasAlerta = 7,
}) {
  final evaluadas = bolsas
      .map(
        (b) => UnidadOrdenada.evaluar(
          b,
          fechaReferencia: fechaReferencia,
          diasAlerta: diasAlerta,
        ),
      )
      .toList();

  evaluadas.sort((a, b) {
    // Las aptas siempre van arriba y las vencidas al final
    if (a.esApta != b.esApta) {
      return a.esApta ? -1 : 1;
    }

    // Si ambas son aptas o ambas vencidas, ordenamos por la fecha mas cercana
    final cmpFecha = soloFecha(a.bolsa.fechaVencimiento)
        .compareTo(soloFecha(b.bolsa.fechaVencimiento));
    if (cmpFecha != 0) return cmpFecha;

    // Si vencen el mismo dia, desempatamos por codigo
    return a.bolsa.codigo.compareTo(b.bolsa.codigo);
  });

  return evaluadas;
}
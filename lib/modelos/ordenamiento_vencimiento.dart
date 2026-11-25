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

  // Calcula cuantos dias faltan para que venza y clasifica la bolsa
  factory UnidadOrdenada.evaluar(
    BolsaSangre bolsa, {
    DateTime? fechaReferencia,
    int diasAlerta = 7,
  }) {
    final umbral = diasAlerta < 0 ? 0 : diasAlerta;
    final ref = soloFecha(fechaReferencia ?? fechaHoy());
    final vence = soloFecha(bolsa.fechaVencimiento);
    final ingreso = soloFecha(bolsa.fechaIngreso);

    // Si vienen datos invalidos (volumen <= 0 o fechas cruzadas) queda como no apta
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

    // Si da 0 o negativo ya vencio; dejamos diasRestantes en 0 para no mostrar negativos
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

// Ordena las bolsas por vencimiento y manda las vencidas al final
List<UnidadOrdenada> ordenarUnidadesPorVencimiento(
  List<BolsaSangre> bolsas, {
  DateTime? fechaReferencia,
  int diasAlerta = 7,
  bool ascendente = true,
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
    // Las aptas van primero y las vencidas quedan al final
    if (a.esApta != b.esApta) {
      return a.esApta ? -1 : 1;
    }

    // Ordenamos por fecha de vencimiento
    final cmpFecha = soloFecha(a.bolsa.fechaVencimiento)
        .compareTo(soloFecha(b.bolsa.fechaVencimiento));
    if (cmpFecha != 0) return ascendente ? cmpFecha : -cmpFecha;

    // Si vencen el mismo dia, desempatamos por codigo
    return a.bolsa.codigo.compareTo(b.bolsa.codigo);
  });

  return evaluadas;
}
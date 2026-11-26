enum EstadoUnidad {
  disponible('DISPONIBLE'),
  retirada('RETIRADA'),
  enTransito('EN_TRANSITO'),
  enRevision('EN_REVISION');

  const EstadoUnidad(this.valorDb);

  final String valorDb;

  static EstadoUnidad desdeDb(String valor) {
    return EstadoUnidad.values.firstWhere(
      (estado) => estado.valorDb == valor,
      orElse: () =>
          throw FormatException('Estado de unidad desconocido: $valor'),
    );
  }
}

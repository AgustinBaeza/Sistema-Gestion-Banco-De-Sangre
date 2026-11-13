enum TipoSanguineo {
  aPositivo('A+'),
  aNegativo('A-'),
  bPositivo('B+'),
  bNegativo('B-'),
  abPositivo('AB+'),
  abNegativo('AB-'),
  oPositivo('O+'),
  oNegativo('O-');
 
  const TipoSanguineo(this.etiqueta);
  final String etiqueta;
}
 
/// dd/mm/aaaa para mostrar al usuario
String formatearFecha(DateTime d) =>
    "${d.day.toString().padLeft(2, '0')}/"
    "${d.month.toString().padLeft(2, '0')}/"
    "${d.year}";
 
/// aaaa-mm-dd para guardar en SQLite
String fechaIso(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-"
    "${d.month.toString().padLeft(2, '0')}-"
    "${d.day.toString().padLeft(2, '0')}";
 
/// Deja solo el dia, sin hora
DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
 
/// Fecha de hoy a las 00:00
DateTime fechaHoy() => soloFecha(DateTime.now());
 
/// Suma dias de calendario. Se usa en vez de Duration(days: n) porque
/// con el cambio de hora un dia puede durar 23 o 25 horas.
DateTime sumarDias(DateTime d, int dias) =>
    DateTime(d.year, d.month, d.day + dias);
 
class BolsaSangre {
  static const volumenMinMl = 100;
  static const volumenMaxMl = 600;
 
  /// Vida util de los globulos rojos (informe, RF-02)
  static const vidaUtilDias = 42;
 
  /// Letras, numeros y guiones; entre 4 y 20 caracteres
  static final codigoRegex = RegExp(r"^[A-Z0-9-]{4,20}$");
 
  final int id;
  final String codigo;
  final TipoSanguineo tipo;
  final String sede;
  final int volumenMl;
  final DateTime fechaIngreso;
  final DateTime fechaVencimiento;

  BolsaSangre({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.sede,
    required this.volumenMl,
    required this.fechaIngreso,
    required this.fechaVencimiento,
  });

  factory BolsaSangre.fromMap(Map m) => BolsaSangre(
    id: m["id"] as int,
    codigo: m["codigo"] as String,
    tipo: TipoSanguineo.values.byName(m["tipo_sanguineo"] as String),
    sede: m["sede"] as String,
    volumenMl: m["volumen_ml"] as int,
    fechaIngreso: DateTime.parse(m["fecha_ingreso"] as String),
    fechaVencimiento: DateTime.parse(m["fecha_vencimiento"] as String),
  );
}
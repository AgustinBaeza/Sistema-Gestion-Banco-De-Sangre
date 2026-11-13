import "package:flutter/material.dart";
import "../modelos/bolsa_sangre.dart";
 
/// Unidades de un tipo sanguineo en una sede (los datos reales vienen en la 3.3)
class FilaInventario {
  final String sede;
  final TipoSanguineo tipo;
  final int unidades;
 
  const FilaInventario(this.sede, this.tipo, this.unidades);
}
 
/// Datos de ejemplo para ver el diseño; se borran en la tarea 3.3
const inventarioEjemplo = [
  FilaInventario("Concepcion", TipoSanguineo.oPositivo, 14),
  FilaInventario("Concepcion", TipoSanguineo.aPositivo, 9),
  FilaInventario("Concepcion2", TipoSanguineo.oPositivo, 8),
  FilaInventario("Concepcion2", TipoSanguineo.oNegativo, 2),
  FilaInventario("Concepcion3", TipoSanguineo.bPositivo, 5),
];
 
class InventarioPage extends StatelessWidget {
  final List<FilaInventario> filas;
 
  const InventarioPage({super.key, required this.filas});
 
  @override
  Widget build(BuildContext context) {
    final sedes = {for (final f in filas) f.sede}.toList()..sort();
 
    int unidades(TipoSanguineo t, String sede) => filas
        .where((f) => f.tipo == t && f.sede == sede)
        .fold(0, (suma, f) => suma + f.unidades);
 
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(title: const Text("Inventario por tipo sanguineo")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: Colors.white,
            child: filas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text("No hay unidades registradas"),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        const DataColumn(label: Text("Tipo")),
                        for (final s in sedes)
                          DataColumn(label: Text(s), numeric: true),
                        const DataColumn(label: Text("Total"), numeric: true),
                      ],
                      rows: [
                        for (final t in TipoSanguineo.values)
                          DataRow(
                            cells: [
                              DataCell(Text(t.etiqueta)),
                              for (final s in sedes)
                                DataCell(Text("${unidades(t, s)}")),
                              DataCell(
                                Text(
                                  "${sedes.fold(0, (suma, s) => suma + unidades(t, s))}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
 
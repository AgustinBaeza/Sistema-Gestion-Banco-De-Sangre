import "package:flutter/material.dart";
import "../modelos/bolsa_sangre.dart";
import "../modelos/stock_sede.dart";
 
/// Datos de ejemplo para ver el diseño; se borran en la tarea 3.3
final inventarioEjemplo = [
  StockSede(sede: "Concepcion", tipoSanguineo: "oPositivo", cantidad: 14),
  StockSede(sede: "Concepcion", tipoSanguineo: "aPositivo", cantidad: 9),
  StockSede(sede: "Concepcion2", tipoSanguineo: "oPositivo", cantidad: 8),
  StockSede(sede: "Concepcion2", tipoSanguineo: "oNegativo", cantidad: 2),
  StockSede(sede: "Concepcion3", tipoSanguineo: "bPositivo", cantidad: 5),
];
 
class InventarioPage extends StatelessWidget {
  final List<StockSede> filas;
 
  const InventarioPage({super.key, required this.filas});
 
  @override
  Widget build(BuildContext context) {
    final sedes = {for (final f in filas) f.sede}.toList()..sort();
 
    // Acepta el tipo guardado como "oNegativo" o como "O-"
    int cantidad(TipoSanguineo t, String sede) => filas
        .where((f) =>
            f.sede == sede &&
            (f.tipoSanguineo == t.name || f.tipoSanguineo == t.etiqueta))
        .fold(0, (suma, f) => suma + f.cantidad);
 
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
                    child: Text("No hay unidades disponibles"),
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
                                DataCell(Text("${cantidad(t, s)}")),
                              DataCell(
                                Text(
                                  "${sedes.fold(0, (suma, s) => suma + cantidad(t, s))}",
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
import 'package:flutter/material.dart';
import '../modelos/bolsa_sangre.dart';
import '../modelos/stock_sede.dart';

class InventarioPage extends StatefulWidget {
  final List<StockSede> filas;

  const InventarioPage({super.key, required this.filas});

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  // Estados para los dropdowns de los filtros
  String? sedeSeleccionada;
  TipoSanguineo? tipoSeleccionado;

  @override
  Widget build(BuildContext context) {
    // Sacamos las sedes sin repetir y las ordenamos alfabeticamente para el Dropdown
    final todasLasSedes = {for (final f in widget.filas) f.sede}.toList()..sort();

    // Filtramos la lista original segun lo que este seleccionado
    final filasFiltradas = widget.filas.where((f) {
      final cumpleSede = sedeSeleccionada == null || f.sede == sedeSeleccionada;
      final cumpleTipo = tipoSeleccionado == null || 
          f.tipoSanguineo == tipoSeleccionado!.name || 
          f.tipoSanguineo == tipoSeleccionado!.etiqueta;
      return cumpleSede && cumpleTipo;
    }).toList();

    // Si hay un filtro activo, mostramos solo esa sede/tipo. Si no, mostramos todo
    final sedesMostrar = sedeSeleccionada != null ? [sedeSeleccionada!] : todasLasSedes;
    final tiposMostrar = tipoSeleccionado != null ? [tipoSeleccionado!] : TipoSanguineo.values;

    // Suma las cantidades cruzando el tipo de sangre con la sede
    int cantidad(TipoSanguineo t, String sede) => filasFiltradas
        .where((f) =>
            f.sede == sede &&
            (f.tipoSanguineo == t.name || f.tipoSanguineo == t.etiqueta))
        .fold(0, (suma, f) => suma + f.cantidad);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(title: const Text("Inventario por tipo sanguíneo")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta superior con los dropdowns
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Filtrar por:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      DropdownButton<String>(
                        hint: const Text("Todas las sedes"),
                        value: sedeSeleccionada,
                        items: [
                          const DropdownMenuItem(value: null, child: Text("Todas las sedes")),
                          ...todasLasSedes.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (val) => setState(() => sedeSeleccionada = val),
                      ),
                      DropdownButton<TipoSanguineo>(
                        hint: const Text("Todos los tipos"),
                        value: tipoSeleccionado,
                        items: [
                          const DropdownMenuItem(value: null, child: Text("Todos los tipos")),
                          ...TipoSanguineo.values.map((t) => 
                              DropdownMenuItem(value: t, child: Text(t.etiqueta))),
                        ],
                        onChanged: (val) => setState(() => tipoSeleccionado = val),
                      ),
                      // Boton "Limpiar" (solo aparece si hay filtros aplicados)
                      if (sedeSeleccionada != null || tipoSeleccionado != null)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            sedeSeleccionada = null;
                            tipoSeleccionado = null;
                          }),
                          icon: const Icon(Icons.clear, color: Color(0xFFB91C1C)),
                          label: const Text("Limpiar", style: TextStyle(color: Color(0xFFB91C1C))),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // TABLA DE INVENTARIO
              Card(
                color: Colors.white,
                child: filasFiltradas.isEmpty && (sedeSeleccionada != null || tipoSeleccionado != null)
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text("Sin existencias para esta combinación.", 
                                  style: TextStyle(fontSize: 16, color: Colors.grey)),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text("Tipo", style: TextStyle(fontWeight: FontWeight.bold))),
                            for (final s in sedesMostrar)
                              DataColumn(label: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                            const DataColumn(label: Text("Total", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          ],
                          rows: [
                            for (final t in tiposMostrar)
                              DataRow(
                                cells: [
                                  DataCell(Text(t.etiqueta, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  for (final s in sedesMostrar)
                                    DataCell(Text("${cantidad(t, s)}")),
                                  DataCell(
                                    Text(
                                      "${sedesMostrar.fold(0, (suma, s) => suma + cantidad(t, s))}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../modelos/bolsa_sangre.dart';
import '../basedatos/repositorio_bolsa.dart';
import '../modelos/nivel_stock.dart';
import '../modelos/ordenamiento_vencimiento.dart';

class InventarioPage extends StatefulWidget {
  final RepositorioBolsa repo;

  const InventarioPage({super.key, required this.repo});

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  // Estados para los dropdowns de los filtros
  String? sedeSeleccionada;
  TipoSanguineo? tipoSeleccionado;

  // Estados para ordenar por vencimiento y mostrar u ocultar vencidas
  bool ordenMasProximoPrimero = true;
  bool mostrarVencidas = true;

  @override
  Widget build(BuildContext context) {
    final todasLasSedes = widget.repo.sedes();
    // la consulta ya llega filtrada desde la base de datos
    final filas = widget.repo.stockPorSedeYTipo(
      sede: sedeSeleccionada,
      tipo: tipoSeleccionado,
    );

    final unidadesOrdenadas = widget.repo.listarOrdenadasPorVencimiento(
      sede: sedeSeleccionada,
      tipo: tipoSeleccionado,
      ascendente: ordenMasProximoPrimero,
    );
    final unidadesVisibles = mostrarVencidas
        ? unidadesOrdenadas
        : unidadesOrdenadas.where((u) => u.esApta).toList();
    final cantPorVencer = unidadesOrdenadas
        .where((u) => u.estado == EstadoVencimiento.proximaAVencer)
        .length;
    final cantVencidas = unidadesOrdenadas
        .where((u) => u.estado == EstadoVencimiento.vencida)
        .length;

    // Si hay un filtro activo, mostramos solo esa sede/tipo. Si no, mostramos todo
    final sedesMostrar = sedeSeleccionada != null ? [sedeSeleccionada!] : todasLasSedes;
    final tiposMostrar = tipoSeleccionado != null ? [tipoSeleccionado!] : TipoSanguineo.values;

    final celdas = evaluarStock(filas, sedesMostrar, tiposMostrar);
    EvaluacionStock celda(TipoSanguineo t, String s) =>
        celdas.firstWhere((c) => c.tipo == t && c.sede == s);
    List<EvaluacionStock> conNivel(Set<NivelStock> niveles) =>
        celdas.where((c) => niveles.contains(c.nivel)).toList()
          ..sort((a, b) => a.cantidad.compareTo(b.cantidad));

    final hayFiltros = sedeSeleccionada != null || tipoSeleccionado != null;
    const negrita = TextStyle(fontWeight: FontWeight.bold);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(title: const Text("Evaluación de stock")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _tarjeta(Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text("Filtrar por:", style: negrita),
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
                    // Boton "Limpiar"
                    if (hayFiltros)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          sedeSeleccionada = null;
                          tipoSeleccionado = null;
                        }),
                        icon: const Icon(Icons.clear, color: Color(0xFFB91C1C)),
                        label: const Text("Limpiar", style: TextStyle(color: Color(0xFFB91C1C))),
                      ),
                  ],
                )),
                const SizedBox(height: 24),
                if (todasLasSedes.isEmpty)
                  _tarjeta(const Text(
                    "Aún no hay bolsas registradas.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ))
                else ...[
                  Wrap(spacing: 16, runSpacing: 16, children: [
                    _indicador("Unidades vigentes",
                        celdas.fold(0, (s, c) => s + c.cantidad), const Color(0xFF334155)),
                    for (final n in NivelStock.values)
                      if (n != NivelStock.normal)
                        _indicador("Stock ${n.etiqueta.toLowerCase()}",
                            conNivel({n}).length, n.color),
                  ]),
                  const SizedBox(height: 24),
                  // Tabla con cada cantidad coloreada segun su nivel
                  _tarjeta(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final n in NivelStock.values) _insignia(n.etiqueta, n),
                      ]),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text("Tipo", style: negrita)),
                            for (final s in sedesMostrar)
                              DataColumn(label: Text(s, style: negrita), numeric: true),
                            const DataColumn(label: Text("Total", style: negrita), numeric: true),
                          ],
                          rows: [
                            for (final t in tiposMostrar)
                              DataRow(cells: [
                                DataCell(Text(t.etiqueta, style: negrita)),
                                for (final s in sedesMostrar)
                                  DataCell(_insignia("${celda(t, s).cantidad}",
                                      celda(t, s).nivel)),
                                DataCell(Text(
                                  "${sedesMostrar.fold(0, (suma, s) => suma + celda(t, s).cantidad)}",
                                  style: negrita.copyWith(color: const Color(0xFFB91C1C)),
                                )),
                              ]),
                          ],
                        ),
                      ),
                    ],
                  )),
                  const SizedBox(height: 24),
                  // Reporte: que combinaciones faltan y cuales sobran
                  _tarjeta(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Reporte de evaluación",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      Text("Generado el ${formatearFecha(fechaHoy())}",
                          style: const TextStyle(color: Colors.grey)),
                      _seccion("Falta de stock",
                          conNivel({NivelStock.critico, NivelStock.bajo})),
                      _seccion("Abundancia de stock",
                          conNivel({NivelStock.abundante}).reversed.toList()),
                    ],
                  )),
                  const SizedBox(height: 24),
                  // Listado de bolsas ordenado por vencimiento con sus alertas
                  _tarjeta(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Control de vencimiento por unidad",
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _insigniaVencimiento(
                                    "$cantPorVencer por vencer",
                                    EstadoVencimiento.proximaAVencer,
                                  ),
                                  _insigniaVencimiento(
                                    "$cantVencidas vencidas",
                                    EstadoVencimiento.vencida,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DropdownButton<bool>(
                                value: ordenMasProximoPrimero,
                                items: const [
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text("Más próximas a vencer"),
                                  ),
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text("Más lejanas a vencer"),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => ordenMasProximoPrimero = val);
                                  }
                                },
                              ),
                              FilterChip(
                                label: const Text("Mostrar vencidas"),
                                selected: mostrarVencidas,
                                onSelected: (val) => setState(() => mostrarVencidas = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (unidadesVisibles.isEmpty)
                        const Text(
                          "No hay unidades para mostrar con los filtros seleccionados.",
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: unidadesVisibles.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final u = unidadesVisibles[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFEE2E2),
                                child: Text(
                                  u.bolsa.tipo.etiqueta,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                "${u.bolsa.codigo} · ${u.bolsa.sede}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: u.esApta ? const Color(0xFF1E293B) : Colors.grey,
                                ),
                              ),
                              subtitle: Text(
                                "Vence: ${formatearFecha(u.bolsa.fechaVencimiento)} · ${u.detalleEstado}",
                              ),
                              trailing: _insigniaVencimiento(u.estado.etiqueta, u.estado),
                            );
                          },
                        ),
                    ],
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(Widget hijo) => Card(
        color: Colors.white,
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.all(20), child: hijo),
      );

  Widget _indicador(String titulo, int valor, Color color) => SizedBox(
        width: 230,
        child: _tarjeta(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$valor",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            Text(titulo, style: const TextStyle(color: Color(0xFF334155))),
          ],
        )),
      );

  Widget _insignia(String texto, NivelStock n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: n.fondo, borderRadius: BorderRadius.circular(12)),
        child: Text(texto, style: TextStyle(color: n.color, fontWeight: FontWeight.bold)),
      );

  // Colores e iconos segun el estado de vencimiento de cada bolsa
  Widget _insigniaVencimiento(String texto, EstadoVencimiento estado) {
    final (Color colorTexto, Color colorFondo, IconData icono) = switch (estado) {
      EstadoVencimiento.disponible => (
          const Color(0xFF15803D),
          const Color(0xFFDCFCE7),
          Icons.check_circle_outline,
        ),
      EstadoVencimiento.proximaAVencer => (
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7),
          Icons.warning_amber_rounded,
        ),
      EstadoVencimiento.vencida => (
          const Color(0xFFB91C1C),
          const Color(0xFFFEE2E2),
          Icons.block,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: colorTexto),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(color: colorTexto, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, List<EvaluacionStock> celdas) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text("$titulo (${celdas.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
          if (celdas.isEmpty) const Text("Ninguna.", style: TextStyle(color: Colors.grey)),
          for (final c in celdas)
            ListTile(
              dense: true,
              title: Text("${c.tipo.etiqueta} en ${c.sede}"),
              trailing: _insignia("${c.cantidad} · ${c.nivel.etiqueta}", c.nivel),
            ),
        ],
      );
}
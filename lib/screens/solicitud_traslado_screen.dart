import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DatosSolicitudTraslado {
  final String sedeOrigen;
  final String sedeDestino;
  final String tipoSanguineo;
  final int cantidad;
  final int stockMinimo;
  final int stockOptimo;
  final int stockMaximo;
  final int stockDisponibleOrigen;
  final bool notificacionEnviada;

  const DatosSolicitudTraslado({
    required this.sedeOrigen,
    required this.sedeDestino,
    required this.tipoSanguineo,
    required this.cantidad,
    required this.stockMinimo,
    required this.stockOptimo,
    required this.stockMaximo,
    required this.stockDisponibleOrigen,
    this.notificacionEnviada = true,
  });

  /// Excedente por encima del stock mínimo y óptimo para orientar la solicitud
  int get excedenteSobreMinimo =>
      (stockDisponibleOrigen - stockMinimo).clamp(0, stockDisponibleOrigen);

  int get excedenteSobreOptimo =>
      (stockDisponibleOrigen - stockOptimo).clamp(0, stockDisponibleOrigen);
}

class SolicitudTrasladoScreen extends StatefulWidget {
  const SolicitudTrasladoScreen({
    super.key,
    this.sedesDisponibles = const [
      'Sede Central',
      'Sede Norte',
      'Sede Sur',
      'Sede Clínica Regional',
    ],
    this.tiposSanguineos = const [
      'O+',
      'O-',
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
    ],
    this.stockActualPorSedeYTipo = const {},
    this.onEnviarSolicitud,
  });

  final List<String> sedesDisponibles;
  final List<String> tiposSanguineos;

  /// Mapa opcional: "sede|tipo" -> cantidad disponible actual (útil para integrar con StockSede)
  final Map<String, int> stockActualPorSedeYTipo;

  /// Callback para conectar la Task 7.2 (validación en backend/BD y notificación)
  final Future<String?> Function(DatosSolicitudTraslado datos)?
      onEnviarSolicitud;

  @override
  State<SolicitudTrasladoScreen> createState() =>
      _SolicitudTrasladoScreenState();
}

class _SolicitudTrasladoScreenState extends State<SolicitudTrasladoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();

  late String _sedeDestino;
  late String _sedeOrigen;
  late String _tipoSanguineo;

  // Parámetros base de referencia para cálculo de stock mínimo, óptimo y máximo
  int _stockMinimo = 5;
  int _stockOptimo = 12;
  int _stockMaximo = 20;

  bool _enviando = false;
  String? _mensajeEstado;
  bool _esExito = false;

  @override
  void initState() {
    super.initState();
    _sedeDestino = widget.sedesDisponibles.first;
    _sedeOrigen = widget.sedesDisponibles.length > 1
        ? widget.sedesDisponibles[1]
        : widget.sedesDisponibles.first;
    _tipoSanguineo = widget.tiposSanguineos.first;
    _recalcularNivelesReferencia();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  void _recalcularNivelesReferencia() {
    // Regla base clara: mínimo (4 para Rh- críticos, 6 para el resto), óptimo (2.5x mínimo) y máximo (4x mínimo)
    final bool esCritico = _tipoSanguineo.endsWith('-');
    final int baseMin = esCritico ? 4 : 6;
    _stockMinimo = baseMin;
    _stockOptimo = (baseMin * 2.5).round();
    _stockMaximo = baseMin * 4;
  }

  int _obtenerStockSede(String sede) {
    return widget.stockActualPorSedeYTipo['$sede|$_tipoSanguineo'] ?? 0;
  }

  Future<void> _onSubmit() async {
    setState(() {
      _mensajeEstado = null;
      _esExito = false;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _mensajeEstado = 'Revise los campos del formulario antes de enviar.';
        _esExito = false;
      });
      return;
    }

    if (_sedeOrigen == _sedeDestino) {
      setState(() {
        _mensajeEstado =
            'La sede de origen y la sede de destino deben ser distintas.';
        _esExito = false;
      });
      return;
    }

    final int cantidad = int.parse(_cantidadController.text.trim());
    final int stockOrigen = _obtenerStockSede(_sedeOrigen);
    final int excedenteDisponible = (stockOrigen - _stockMinimo).clamp(
      0,
      stockOrigen,
    );

    if (cantidad > excedenteDisponible) {
      setState(() {
        _mensajeEstado =
            'La sede $_sedeOrigen solo tiene $excedenteDisponible unidad(es) de excedente por encima del stock mínimo ($_stockMinimo).';
        _esExito = false;
      });
      return;
    }

    final datos = DatosSolicitudTraslado(
      sedeOrigen: _sedeOrigen,
      sedeDestino: _sedeDestino,
      tipoSanguineo: _tipoSanguineo,
      cantidad: cantidad,
      stockMinimo: _stockMinimo,
      stockOptimo: _stockOptimo,
      stockMaximo: _stockMaximo,
      stockDisponibleOrigen: stockOrigen,
      notificacionEnviada: true,
    );

    setState(() => _enviando = true);

    try {
      String? mensajeExterno;
      if (widget.onEnviarSolicitud != null) {
        mensajeExterno = await widget.onEnviarSolicitud!(datos);
      }

      if (!mounted) return;
      setState(() {
        _esExito = true;
        _mensajeEstado = mensajeExterno ??
            'Solicitud creada: $cantidad unidad(es) de $_tipoSanguineo hacia $_sedeDestino. Se notificó a la sede de origen ($_sedeOrigen).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _esExito = false;
        _mensajeEstado = 'No se pudo procesar la solicitud: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int stockDestino = _obtenerStockSede(_sedeDestino);
    final int stockOrigen = _obtenerStockSede(_sedeOrigen);
    final int excedenteSobreMinimo = (stockOrigen - _stockMinimo).clamp(
      0,
      stockOrigen,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text('Solicitar traslado entre sedes'),
        backgroundColor: const Color(0xFFB91C1C),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nueva solicitud de abastecimiento',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Complete los datos para solicitar unidades a otra sede ante escasez local.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Resumen de niveles mínimo, óptimo y máximo
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Umbrales de referencia ($_tipoSanguineo)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _ChipNivel(
                                  etiqueta: 'Mínimo',
                                  valor: '$_stockMinimo',
                                  color: const Color(0xFFB91C1C),
                                ),
                                _ChipNivel(
                                  etiqueta: 'Óptimo',
                                  valor: '$_stockOptimo',
                                  color: const Color(0xFF15803D),
                                ),
                                _ChipNivel(
                                  etiqueta: 'Máximo',
                                  valor: '$_stockMaximo',
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Stock en destino ($_sedeDestino): $stockDestino  |  '
                              'Stock en origen ($_sedeOrigen): $stockOrigen (Excedente sobre mínimo: $excedenteSobreMinimo)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      DropdownButtonFormField<String>(
                        value: _sedeDestino,
                        decoration: const InputDecoration(
                          labelText: 'Sede solicitante (destino con escasez)',
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: widget.sedesDisponibles
                            .map(
                              (sede) => DropdownMenuItem(
                                value: sede,
                                child: Text(sede),
                              ),
                            )
                            .toList(),
                        onChanged: (valor) {
                          if (valor == null) return;
                          setState(() => _sedeDestino = valor);
                        },
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _sedeOrigen,
                        decoration: const InputDecoration(
                          labelText: 'Sede de origen (abastecedora)',
                          prefixIcon: Icon(Icons.warehouse_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: widget.sedesDisponibles
                            .map(
                              (sede) => DropdownMenuItem(
                                value: sede,
                                child: Text(sede),
                              ),
                            )
                            .toList(),
                        onChanged: (valor) {
                          if (valor == null) return;
                          setState(() => _sedeOrigen = valor);
                        },
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _tipoSanguineo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo sanguíneo',
                          prefixIcon: Icon(Icons.bloodtype_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: widget.tiposSanguineos
                            .map(
                              (tipo) => DropdownMenuItem(
                                value: tipo,
                                child: Text(tipo),
                              ),
                            )
                            .toList(),
                        onChanged: (valor) {
                          if (valor == null) return;
                          setState(() {
                            _tipoSanguineo = valor;
                            _recalcularNivelesReferencia();
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _cantidadController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Cantidad de unidades a solicitar',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingrese la cantidad requerida';
                          }
                          final int? numero = int.tryParse(value.trim());
                          if (numero == null || numero <= 0) {
                            return 'La cantidad debe ser mayor a 0';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            size: 18,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Al crear la solicitud se notificará automáticamente a $_sedeOrigen.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _enviando ? null : _onSubmit,
                          icon: _enviando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _enviando
                                ? 'Enviando solicitud...'
                                : 'Solicitar traslado',
                            style: const TextStyle(fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB91C1C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                      if (_mensajeEstado != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _esExito
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _mensajeEstado!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _esExito
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipNivel extends StatelessWidget {
  const _ChipNivel({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      label: Text(
        '$etiqueta: $valor',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
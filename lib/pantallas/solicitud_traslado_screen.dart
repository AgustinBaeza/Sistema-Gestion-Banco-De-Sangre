import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modelos/bolsa_sangre.dart';

class DatosSolicitudTraslado {
  final String sedeOrigen;
  final String sedeDestino;
  final TipoSanguineo tipoSanguineo;
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

  int get excedenteSobreMinimo =>
      (stockDisponibleOrigen - stockMinimo).clamp(0, stockDisponibleOrigen);

  int get excedenteSobreOptimo =>
      (stockDisponibleOrigen - stockOptimo).clamp(0, stockDisponibleOrigen);
}

class SolicitudTrasladoPage extends StatefulWidget {
  const SolicitudTrasladoPage({
    super.key,
    this.sedesDisponibles = const [
      'Sede Central',
      'Sede Norte',
      'Sede Sur',
      'Concepcion',
    ],
    this.tiposSanguineos = TipoSanguineo.values,
    this.stockActualPorSedeYTipo = const {},
    this.onEnviarSolicitud,
  });

  final List<String> sedesDisponibles;
  final List<TipoSanguineo> tiposSanguineos;

  /// Clave sugerida: "$sede|${tipo.name}" o "$sede|${tipo.etiqueta}"
  final Map<String, int> stockActualPorSedeYTipo;

  final Future<String?> Function(DatosSolicitudTraslado datos)?
      onEnviarSolicitud;

  @override
  State<SolicitudTrasladoPage> createState() => _SolicitudTrasladoPageState();
}

class _SolicitudTrasladoPageState extends State<SolicitudTrasladoPage> {
  static const _rojo = Color(0xFFB91C1C);

  final _formKey = GlobalKey<FormState>();
  final _cantidadCtrl = TextEditingController();

  late String _sedeDestino;
  late String _sedeOrigen;
  late TipoSanguineo _tipoSanguineo;

  int _stockMinimo = 4;
  int _stockOptimo = 10;
  int _stockMaximo = 16;

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
    _cantidadCtrl.dispose();
    super.dispose();
  }

  void _recalcularNivelesReferencia() {
    final bool esRhNegativo = _tipoSanguineo.name.endsWith('Negativo');
    final int baseMin = esRhNegativo ? 4 : 6;
    _stockMinimo = baseMin;
    _stockOptimo = (baseMin * 2.5).round();
    _stockMaximo = baseMin * 4;
  }

  int _obtenerStockSede(String sede) {
    return widget.stockActualPorSedeYTipo['$sede|${_tipoSanguineo.name}'] ??
        widget.stockActualPorSedeYTipo['$sede|${_tipoSanguineo.etiqueta}'] ??
        0;
  }

  Future<void> _onSubmit() async {
    setState(() {
      _mensajeEstado = null;
      _esExito = false;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _mensajeEstado = 'Revisa los campos marcados antes de enviar.';
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

    final int cantidad = int.parse(_cantidadCtrl.text.trim());
    final int stockOrigen = _obtenerStockSede(_sedeOrigen);
    final int excedenteDisponible = (stockOrigen - _stockMinimo).clamp(
      0,
      stockOrigen,
    );

    if (cantidad > excedenteDisponible) {
      setState(() {
        _mensajeEstado =
            'La sede $_sedeOrigen solo tiene $excedenteDisponible unidad(es) '
            'de excedente sobre el stock mínimo ($_stockMinimo).';
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
      final String? mensajeExterno = widget.onEnviarSolicitud != null
          ? await widget.onEnviarSolicitud!(datos)
          : null;

      if (!mounted) return;
      setState(() {
        _esExito = true;
        _mensajeEstado = mensajeExterno ??
            'Solicitud creada: $cantidad unidad(es) de ${_tipoSanguineo.etiqueta} '
                'hacia $_sedeDestino. Se notificó a la sede de origen ($_sedeOrigen).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _esExito = false;
        _mensajeEstado = 'No se pudo procesar la solicitud: $e';
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
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
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nueva solicitud de traslado',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Solicita unidades a otra sede ante escasez local.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Umbrales de referencia (${_tipoSanguineo.etiqueta})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _ChipNivel(
                                  etiqueta: 'Mínimo',
                                  valor: '$_stockMinimo',
                                  color: _rojo,
                                ),
                                _ChipNivel(
                                  etiqueta: 'Óptimo',
                                  valor: '$_stockOptimo',
                                  color: Colors.green.shade700,
                                ),
                                _ChipNivel(
                                  etiqueta: 'Máximo',
                                  valor: '$_stockMaximo',
                                  color: Colors.blue.shade700,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Destino ($_sedeDestino): $stockDestino | '
                              'Origen ($_sedeOrigen): $stockOrigen '
                              '(Excedente mín.: $excedenteSobreMinimo)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _sedeDestino,
                        decoration: const InputDecoration(
                          labelText: 'Sede destino (con escasez) *',
                          border: OutlineInputBorder(),
                        ),
                        items: widget.sedesDisponibles
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _sedeDestino = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _sedeOrigen,
                        decoration: const InputDecoration(
                          labelText: 'Sede origen (abastecedora) *',
                          border: OutlineInputBorder(),
                        ),
                        items: widget.sedesDisponibles
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _sedeOrigen = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<TipoSanguineo>(
                        initialValue: _tipoSanguineo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo sanguíneo *',
                          border: OutlineInputBorder(),
                        ),
                        items: widget.tiposSanguineos
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.etiqueta),
                              ),
                            )
                            .toList(),
                        onChanged: (t) {
                          if (t != null) {
                            setState(() {
                              _tipoSanguineo = t;
                              _recalcularNivelesReferencia();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cantidadCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Cantidad a solicitar *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final texto = (v ?? '').trim();
                          if (texto.isEmpty) {
                            return 'La cantidad es obligatoria';
                          }
                          final n = int.tryParse(texto);
                          if (n == null || n <= 0) {
                            return 'Debe ser mayor a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Se notificará automáticamente a la sede de origen ($_sedeOrigen) al crear la solicitud.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 46,
                        child: FilledButton(
                          onPressed: _enviando ? null : _onSubmit,
                          style: FilledButton.styleFrom(backgroundColor: _rojo),
                          child: Text(
                            _enviando ? 'Enviando...' : 'Solicitar traslado',
                          ),
                        ),
                      ),
                      if (_mensajeEstado != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _esExito
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _mensajeEstado!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _esExito
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
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
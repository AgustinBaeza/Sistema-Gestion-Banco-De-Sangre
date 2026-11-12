import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../basedatos/repositorio_bolsa.dart";
import "../modelos/bolsa_sangre.dart";
 
class FormularioBolsaPage extends StatefulWidget {
  final RepositorioBolsa repo;
 
  const FormularioBolsaPage({super.key, required this.repo});
 
  @override
  State<FormularioBolsaPage> createState() => _FormularioBolsaPageState();
}
 
class _FormularioBolsaPageState extends State<FormularioBolsaPage> {
  static const _rojo = Color(0xFFB91C1C);
 
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _volumenCtrl = TextEditingController();
  final _ingresoCtrl = TextEditingController();
  final _vencimientoCtrl = TextEditingController();
 
  TipoSanguineo? _tipo;
  DateTime? _ingreso;
  DateTime? _vencimiento;
 
  /// Si el usuario eligio el vencimiento a mano ya no se recalcula solo
  bool _vencimientoEditado = false;
 
  @override
  void dispose() {
    _codigoCtrl.dispose();
    _volumenCtrl.dispose();
    _ingresoCtrl.dispose();
    _vencimientoCtrl.dispose();
    super.dispose();
  }
 
  /// Ultimo vencimiento posible: ingreso + vida util (informe, RF-02)
  DateTime _vencimientoMaximo(DateTime ingreso) =>
      sumarDias(ingreso, BolsaSangre.vidaUtilDias);
 
  bool _vencimientoValido(DateTime v, DateTime ingreso) =>
      v.isAfter(ingreso) &&
      v.isAfter(fechaHoy()) &&
      !v.isAfter(_vencimientoMaximo(ingreso));
 
  void _ponerVencimiento(DateTime v) {
    _vencimiento = v;
    _vencimientoCtrl.text = formatearFecha(v);
  }
 
  Future<void> _elegirIngreso() async {
    final hoy = fechaHoy();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _ingreso ?? hoy,
      // Antes de esto la unidad ya estaria vencida
      firstDate: sumarDias(hoy, -(BolsaSangre.vidaUtilDias - 1)),
      lastDate: hoy,
      helpText: "Fecha de ingreso",
    );
    if (elegida == null) return;
    setState(() {
      _ingreso = elegida;
      _ingresoCtrl.text = formatearFecha(elegida);
      // Se sugiere el vencimiento segun la vida util; el usuario lo puede
      // cambiar despues si la etiqueta de la bolsa dice otra fecha
      final actual = _vencimiento;
      if (!_vencimientoEditado ||
          actual == null ||
          !_vencimientoValido(actual, elegida)) {
        _ponerVencimiento(_vencimientoMaximo(elegida));
        _vencimientoEditado = false;
      }
    });
  }
 
  Future<void> _elegirVencimiento() async {
    final ingreso = _ingreso;
    if (ingreso == null) {
      _mensaje("Primero selecciona la fecha de ingreso", error: true);
      return;
    }
    final primera = sumarDias(fechaHoy(), 1);
    final ultima = _vencimientoMaximo(ingreso);
    final actual = _vencimiento;
    final elegida = await showDatePicker(
      context: context,
      initialDate:
          actual != null && !actual.isBefore(primera) && !actual.isAfter(ultima)
          ? actual
          : ultima,
      firstDate: primera,
      lastDate: ultima,
      helpText: "Fecha de vencimiento",
    );
    if (elegida == null) return;
    setState(() {
      _ponerVencimiento(elegida);
      _vencimientoEditado = true;
    });
  }
 
  String? _validarVencimiento(String? _) {
    final v = _vencimiento;
    if (v == null) return "Selecciona la fecha de vencimiento";
    final ingreso = _ingreso;
    if (ingreso != null && !v.isAfter(ingreso)) {
      return "Debe ser posterior a la fecha de ingreso";
    }
    if (!v.isAfter(fechaHoy())) return "La unidad ya esta vencida";
    if (ingreso != null && v.isAfter(_vencimientoMaximo(ingreso))) {
      return "No puede superar ${BolsaSangre.vidaUtilDias} dias desde el ingreso";
    }
    return null;
  }
 
  void _mensaje(String texto, {bool error = false}) {
    final colores = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? colores.error : null,
      ),
    );
  }
 
  void _limpiar() {
    _codigoCtrl.clear();
    _volumenCtrl.clear();
    _ingresoCtrl.clear();
    _vencimientoCtrl.clear();
    _formKey.currentState!.reset();
    setState(() {
      _tipo = null;
      _ingreso = null;
      _vencimiento = null;
      _vencimientoEditado = false;
    });
  }
 
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      _mensaje("Revisa los campos marcados antes de guardar", error: true);
      return;
    }
 
    try {
      final bolsa = await widget.repo.crear(
        codigo: _codigoCtrl.text,
        tipo: _tipo!,
        volumenMl: int.parse(_volumenCtrl.text),
        fechaIngreso: _ingreso!,
        fechaVencimiento: _vencimiento!,
      );
      // Despues de un await la pantalla pudo haberse cerrado
      if (!mounted) return;
      // Se queda en el formulario para registrar varias unidades seguidas
      _limpiar();
      _mensaje("Bolsa ${bolsa.codigo} registrada correctamente");
    } on StateError catch (e) {
      if (!mounted) return;
      _mensaje(e.message, error: true);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      _mensaje(e.message.toString(), error: true);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
 
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(title: const Text("Ingreso de bolsa de sangre")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              color: Colors.white,
              elevation: 2,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Datos de la unidad", style: texto.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      "Los campos con * son obligatorios",
                      style: texto.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _codigoCtrl,
                            decoration: const InputDecoration(
                              labelText: "Codigo identificador *",
                              hintText: "Ej: BS-2026-0001",
                              helperText:
                                  "4 a 20 caracteres: letras, numeros y guiones",
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r"[A-Za-z0-9-]"),
                              ),
                              TextInputFormatter.withFunction(
                                (_, nuevo) => nuevo.copyWith(
                                  text: nuevo.text.toUpperCase(),
                                ),
                              ),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            validator: (v) {
                              final t = (v ?? "").trim();
                              if (t.isEmpty) return "El codigo es obligatorio";
                              if (!BolsaSangre.codigoRegex.hasMatch(t)) {
                                return "Usa entre 4 y 20 caracteres (A-Z, 0-9, -)";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<TipoSanguineo>(
                            decoration: const InputDecoration(
                              labelText: "Tipo sanguineo *",
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final t in TipoSanguineo.values)
                                DropdownMenuItem(
                                  value: t,
                                  child: Text(t.etiqueta),
                                ),
                            ],
                            onChanged: (t) => _tipo = t,
                            validator: (t) => t == null
                                ? "Selecciona un tipo sanguineo"
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _volumenCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Volumen (mL) *",
                              hintText: "Ej: 450",
                              helperText:
                                  "Entre ${BolsaSangre.volumenMinMl} y "
                                  "${BolsaSangre.volumenMaxMl} mL",
                              suffixText: "mL",
                              border: const OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            validator: (v) {
                              final t = (v ?? "").trim();
                              if (t.isEmpty) return "El volumen es obligatorio";
                              final n = int.tryParse(t);
                              if (n == null) return "Ingresa solo numeros";
                              if (n < BolsaSangre.volumenMinMl ||
                                  n > BolsaSangre.volumenMaxMl) {
                                return "Debe estar entre "
                                    "${BolsaSangre.volumenMinMl} y "
                                    "${BolsaSangre.volumenMaxMl} mL";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _ingresoCtrl,
                            readOnly: true,
                            onTap: _elegirIngreso,
                            decoration: const InputDecoration(
                              labelText: "Fecha de ingreso *",
                              hintText: "dd/mm/aaaa",
                              suffixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                            validator: (_) => _ingreso == null
                                ? "Selecciona la fecha de ingreso"
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _vencimientoCtrl,
                            readOnly: true,
                            onTap: _elegirVencimiento,
                            decoration: const InputDecoration(
                              labelText: "Fecha de vencimiento *",
                              hintText: "dd/mm/aaaa",
                              helperText:
                                  "Se sugiere ingreso + "
                                  "${BolsaSangre.vidaUtilDias} dias; "
                                  "corrigela si la etiqueta dice otra",
                              helperMaxLines: 2,
                              suffixIcon: Icon(Icons.event_busy),
                              border: OutlineInputBorder(),
                            ),
                            validator: _validarVencimiento,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _limpiar,
                                  child: const Text("Limpiar"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _guardar,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _rojo,
                                  ),
                                  child: const Text("Guardar bolsa"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
 
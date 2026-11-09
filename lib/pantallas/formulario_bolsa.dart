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
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _volumenCtrl = TextEditingController();
  final _ingresoCtrl = TextEditingController();
  final _vencimientoCtrl = TextEditingController();

  TipoSanguineo? _tipo;
  DateTime? _ingreso;
  DateTime? _vencimiento;
  late List<BolsaSangre> _bolsas;

  @override
  void initState() {
    super.initState();
    _bolsas = widget.repo.listar();
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _volumenCtrl.dispose();
    _ingresoCtrl.dispose();
    _vencimientoCtrl.dispose();
    super.dispose();
  }

  DateTime get _hoy {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _elegirIngreso() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _ingreso ?? _hoy,
      firstDate: _hoy.subtract(const Duration(days: 365)),
      lastDate: _hoy,
      helpText: "Fecha de ingreso",
    );
    if (elegida == null) return;
    setState(() {
      _ingreso = elegida;
      _ingresoCtrl.text = formatearFecha(elegida);
      // Si el vencimiento ya no es valido, se borra para que lo vuelva a elegir
      if (_vencimiento != null && !_vencimiento!.isAfter(elegida)) {
        _vencimiento = null;
        _vencimientoCtrl.clear();
      }
    });
  }

  Future<void> _elegirVencimiento() async {
    final primera = (_ingreso ?? _hoy).add(const Duration(days: 1));
    final elegida = await showDatePicker(
      context: context,
      initialDate: _vencimiento ?? primera,
      firstDate: primera,
      lastDate: _hoy.add(const Duration(days: 365 * 2)),
      helpText: "Fecha de vencimiento",
    );
    if (elegida == null) return;
    setState(() {
      _vencimiento = elegida;
      _vencimientoCtrl.text = formatearFecha(elegida);
    });
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
    });
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) {
      _mensaje("Revisa los campos marcados antes de guardar", error: true);
      return;
    }

    try {
      final bolsa = widget.repo.crear(
        codigo: _codigoCtrl.text,
        tipo: _tipo!,
        volumenMl: int.parse(_volumenCtrl.text),
        fechaIngreso: _ingreso!,
        fechaVencimiento: _vencimiento!,
      );
      _limpiar();
      setState(() => _bolsas = widget.repo.listar());
      _mensaje("Bolsa ${bolsa.codigo} registrada correctamente");
    } on StateError catch (e) {
      _mensaje(e.message, error: true);
    } on ArgumentError catch (e) {
      _mensaje(e.message.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Ingreso de bolsa de sangre")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
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
                              "4 a 20 caracteres: letras, números y guiones",
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[A-Za-z0-9-]"),
                          ),
                          TextInputFormatter.withFunction(
                            (_, nuevo) =>
                                nuevo.copyWith(text: nuevo.text.toUpperCase()),
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
                            DropdownMenuItem(value: t, child: Text(t.etiqueta)),
                        ],
                        onChanged: (t) => _tipo = t,
                        validator: (t) =>
                            t == null ? "Selecciona un tipo sanguineo" : null,
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
                            return "Debe estar entre ${BolsaSangre.volumenMinMl} "
                                "y ${BolsaSangre.volumenMaxMl} mL";
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
                          suffixIcon: Icon(Icons.event_busy),
                          border: OutlineInputBorder(),
                        ),
                        validator: (_) {
                          if (_vencimiento == null) {
                            return "Selecciona la fecha de vencimiento";
                          }
                          if (_ingreso != null &&
                              !_vencimiento!.isAfter(_ingreso!)) {
                            return "Debe ser posterior a la fecha de ingreso";
                          }
                          return null;
                        },
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
                              child: const Text("Guardar bolsa"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Bolsas registradas (${_bolsas.length})",
                  style: texto.titleMedium,
                ),
                const Divider(),
                if (_bolsas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text("Aún no hay bolsas registradas"),
                  ),
                for (final b in _bolsas)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(b.tipo.etiqueta)),
                    title: Text(b.codigo),
                    subtitle: Text(
                      "${b.volumenMl} mL · Ingreso ${formatearFecha(b.fechaIngreso)} "
                      "· Vence ${formatearFecha(b.fechaVencimiento)}",
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

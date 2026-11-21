import 'package:flutter/material.dart';

import '../basedatos/repositorio_bolsa.dart';
import '../modelos/bolsa_sangre.dart';

class FormularioRetiroPage extends StatefulWidget {
  final RepositorioBolsa repo;

  const FormularioRetiroPage({super.key, required this.repo});

  @override
  State<FormularioRetiroPage> createState() => _FormularioRetiroPageState();
}

class _FormularioRetiroPageState extends State<FormularioRetiroPage> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();

  String? _error;
  BolsaSangre? _bolsaEncontrada;

  final List<String> _motivos = [
    'Uso de unidad',
    'Vencimiento',
    'Descarte',
    'Otro motivo operativo',
  ];

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  void _limpiarResultado() {
    setState(() {
      _bolsaEncontrada = null;
      _error = null;
    });
  }

  void _validarUnidad() {
    _limpiarResultado();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final codigo = _codigoCtrl.text.trim().toUpperCase();

    // Se utiliza el repositorio existente de la US2.
    final bolsas = widget.repo.listar();

    BolsaSangre? encontrada;

    for (final bolsa in bolsas) {
      if (bolsa.codigo.toUpperCase() == codigo) {
        encontrada = bolsa;
        break;
      }
    }

    if (encontrada == null) {
      setState(() {
        _error = 'No existe una unidad con ese código.';
      });
      return;
    }

    setState(() {
      _bolsaEncontrada = encontrada;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retiro de unidades de sangre')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Identificar unidad a retirar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _codigoCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Código de la unidad *',
                          hintText: 'Ej: BS-2026-0001',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _limpiarResultado(),
                        validator: (valor) {
                          final codigo = (valor ?? '').trim().toUpperCase();

                          if (codigo.isEmpty) {
                            return 'Ingresa el código de la unidad';
                          }

                          if (!BolsaSangre.codigoRegex.hasMatch(codigo)) {
                            return 'Usa entre 4 y 20 caracteres: '
                                'letras, números y guiones';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Motivo del retiro *',
                          border: OutlineInputBorder(),
                        ),
                        items: _motivos
                            .map(
                              (motivo) => DropdownMenuItem<String>(
                                value: motivo,
                                child: Text(motivo),
                              ),
                            )
                            .toList(),

                        onChanged: (valor) {
                          setState(() {
                            _bolsaEncontrada = null;
                            _error = null;
                          });
                        },

                        validator: (valor) {
                          if (valor == null) {
                            return 'Selecciona un motivo';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      FilledButton(
                        onPressed: _validarUnidad,
                        child: const Text('Verificar unidad'),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],

                      if (_bolsaEncontrada != null) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const Text(
                          'Unidad encontrada',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Código: ${_bolsaEncontrada!.codigo}'),
                        Text('Tipo: ${_bolsaEncontrada!.tipo.etiqueta}'),
                        Text('Sede: ${_bolsaEncontrada!.sede}'),
                        Text(
                          'Volumen: '
                          '${_bolsaEncontrada!.volumenMl} mL',
                        ),
                        Text(
                          'Vencimiento: '
                          '${formatearFecha(_bolsaEncontrada!.fechaVencimiento)}',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Unidad localizada. Su estado de retiro '
                          'se verificará al integrar la Task 5.2.',
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Text(
                        'Esta pantalla todavía no registra el retiro. '
                        'La actualización del inventario y el '
                        'almacenamiento del motivo corresponden '
                        'a la Task 5.2.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
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

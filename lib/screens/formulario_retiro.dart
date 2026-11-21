import 'package:flutter/material.dart';
import '../modelos/bolsa_sangre.dart';

class FormularioRetiroPage extends StatefulWidget {
  const FormularioRetiroPage({super.key});

  @override
  State<FormularioRetiroPage> createState() => _FormularioRetiroPageState();
}

class _FormularioRetiroPageState extends State<FormularioRetiroPage> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  void _validarCodigo() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Formato correcto. La búsqueda de la unidad está pendiente.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retiro de unidades de sangre')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Identificar unidad a retirar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _codigoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código de la unidad',
                      hintText: 'Ej: BS-2026-0001',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      final codigo = (valor ?? '').trim();

                      if (codigo.isEmpty) {
                        return 'Ingresa el código de la unidad';
                      }

                      if (!BolsaSangre.codigoRegex.hasMatch(codigo)) {
                        return 'Código inválido: utiliza de 4 a 20 caracteres';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _validarCodigo,
                    child: const Text('Validar código'),
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

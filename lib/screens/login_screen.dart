import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _mostrarContrasena = false;
  String? _mensaje;

  void _mostrarAviso() {
    setState(() {
      _mensaje = 'La autenticación todavía no está disponible.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: Colors.white,
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0xFFFDE8E8),
                      child: Icon(
                        Icons.bloodtype,
                        size: 44,
                        color: Color(0xFFB91C1C),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Banco de Sangre',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Sistema de Gestión de Unidades de Sangre',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 20),

                    const Text(
                      'Acceso al sistema',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      obscureText: !_mostrarContrasena,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _mostrarContrasena
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _mostrarContrasena = !_mostrarContrasena;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _mostrarAviso,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB91C1C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Iniciar sesión',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    if (_mensaje != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _mensaje!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    const Text(
                      'Acceso exclusivo para personal autorizado',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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

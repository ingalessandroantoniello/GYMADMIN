import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dashboard_screen.dart';
import '../helpers.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  void _intentarLogin(BuildContext context) async {
    var boxUsuarios = Hive.box('usuariosBox');
    String userText = _userController.text.trim();
    String passText = _passController.text.trim();

    Map<String, dynamic>? usuarioEncontrado;

    for (var key in boxUsuarios.keys) {
      var u = boxUsuarios.get(key);
      if (u != null) {
        var mapU = Map<String, dynamic>.from(u as Map);
        if (mapU['usuario'].toString().trim().toLowerCase() == userText.toLowerCase() && 
            mapU['password'].toString().trim() == passText) {
          usuarioEncontrado = mapU;
          break;
        }
      }
    }

    if (usuarioEncontrado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario o contraseña incorrectos'), backgroundColor: Colors.red),
      );
      return;
    }

    bool esAdmin = usuarioEncontrado['rol'] == 'Administrador';
    List<String> sedesPermitidas = esAdmin 
        ? ['sevilla', 'terepaima', 'metropolis', 'trinitarias'] 
        : List<String>.from(usuarioEncontrado['sedesPermitidas'] ?? ['sevilla']);

    if (sedesPermitidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este usuario no tiene sedes asignadas.'), backgroundColor: Colors.orange),
      );
      return;
    }

    String sedeSeleccionada = sedesPermitidas.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (contextDialog) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Seleccione la Sede de Trabajo'),
              content: DropdownButtonFormField<String>(
                initialValue: sedeSeleccionada,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: sedesPermitidas.map((sede) {
                  return DropdownMenuItem(
                    value: sede,
                    child: Text('Sede: ${sede.toUpperCase()}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => sedeSeleccionada = val);
                  }
                },
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () async {
                    var configBox = Hive.box('configBox');
                    await configBox.put('sede_activa', sedeSeleccionada);

                    usuarioEncontrado!['sedeId'] = sedeSeleccionada;

                    // ABRIR TODAS LAS CAJAS AQUÍ PARA QUE ESTÉN DISPONIBLES EN TODA LA APP
                    await Hive.openBox(obtenerNombreBoxSede('clientsBox'));
                    await Hive.openBox(obtenerNombreBoxSede('ventasBox'));
                    await Hive.openBox(obtenerNombreBoxSede('accesosBox'));
                    await Hive.openBox(obtenerNombreBoxSede('inventarioBox')); // <-- INVENTARIO AÑADIDO
                    
                    await Hive.openBox('batidosMenuBox'); 
                    await Hive.openBox('ventasBatidosBox'); 

                    if (contextDialog.mounted) {
                      Navigator.pop(contextDialog);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DashboardScreen(usuarioActual: usuarioEncontrado!),
                        ),
                      );
                    }
                  },
                  child: const Text('Entrar a la Sede'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'GymAdmin',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    onPressed: () => _intentarLogin(context),
                    child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
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
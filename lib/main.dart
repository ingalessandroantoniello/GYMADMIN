import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 1. Abrir cajas globales esenciales
  await Hive.openBox('usuariosBox');
  await Hive.openBox('configBox');
  await Hive.openBox('inventarioBox');

  // 2. Abrir preventivamente todas las cajas de las sedes y sus módulos
  List<String> sedes = ['sevilla', 'terepaima', 'metropolis', 'trinitarias'];
  List<String> modulos = ['ventasBox', 'clientesBox', 'accesosBox'];

  for (var sede in sedes) {
    for (var modulo in modulos) {
      String nombreBox = '${modulo}_$sede';
      if (!Hive.isBoxOpen(nombreBox)) {
        await Hive.openBox(nombreBox);
      }
    }
  }

  // 3. Asegurar usuario Administrador con clave gala2026
  var boxUsuarios = Hive.box('usuariosBox');
  await boxUsuarios.put('admin_1', {
    'id': 'admin_1',
    'nombre': 'Administrador General',
    'usuario': 'admin',
    'password': 'gala2026',
    'rol': 'Administrador',
    'sedesPermitidas': ['sevilla', 'terepaima', 'metropolis', 'trinitarias']
  });

  // 4. Asegurar empleados por defecto
  if (!boxUsuarios.containsKey('user_sevilla')) {
    await boxUsuarios.put('user_sevilla', {'id': 'user_sevilla', 'nombre': 'Cajero Sevilla', 'usuario': 'sevilla', 'password': '123', 'rol': 'Empleado', 'sedesPermitidas': ['sevilla']});
    await boxUsuarios.put('user_terepaima', {'id': 'user_terepaima', 'nombre': 'Cajero Terepaima', 'usuario': 'terepaima', 'password': '123', 'rol': 'Empleado', 'sedesPermitidas': ['terepaima']});
    await boxUsuarios.put('user_metropolis', {'id': 'user_metropolis', 'nombre': 'Cajero Metrópolis', 'usuario': 'metropolis', 'password': '123', 'rol': 'Empleado', 'sedesPermitidas': ['metropolis']});
    await boxUsuarios.put('user_trinitarias', {'id': 'user_trinitarias', 'nombre': 'Cajero Trinitarias', 'usuario': 'trinitarias', 'password': '123', 'rol': 'Empleado', 'sedesPermitidas': ['trinitarias']});
  }

  // 5. Configurar sede y tasa USD por defecto si no existen
  var configBox = Hive.box('configBox');
  if (!configBox.containsKey('tasa_usd')) {
    await configBox.put('tasa_usd', 36.50);
  }
  if (!configBox.containsKey('sede_activa')) {
    await configBox.put('sede_activa', 'sevilla');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GymAdmin',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}
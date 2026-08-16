import 'package:hive_flutter/hive_flutter.dart';

// Obtiene la sede activa globalmente desde la caja de configuración
String obtenerSedeActual() {
  try {
    var configBox = Hive.box('configBox');
    return configBox.get('sede_activa', defaultValue: 'sevilla');
  } catch (e) {
    return 'sevilla';
  }
}

// Genera el nombre de la caja combinando la base y la sede activa (ej: clientesBox_sevilla)
String obtenerNombreBoxSede(String nombreBase) {
  String sedeId = obtenerSedeActual();
  return '${nombreBase}_$sedeId';
}

// Abre o recupera la caja de manera segura
Future<Box> obtenerBoxSeguro(String nombreBase) async {
  String nombreCompleto = obtenerNombreBoxSede(nombreBase);
  if (Hive.isBoxOpen(nombreCompleto)) {
    return Hive.box(nombreCompleto);
  } else {
    return await Hive.openBox(nombreCompleto);
  }
}
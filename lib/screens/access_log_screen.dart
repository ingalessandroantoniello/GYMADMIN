import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../helpers.dart'; 

class AccessLogScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioActual;

  const AccessLogScreen({super.key, required this.usuarioActual});

  @override
  State<AccessLogScreen> createState() => _AccessLogScreenState();
}

class _AccessLogScreenState extends State<AccessLogScreen> {
  
  // Decodificador de imágenes a prueba de balas para evitar crashes
  Uint8List? _obtenerImagenSegura(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;
    try {
      String cleanString = base64String;
      // Remueve cabeceras si las tiene (ej. data:image/png;base64,)
      if (base64String.contains(',')) {
        cleanString = base64String.split(',').last;
      }
      // Limpia espacios en blanco
      cleanString = cleanString.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(cleanString);
    } catch (e) {
      return null; // Si el dato está corrupto, muestra el ícono por defecto sin crashear
    }
  }

  @override
  Widget build(BuildContext context) {
    String boxAccesosNombre = obtenerNombreBoxSede('accesosBox');
    String boxClientesNombre = obtenerNombreBoxSede('clientsBox');

    // Validación de seguridad vital: Si la caja no está abierta, no intentamos dibujarla
    if (!Hive.isBoxOpen(boxAccesosNombre) || !Hive.isBoxOpen(boxClientesNombre)) {
      return const Center(
        child: Text('Sincronizando accesos de la sede...', style: TextStyle(color: Colors.white, fontSize: 16)),
      );
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            alignment: Alignment.centerLeft,
            child: const Text('Control de Acceso', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const Divider(color: Colors.white24, height: 1),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // --- TARJETA DINÁMICA CON FOTO GRANDE ---
                  ValueListenableBuilder(
                    valueListenable: Hive.box(boxAccesosNombre).listenable(),
                    builder: (context, boxAccesos, _) {
                      final listaAccesos = boxAccesos.values.toList();
                      if (listaAccesos.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(10)),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("ESPERANDO...", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Icon(Icons.fingerprint, size: 36, color: Colors.white70),
                              SizedBox(height: 4),
                              Text('Esperando entrada...', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        );
                      }

                      final ultimoAcceso = Map<String, dynamic>.from(listaAccesos.last as Map);
                      final String? clienteId = ultimoAcceso['clienteId']?.toString();
                      
                      final cliente = clienteId != null ? Hive.box(boxClientesNombre).get(clienteId) : null;
                      if (cliente == null) return const SizedBox();

                      final c = Map<String, dynamic>.from(cliente as Map);
                      bool aprobado = ultimoAcceso['estado'] == 'ACCESO PERMITIDO';
                      
                      // Usamos la función segura para evitar crashes
                      Uint8List? fotoBytes = _obtenerImagenSegura(c['fotoBase64']);
                      bool tieneFoto = fotoBytes != null;

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: aprobado ? Colors.green.shade700 : Colors.red.shade700,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ultimoAcceso['estado'] ?? 'DESCONOCIDO', 
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            
                            // FOTO GRANDE
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              backgroundImage: tieneFoto ? MemoryImage(fotoBytes) : null,
                              child: tieneFoto ? null : const Icon(Icons.person, size: 55, color: Colors.grey),
                            ),
                            
                            const SizedBox(height: 10),
                            Text(
                              "${c['nombre'] ?? 'Sin nombre'} ${c['apellido'] ?? ''}", 
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), 
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Cédula: ${c['cedula'] ?? 'N/D'}", 
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Vence: ${c['fechaVencimiento']?.toString().isEmpty ?? true ? 'Sin fecha' : c['fechaVencimiento']}",
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Entradas de Hoy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                  ),
                  const SizedBox(height: 4),

                  // --- HISTORIAL COMPLETO DE ENTRADAS ---
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: Hive.box(boxAccesosNombre).listenable(),
                      builder: (context, boxAccesos, _) {
                        final hoy = DateTime.now();
                        final fechaHoy = "${hoy.day.toString().padLeft(2,'0')}/${hoy.month.toString().padLeft(2,'0')}/${hoy.year}";

                        final listaHoy = boxAccesos.values
                            .map((e) => Map<String, dynamic>.from(e as Map))
                            .where((acceso) => acceso['fecha'] == fechaHoy)
                            .toList()
                            .reversed
                            .toList();

                        if (listaHoy.isEmpty) {
                          return const Center(child: Text('Sin entradas hoy.', style: TextStyle(fontSize: 10, color: Colors.grey)));
                        }

                        return ListView.builder(
                          itemCount: listaHoy.length,
                          itemBuilder: (context, index) {
                            final acceso = listaHoy[index];
                            final clienteReg = acceso['clienteId'] != null 
                                ? Hive.box(boxClientesNombre).get(acceso['clienteId']) 
                                : null;
                                
                            String nombreMostrar = acceso['nombre'] ?? 'Desconocido';
                            String cedulaMostrar = acceso['cedula'] ?? '-';

                            if (clienteReg != null) {
                              final cl = Map<String, dynamic>.from(clienteReg as Map);
                              nombreMostrar = "${cl['nombre']} ${cl['apellido'] ?? ''}";
                              cedulaMostrar = cl['cedula'] ?? '-';
                            }

                            bool aprobado = acceso['estado'] == 'ACCESO PERMITIDO';
                            
                            return SizedBox(
                              height: 44,
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                                child: Center(
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    leading: Icon(aprobado ? Icons.check_circle : Icons.cancel, color: aprobado ? Colors.green : Colors.red, size: 14),
                                    title: Text(nombreMostrar, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), overflow: TextOverflow.ellipsis),
                                    subtitle: Text('C.I: $cedulaMostrar', style: const TextStyle(fontSize: 9)),
                                    trailing: Text(acceso['hora'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
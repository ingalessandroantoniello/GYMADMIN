import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../helpers.dart';
import 'login_screen.dart'; // Importado para el cierre de sesión
import 'clients_screen.dart';
import 'daily_sales_screen.dart';
import 'access_log_screen.dart';
import 'inventory_screen.dart';
import 'batidos_screen.dart';
import 'reports_screen.dart';
import 'user_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioActual;

  const DashboardScreen({super.key, required this.usuarioActual});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String? _globalSelectedClientId;
  Timer? _ratesTimer;

  @override
  void initState() {
    super.initState();
    _actualizarTasasBCV();
    _ratesTimer = Timer.periodic(const Duration(hours: 1), (_) => _actualizarTasasBCV());
  }

  @override
  void dispose() {
    _ratesTimer?.cancel();
    super.dispose();
  }

  Future<void> _actualizarTasasBCV() async {
    try {
      final client = HttpClient();
      final reqUsd = await client.getUrl(Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial'));
      final resUsd = await reqUsd.close();
      final strUsd = await resUsd.transform(utf8.decoder).join();
      final jsonUsd = jsonDecode(strUsd);
      
      final reqEur = await client.getUrl(Uri.parse('https://ve.dolarapi.com/v1/euros/oficial'));
      final resEur = await reqEur.close();
      final strEur = await resEur.transform(utf8.decoder).join();
      final jsonEur = jsonDecode(strEur);

      var configBox = Hive.box('configBox');
      if(jsonUsd['promedio'] != null) await configBox.put('tasa_usd', (jsonUsd['promedio'] as num).toDouble());
      if(jsonEur['promedio'] != null) await configBox.put('tasa_eur', (jsonEur['promedio'] as num).toDouble());
    } catch (e) {
      debugPrint("Error obteniendo tasas BCV: $e");
    }
  }

  Widget _buildTopStatsBar(String boxName) {
    return ValueListenableBuilder(
      valueListenable: Hive.box(boxName).listenable(),
      builder: (context, Box box, _) {
        int total = 0, activos = 0, vencidos = 0, cortesia = 0;
        final hoy = DateTime.now();
        final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);

        for (var value in box.values) {
          final c = Map<String, dynamic>.from(value as Map);
          total++;
          bool esCortesia = c['cortesia'] == true || c['tipo'] == 'Cortesía' || c['estado'] == 'Cortesía';
          if (esCortesia) {
            cortesia++;
          } else {
            String fVencimiento = c['fechaVencimiento']?.toString() ?? '';
            if (fVencimiento.isNotEmpty && fVencimiento.contains('/')) {
              try {
                var parts = fVencimiento.split('/');
                DateTime vDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                if (vDate.isBefore(hoyDate)) vencidos++;
                else activos++;
              } catch (e) { vencidos++; }
            } else {
              vencidos++;
            }
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: Colors.blue.shade800, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(title: 'TOTAL CLIENTES', count: total, color: Colors.white),
              _StatItem(title: 'ACTIVOS', count: activos, color: Colors.greenAccent),
              _StatItem(title: 'VENCIDOS', count: vencidos, color: Colors.redAccent),
              _StatItem(title: 'CORTESÍAS', count: cortesia, color: Colors.orangeAccent),
            ],
          ),
        );
      },
    );
  }

  // --- PANEL DE ENTRADAS EN VIVO ACTUALIZADO ---
  Widget _buildLiveFeedPanel(String boxAccesosNombre, String boxClientesNombre) {
    return Container(
      width: 260,
      color: Colors.blueGrey.shade50,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.blue.shade900,
            child: const Text('ENTRADAS EN VIVO', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box(boxAccesosNombre).listenable(),
              builder: (context, Box boxAccesos, _) {
                if (boxAccesos.isEmpty) {
                  return const Center(child: Text('Sin entradas recientes', style: TextStyle(color: Colors.grey)));
                }

                final hoy = DateTime.now();
                final fechaHoy = "${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}";
                
                var accesosHoy = boxAccesos.values
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .where((a) => a['fecha'] == fechaHoy)
                    .toList()
                    .reversed
                    .toList();

                if (accesosHoy.isEmpty) {
                  return const Center(child: Text('Sin entradas el día de hoy', style: TextStyle(color: Colors.grey)));
                }

                var boxClientes = Hive.box(boxClientesNombre);
                List<dynamic> clientesKeys = boxClientes.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 10),
                  itemCount: accesosHoy.length,
                  itemBuilder: (context, index) {
                    var acceso = accesosHoy[index];
                    bool accesoPermitido = acceso['estado'] == 'ACCESO PERMITIDO';
                    
                    String? clienteId = acceso['clienteId'];
                    Map<String, dynamic>? clienteData;
                    int numCliente = 0;

                    if (clienteId != null && boxClientes.containsKey(clienteId)) {
                      clienteData = Map<String, dynamic>.from(boxClientes.get(clienteId) as Map);
                      numCliente = clientesKeys.indexOf(clienteId) + 1;
                    }

                    String nombre = acceso['nombre'] ?? 'Desconocido';
                    String cedula = acceso['cedula'] ?? (clienteData?['cedula'] ?? 'N/A');
                    String fechaVence = clienteData?['fechaVencimiento'] ?? 'Sin Membresía';
                    String hora = acceso['hora'] ?? '';

                    Uint8List? foto;
                    if (clienteData != null && clienteData['fotoBase64'] != null) {
                      try {
                        String base64String = clienteData['fotoBase64'];
                        String cleanString = base64String.contains(',') ? base64String.split(',').last : base64String;
                        foto = base64Decode(cleanString.replaceAll(RegExp(r'\s+'), ''));
                      } catch (_) {}
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accesoPermitido ? Colors.green : Colors.red, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: foto != null ? MemoryImage(foto) : null,
                              child: foto == null ? const Icon(Icons.person, color: Colors.grey) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'C.I: $cedula | N° $numCliente', 
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800)
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Vence: $fechaVence', 
                                    style: TextStyle(
                                      fontSize: 11, 
                                      fontWeight: FontWeight.bold, 
                                      color: accesoPermitido ? Colors.green.shade700 : Colors.red.shade700
                                    )
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Hora: $hora', 
                                    style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Icon(
                                accesoPermitido ? Icons.check_circle : Icons.cancel,
                                color: accesoPermitido ? Colors.green : Colors.red,
                                size: 26,
                              ),
                            ),
                          ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    String sedeActual = obtenerSedeActual().toUpperCase();
    String boxClientesNombre = obtenerNombreBoxSede('clientsBox');
    String boxAccesosNombre = obtenerNombreBoxSede('accesosBox');

    final List<Widget> pantallas = [
      const _ContenidoDashboard(),
      ClientsScreen(usuarioActual: widget.usuarioActual, clienteIdSeleccionado: _globalSelectedClientId), 
      DailySalesScreen(usuarioActual: widget.usuarioActual),
      AccessLogScreen(usuarioActual: widget.usuarioActual),
      InventoryScreen(usuarioActual: widget.usuarioActual),
      BatidosScreen(usuarioActual: widget.usuarioActual),
      ReportsScreen(usuarioActual: widget.usuarioActual),
      if (widget.usuarioActual['rol'] == 'Administrador')
        UserManagementScreen(usuarioActual: widget.usuarioActual),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Text('Gala Gym - Sede: $sedeActual', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(width: 30),
            
            Expanded(
              child: Center(
                child: Container(
                  width: 450,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (option) => "#${option['numero']} - ${option['nombre']} ${option['apellido'] ?? ''}",
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                      var box = Hive.box(boxClientesNombre);
                      var keys = box.keys.toList();
                      
                      return keys.map((k) {
                        var c = Map<String, dynamic>.from(box.get(k) as Map);
                        c['id'] = k; 
                        c['numero'] = keys.indexOf(k) + 1; 
                        return c;
                      }).where((c) {
                        String busqueda = textEditingValue.text.toLowerCase();
                        String nom = "${c['nombre']} ${c['apellido'] ?? ''}".toLowerCase();
                        String ced = (c['cedula'] ?? '').toString().toLowerCase();
                        String numStr = c['numero'].toString();
                        return nom.contains(busqueda) || ced.contains(busqueda) || numStr == busqueda;
                      });
                    },
                    onSelected: (Map<String, dynamic> selection) {
                      setState(() {
                        _globalSelectedClientId = selection['id'].toString();
                        _selectedIndex = 1; 
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onEditingComplete: onEditingComplete,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: 'Buscar por Nombre, Cédula o Número de Cliente...',
                          prefixIcon: Icon(Icons.search, color: Colors.blue),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(child: Text('Rol: ${widget.usuarioActual['rol']}', style: const TextStyle(fontWeight: FontWeight.bold))),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión / Cambiar Sede',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      
      floatingActionButton: ValueListenableBuilder(
        valueListenable: Hive.box('configBox').listenable(),
        builder: (context, Box box, _) {
          double usd = box.get('tasa_usd', defaultValue: 0.0);
          double eur = box.get('tasa_eur', defaultValue: 0.0);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              border: Border.all(color: Colors.blue.shade900, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance, color: Colors.blue.shade900, size: 30),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TASA OFICIAL BCV', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('USD: Bs. ${usd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                    Text('EUR: Bs. ${eur.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                  ],
                ),
              ],
            ),
          );
        },
      ),

      body: Column(
        children: [
          _buildTopStatsBar(boxClientesNombre),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) => setState(() { _selectedIndex = index; _globalSelectedClientId = null; }),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    const NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Inicio')),
                    const NavigationRailDestination(icon: Icon(Icons.people), label: Text('Clientes')),
                    const NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('Ventas')),
                    const NavigationRailDestination(icon: Icon(Icons.fingerprint), label: Text('Accesos')),
                    const NavigationRailDestination(icon: Icon(Icons.inventory), label: Text('Productos/Membresías')),
                    const NavigationRailDestination(icon: Icon(Icons.local_cafe), label: Text('Batidos')), 
                    const NavigationRailDestination(icon: Icon(Icons.bar_chart), label: Text('Reportes')),
                    if (widget.usuarioActual['rol'] == 'Administrador')
                      const NavigationRailDestination(icon: Icon(Icons.admin_panel_settings), label: Text('Usuarios')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: pantallas[_selectedIndex]),
                const VerticalDivider(thickness: 1, width: 1),
                _buildLiveFeedPanel(boxAccesosNombre, boxClientesNombre),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _StatItem({required this.title, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(count.toString(), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ContenidoDashboard extends StatelessWidget {
  const _ContenidoDashboard();
  @override
  Widget build(BuildContext context) {
    String boxClientesNombre = obtenerNombreBoxSede('clientsBox');
    String boxVentasNombre = obtenerNombreBoxSede('ventasBox');
    String boxAccesosNombre = obtenerNombreBoxSede('accesosBox');
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Panel General de Control', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                ValueListenableBuilder(valueListenable: Hive.box(boxClientesNombre).listenable(), builder: (c, Box box, _) => _buildDashCard('Clientes Registrados', box.length.toString(), Icons.people, Colors.blue)),
                ValueListenableBuilder(valueListenable: Hive.box(boxVentasNombre).listenable(), builder: (c, Box box, _) => _buildDashCard('Ventas Realizadas', box.length.toString(), Icons.point_of_sale, Colors.green)),
                ValueListenableBuilder(valueListenable: Hive.box(boxAccesosNombre).listenable(), builder: (c, Box box, _) => _buildDashCard('Accesos Registrados', box.length.toString(), Icons.fingerprint, Colors.orange)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildDashCard(String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 40, color: color), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 16)), const SizedBox(height: 4), Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))],
      ),
    );
  }
}
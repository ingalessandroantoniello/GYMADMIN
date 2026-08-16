import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../helpers.dart';
import 'clients_screen.dart';
import 'daily_sales_screen.dart';
import 'access_log_screen.dart';
import 'inventory_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    String sedeActual = obtenerSedeActual().toUpperCase();

    final List<Widget> pantallas = [
      const _ContenidoDashboard(),
      ClientsScreen(usuarioActual: widget.usuarioActual),
      DailySalesScreen(usuarioActual: widget.usuarioActual),
      AccessLogScreen(usuarioActual: widget.usuarioActual),
      InventoryScreen(usuarioActual: widget.usuarioActual),
      ReportsScreen(usuarioActual: widget.usuarioActual),
      if (widget.usuarioActual['rol'] == 'Administrador')
        UserManagementScreen(usuarioActual: widget.usuarioActual),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('GymAdmin - Sede: $sedeActual'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Rol: ${widget.usuarioActual['rol']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Inicio'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Clientes'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.point_of_sale),
                label: Text('Ventas'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.fingerprint),
                label: Text('Accesos'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.inventory),
                label: Text('Inventario'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.bar_chart),
                label: Text('Reportes'),
              ),
              if (widget.usuarioActual['rol'] == 'Administrador')
                const NavigationRailDestination(
                  icon: Icon(Icons.admin_panel_settings),
                  label: Text('Usuarios'),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: pantallas[_selectedIndex],
          ),
        ],
      ),
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
          const Text(
            'Panel General de Control',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                ValueListenableBuilder(
                  valueListenable: Hive.box(boxClientesNombre).listenable(),
                  builder: (context, Box box, _) {
                    return Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people, size: 40, color: Colors.blue),
                            const SizedBox(height: 8),
                            const Text('Clientes Registrados', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${box.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder(
                  valueListenable: Hive.box(boxVentasNombre).listenable(),
                  builder: (context, Box box, _) {
                    return Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.point_of_sale, size: 40, color: Colors.green),
                            const SizedBox(height: 8),
                            const Text('Ventas Realizadas', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${box.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder(
                  valueListenable: Hive.box(boxAccesosNombre).listenable(),
                  builder: (context, Box box, _) {
                    return Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.fingerprint, size: 40, color: Colors.orange),
                            const SizedBox(height: 8),
                            const Text('Accesos Registrados', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${box.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
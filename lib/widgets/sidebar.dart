import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Map<String, dynamic> usuarioActual; 
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout; 

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.usuarioActual,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final String rolUsuario = usuarioActual['rol'] ?? 'Cajero';
    final String nombreUsuario = usuarioActual['usuario'] ?? 'Usuario';
    final bool esAdmin = rolUsuario == 'Administrador';
    
    final permisos = Map<String, dynamic>.from(usuarioActual['permisos'] ?? {});
    final bool puedeVerReportes = esAdmin || (permisos['ver_reportes'] == true);

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.fitness_center, color: Colors.blue, size: 28), 
                  SizedBox(width: 8),
                  Text('GALA GYM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  CircleAvatar(backgroundColor: Colors.blue[100], child: const Icon(Icons.person, color: Colors.blue)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombreUsuario.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Chip(
                        label: Text(rolUsuario, style: const TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: esAdmin ? Colors.blue[900] : Colors.orange[800],
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        const NavigationDrawerDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Clientes y Membresías')),
        const NavigationDrawerDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Inventario y Productos')),
        const NavigationDrawerDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history_toggle_off), label: Text('Registro de Entradas')),
        const NavigationDrawerDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: Text('Ventas del Día (GYM)')),
        
        // --- NUEVO BOTÓN: BARRA DE BATIDOS ---
        const NavigationDrawerDestination(icon: Icon(Icons.local_cafe_outlined, color: Colors.orange), selectedIcon: Icon(Icons.local_cafe, color: Colors.orange), label: Text('Barra de Batidos')),
        
        if (puedeVerReportes) 
          const NavigationDrawerDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Reportes e Impresión')),
          
        if (esAdmin) 
          const NavigationDrawerDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: Text('Gestión de Usuarios')),

        const Divider(),
        
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 15)),
            icon: const Icon(Icons.logout), label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: onLogout,
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class UserManagementScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioActual;

  const UserManagementScreen({super.key, required this.usuarioActual});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  void _eliminarUsuario(String user) async {
    if (user == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por seguridad, el usuario maestro no se puede borrar'), backgroundColor: Colors.red));
      return;
    }

    var box = Hive.box('usuariosBox');
    await box.delete(user);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario eliminado'), backgroundColor: Colors.orange));
    }
  }

  void _abrirFormularioUsuario(BuildContext context, {Map<String, dynamic>? usuarioParaEditar}) {
    final bool esEdicion = usuarioParaEditar != null;
    final TextEditingController userCtrl = TextEditingController(text: esEdicion ? usuarioParaEditar['usuario'] : '');
    final TextEditingController passCtrl = TextEditingController(text: esEdicion ? usuarioParaEditar['clave'] : '');
    
    String rolSeleccionado = esEdicion ? (usuarioParaEditar['rol'] ?? 'Cajero') : 'Cajero';

    // MAPA CON EL NUEVO PERMISO AGREGADO
    Map<String, bool> permisos = {
      'crear_clientes': true,
      'vender': true,
      'modificar_precios': false,
      'editar_fechas': false,
      'editar_facturas': false,
      'gestionar_inventario': false,
      'ver_cuadre': false,
      'ver_reportes': false, // EL NUEVO PERMISO
    };

    if (esEdicion && usuarioParaEditar['permisos'] != null) {
      Map<String, dynamic> pOriginal = Map<String, dynamic>.from(usuarioParaEditar['permisos']);
      pOriginal.forEach((key, val) {
        if (permisos.containsKey(key)) {
          permisos[key] = val == true;
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool esAdmin = rolSeleccionado == 'Administrador';

            return Padding(
              padding: EdgeInsets.only(top: 20, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(esEdicion ? 'Editar Usuario / Permisos' : 'Crear Nuevo Usuario', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Divider(),
                    const SizedBox(height: 15),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: userCtrl,
                            enabled: !(esEdicion && usuarioParaEditar['usuario'] == 'admin'),
                            decoration: const InputDecoration(labelText: 'Nombre de Usuario', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: passCtrl,
                            decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    DropdownButtonFormField<String>(
                      initialValue: rolSeleccionado,
                      decoration: const InputDecoration(labelText: 'Rol Principal', border: OutlineInputBorder()),
                      items: ['Cajero', 'Administrador'].map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            rolSeleccionado = val;
                            if (val == 'Administrador') {
                              permisos.updateAll((key, value) => true);
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    const Text('Permisos Especiales del Usuario:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: const Text('Registrar nuevos clientes'),
                            value: esAdmin ? true : permisos['crear_clientes'],
                            onChanged: esAdmin ? null : (v) => setModalState(() => permisos['crear_clientes'] = v ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Vender y renovar membresías'),
                            value: esAdmin ? true : permisos['vender'],
                            onChanged: esAdmin ? null : (v) => setModalState(() => permisos['vender'] = v ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Modificar montos/precios al vender (Descuentos)'),
                            value: esAdmin ? true : permisos['modificar_precios'],
                            onChanged: esAdmin ? null : (v) => setModalState(() => permisos['modificar_precios'] = v ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Modificar fechas de membresías activas'),
                            value: esAdmin ? true : permisos['editar_fechas'],
                            onChanged: esAdmin ? null : (v) => setModalState(() => permisos['editar_fechas'] = v ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Corregir/Editar facturas pasadas (Pagos)'),
                            value: esAdmin ? true : permisos['editar_facturas'],
                            onChanged: esAdmin ? null : (v) => setModalState(() => permisos['editar_facturas'] = v ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Gestionar inventario (Crear/Eliminar Productos)'),
                            value: esAdmin ? true : permisos['gestionar_inventario'],
                            onChanged: esAdmin ? null : (v) => setModalState(() => permisos['gestionar_inventario'] = v ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Ver totales de cuadre de caja en Ventas'),
                            value: esAdmin ? true : permisos['ver_cuadre'],
                            onChanged: esAdmin ? null : (v) => setModalState(() => permisos['ver_cuadre'] = v ?? false),
                          ),
                          // --- LA NUEVA CASILLA DE VERIFICACIÓN ---
                          CheckboxListTile(
                            title: const Text('Generar e imprimir Reportes PDF (Caja y Clientes)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            value: esAdmin ? true : permisos['ver_reportes'],
                            onChanged: esAdmin ? null : (v) => setModalState(() => permisos['ver_reportes'] = v ?? false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
                        icon: const Icon(Icons.save),
                        label: Text(esEdicion ? 'Guardar Cambios de Usuario' : 'Crear y Autorizar Usuario', style: const TextStyle(fontSize: 16)),
                        onPressed: () async {
                          String u = userCtrl.text.trim();
                          String p = passCtrl.text.trim();
                          if (u.isEmpty || p.isEmpty) {
                            return;
                          }

                          var box = Hive.box('usuariosBox');
                          
                          if (!esEdicion && box.containsKey(u)) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ese nombre de usuario ya existe'), backgroundColor: Colors.orange));
                            return;
                          }

                          if (esAdmin) {
                             permisos.updateAll((key, value) => true);
                          }

                          await box.put(u, {
                            'usuario': u,
                            'clave': p,
                            'rol': rolSeleccionado,
                            'permisos': permisos, 
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(esEdicion ? 'Usuario actualizado exitosamente' : 'Usuario creado exitosamente'), backgroundColor: Colors.green));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión del Personal y Permisos'), backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15)),
              icon: const Icon(Icons.person_add),
              label: const Text('REGISTRAR NUEVO EMPLEADO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () => _abrirFormularioUsuario(context),
            ),
            const SizedBox(height: 25),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box('usuariosBox').listenable(),
                builder: (context, box, _) {
                  final usuarios = box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();

                  return ListView.builder(
                    itemCount: usuarios.length,
                    itemBuilder: (context, index) {
                      final user = usuarios[index];
                      final bool esAdmin = user['rol'] == 'Administrador';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: esAdmin ? Colors.blue[900] : Colors.orange,
                            child: Icon(esAdmin ? Icons.admin_panel_settings : Icons.point_of_sale, color: Colors.white),
                          ),
                          title: Text(user['usuario'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text("Rol: ${user['rol']} | Clave: ${user['clave']}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Editar usuario y permisos',
                                onPressed: () => _abrirFormularioUsuario(context, usuarioParaEditar: user),
                              ),
                              if (user['usuario'] != 'admin')
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Eliminar acceso',
                                  onPressed: () => _eliminarUsuario(user['usuario']),
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
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class InventoryScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioActual;

  const InventoryScreen({super.key, required this.usuarioActual});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  String _tipoProducto = 'Membresía';

  void _guardarProducto() async {
    if (_nombreController.text.trim().isEmpty || _precioController.text.trim().isEmpty) {
      return;
    }

    final nuevoProducto = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'nombre': _nombreController.text.trim(),
      'tipo': _tipoProducto,
      'precio': double.parse(_precioController.text.replaceAll(',', '.')),
    };

    await Hive.box('inventarioBox').put(nuevoProducto['id'], nuevoProducto);

    _nombreController.clear();
    _precioController.clear();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _eliminarProducto(String id) async {
    await Hive.box('inventarioBox').delete(id);
  }

  void _showFormularioProducto(BuildContext context, String categoriaInicial) {
    _tipoProducto = categoriaInicial;
    _nombreController.clear();
    _precioController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(top: 20, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crear: $_tipoProducto', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  const SizedBox(height: 15),
                  TextField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _precioController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio Fijo (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money))),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      icon: const Icon(Icons.save), label: const Text('Guardar'), onPressed: _guardarProducto,
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = widget.usuarioActual['rol'] == 'Administrador';
    final permisos = Map<String, dynamic>.from(widget.usuarioActual['permisos'] ?? {});
    final bool puedeGestionar = esAdmin || (permisos['gestionar_inventario'] == true);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventario y Control de Precios')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (puedeGestionar)
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                    icon: const Icon(Icons.badge),
                    label: const Text('AÑADIR MEMBRESÍA', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showFormularioProducto(context, 'Membresía'),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('AÑADIR PRODUCTO', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showFormularioProducto(context, 'Artículo / Bebida'),
                  ),
                ],
              ),
            if (puedeGestionar) const SizedBox(height: 25),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box('inventarioBox').listenable(),
                builder: (context, box, _) {
                  final productos = box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                  if (productos.isEmpty) {
                    return const Center(child: Text('Aún no hay productos.', style: TextStyle(color: Colors.grey)));
                  }

                  return ListView.builder(
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final prod = productos[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(prod['tipo'] == 'Membresía' ? Icons.badge : Icons.shopping_bag, color: prod['tipo'] == 'Membresía' ? Colors.indigo : Colors.orange),
                          title: Text(prod['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(prod['tipo']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("\$${prod['precio'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                              if (puedeGestionar) IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _eliminarProducto(prod['id']))
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
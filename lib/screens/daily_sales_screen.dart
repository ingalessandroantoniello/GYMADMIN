import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../helpers.dart';

class DailySalesScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioActual;

  const DailySalesScreen({super.key, required this.usuarioActual});

  @override
  State<DailySalesScreen> createState() => _DailySalesScreenState();
}

class _DailySalesScreenState extends State<DailySalesScreen> {
  @override
  Widget build(BuildContext context) {
    String boxNombre = obtenerNombreBoxSede('ventasBox');
    var ventasBox = Hive.box(boxNombre);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ventas Diarias - ${obtenerSedeActual().toUpperCase()}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder(
        valueListenable: ventasBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text(
                'No hay ventas registradas en esta sede.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              var venta = box.getAt(index);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.point_of_sale, color: Colors.green),
                  title: Text('Venta #${index + 1}'),
                  subtitle: Text('Detalle: ${venta.toString()}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
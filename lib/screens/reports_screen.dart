import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../helpers.dart'; // Importante para obtener el nombre de la sede

class ReportsScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioActual;
  const ReportsScreen({super.key, required this.usuarioActual});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _filtroTipo = 'Día'; // Opciones: 'Día' o 'Mes'
  DateTime _fechaSeleccionada = DateTime.now();

  Future<void> _seleccionarFecha(BuildContext context) async {
    if (_filtroTipo == 'Día') {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _fechaSeleccionada,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() => _fechaSeleccionada = picked);
      }
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          int mesTemp = _fechaSeleccionada.month;
          int anioTemp = _fechaSeleccionada.year;
          return AlertDialog(
            title: const Text('Seleccionar Mes y Año'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                DropdownButton<int>(
                  value: mesTemp,
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('Mes ${i + 1}'))),
                  onChanged: (v) {
                    if (v != null) mesTemp = v;
                  },
                ),
                DropdownButton<int>(
                  value: anioTemp,
                  items: [2025, 2026, 2027].map((a) => DropdownMenuItem(value: a, child: Text('$a'))).toList(),
                  onChanged: (v) {
                    if (v != null) anioTemp = v;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () {
                setState(() => _fechaSeleccionada = DateTime(anioTemp, mesTemp, 1));
                Navigator.pop(ctx);
              }, child: const Text('Aceptar'))
            ],
          );
        },
      );
    }
  }

  void _imprimirReporte(double totalUSD, double totalBs, Map<String, double> desglose) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Imprimir Reporte de Caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Período: ${_filtroTipo == 'Día' ? "${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}" : "Mes ${_fechaSeleccionada.month}/${_fechaSeleccionada.year}"}'),
            const Divider(),
            Text('Total General: USD ${totalUSD.toStringAsFixed(2)}'),
            Text('Total en Bs: Bs. ${totalBs.toStringAsFixed(2)}'),
            const Divider(),
            const Text('Desglose:'),
            ...desglose.entries.map((e) => Text('- ${e.key}: USD ${e.value.toStringAsFixed(2)}')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimir'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte enviado a impresora'), backgroundColor: Colors.green));
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var configBox = Hive.box('configBox');
    final double tasaUsd = configBox.get('tasa_usd', defaultValue: 1.0);
    
    // Generamos el nombre dinámico de la caja para esta sede
    String boxVentasNombre = obtenerNombreBoxSede('ventasBox');

    // Escudo de seguridad para evitar crashes si la caja no ha cargado
    if (!Hive.isBoxOpen(boxVentasNombre)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reportes Financieros y de Caja')),
        body: const Center(child: Text('Cargando datos de la sede...', style: TextStyle(color: Colors.grey, fontSize: 16))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes Financieros y de Caja')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Filtrar por:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _filtroTipo,
                      items: const [
                        DropdownMenuItem(value: 'Día', child: Text('Día Específico')),
                        DropdownMenuItem(value: 'Mes', child: Text('Mes Específico')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _filtroTipo = val);
                        }
                      },
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_filtroTipo == 'Día' 
                      ? "${_fechaSeleccionada.day.toString().padLeft(2,'0')}/${_fechaSeleccionada.month.toString().padLeft(2,'0')}/${_fechaSeleccionada.year}" 
                      : "Mes: ${_fechaSeleccionada.month}/${_fechaSeleccionada.year}"),
                  onPressed: () => _seleccionarFecha(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ValueListenableBuilder(
                // Usamos la variable dinámica boxVentasNombre aquí
                valueListenable: Hive.box(boxVentasNombre).listenable(),
                builder: (context, boxVentas, _) {
                  final ventas = boxVentas.values
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .where((v) {
                        String fechaVenta = v['fecha'] ?? ''; 
                        if (fechaVenta.isEmpty) {
                          return false;
                        }
                        var partes = fechaVenta.split('/');
                        if (partes.length < 3) {
                          return false;
                        }
                        int d = int.parse(partes[0]);
                        int m = int.parse(partes[1]);
                        int a = int.parse(partes[2]);

                        if (_filtroTipo == 'Día') {
                          return d == _fechaSeleccionada.day && 
                                 m == _fechaSeleccionada.month && 
                                 a == _fechaSeleccionada.year;
                        } else {
                          return m == _fechaSeleccionada.month && 
                                 a == _fechaSeleccionada.year;
                        }
                      })
                      .toList();

                  double totalGeneralUSD = 0.0;
                  double totalBsEquivalente = 0.0;
                  Map<String, double> desglosePorMetodo = {};

                  for (var v in ventas) {
                    double montoVenta = (v['monto'] as num).toDouble();
                    totalGeneralUSD += montoVenta;

                    if (v['pagosDetalle'] is List) {
                      for (var pago in (v['pagosDetalle'] as List)) {
                        String metodo = pago['metodo'] ?? 'Desconocido';
                        double montoPago = (pago['monto'] as num).toDouble();

                        desglosePorMetodo[metodo] = (desglosePorMetodo[metodo] ?? 0.0) + montoPago;

                        if (metodo == 'Efectivo BS' || metodo == 'Pago Móvil') {
                          totalBsEquivalente += (montoPago * tasaUsd);
                        }
                      }
                    } else {
                      String metodoLegacy = v['metodoPago'] ?? 'Efectivo USD';
                      desglosePorMetodo[metodoLegacy] = (desglosePorMetodo[metodoLegacy] ?? 0.0) + montoVenta;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Resumen del Período", style: TextStyle(color: Colors.white70, fontSize: 14)),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.print, size: 16),
                                  label: const Text('Imprimir Reporte'),
                                  onPressed: () => _imprimirReporte(totalGeneralUSD, totalBsEquivalente, desglosePorMetodo),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("Total General: USD ${totalGeneralUSD.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Total en Bs (Tasa BCV): Bs. ${totalBsEquivalente.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Desglose por Forma de Pago:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ventas.isEmpty
                            ? const Center(child: Text('No hay registros para este período.'))
                            : ListView(
                                children: desglosePorMetodo.entries.map((entry) {
                                  String metodo = entry.key;
                                  double monto = entry.value;
                                  bool esBs = (metodo == 'Efectivo BS' || metodo == 'Pago Móvil');

                                  return Card(
                                    child: ListTile(
                                      leading: Icon(esBs ? Icons.money : Icons.attach_money, color: esBs ? Colors.green : Colors.blue),
                                      title: Text(metodo, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("USD ${monto.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                          if (esBs)
                                            Text("Bs. ${(monto * tasaUsd).toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
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
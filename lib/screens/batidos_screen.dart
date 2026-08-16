import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BatidosScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioActual;

  const BatidosScreen({super.key, required this.usuarioActual});

  @override
  State<BatidosScreen> createState() => _BatidosScreenState();
}

class _BatidosScreenState extends State<BatidosScreen> {
  DateTime _fechaSeleccionada = DateTime.now();

  void _showCrearBatidoForm(BuildContext context) {
    final TextEditingController nombreCtrl = TextEditingController();
    final TextEditingController precioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Añadir Batido al Menú', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del Batido', border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: precioCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
              onPressed: () async {
                if (nombreCtrl.text.trim().isEmpty || precioCtrl.text.trim().isEmpty) {
                  return;
                }
                final nuevoBatido = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'nombre': nombreCtrl.text.trim(),
                  'precio': double.parse(precioCtrl.text.replaceAll(',', '.')),
                };
                await Hive.box('batidosMenuBox').put(nuevoBatido['id'], nuevoBatido);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      }
    );
  }

  void _venderBatido(BuildContext context, Map<String, dynamic> batido) {
    String metodoPago = 'Efectivo USD';
    final TextEditingController clienteCtrl = TextEditingController();
    final double tasaUsd = Hive.box('configBox').get('tasa_usd', defaultValue: 1.0);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool esEnBolivares = (metodoPago == 'Efectivo BS' || metodoPago == 'Pago Móvil');

            return AlertDialog(
              title: Text('Cobrar: ${batido['nombre']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Monto Base: \$${batido['precio'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: metodoPago,
                    decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                    items: ['Efectivo USD', 'Efectivo BS', 'Pago Móvil', 'Tarjeta de Débito', 'Tarjeta de Crédito', 'Zelle', 'BINANCE'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) { 
                      if (val != null) {
                        setModalState(() => metodoPago = val); 
                      }
                    },
                  ),
                  
                  if (esEnBolivares)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                      child: Column(
                        children: [
                          Text('Tasa BCV: $tasaUsd', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                          Text('Cobrar: Bs. ${(batido['precio'] * tasaUsd).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange[900])),
                        ],
                      ),
                    ),

                  const SizedBox(height: 15),
                  TextField(
                    controller: clienteCtrl,
                    decoration: const InputDecoration(labelText: 'Cliente (Opcional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Procesar Venta'),
                  onPressed: () async {
                    final hoy = DateTime.now();
                    final nuevaVenta = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'concepto': batido['nombre'],
                      'monto': batido['precio'],
                      'metodoPago': metodoPago,
                      'cliente': clienteCtrl.text.trim().isEmpty ? 'Cliente de paso' : clienteCtrl.text.trim(),
                      'fecha': "${hoy.day.toString().padLeft(2,'0')}/${hoy.month.toString().padLeft(2,'0')}/${hoy.year}",
                      'hora': "${hoy.hour}:${hoy.minute.toString().padLeft(2, '0')}",
                    };
                    await Hive.box('ventasBatidosBox').put(nuevaVenta['id'], nuevaVenta);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batido vendido'), backgroundColor: Colors.green));
                    }
                  },
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _imprimirReporteBatidos(List<Map<String, dynamic>> ventas, double tUsd, double tBs, double tDig) async {
    final doc = pw.Document();
    final String fechaStr = "${_fechaSeleccionada.day.toString().padLeft(2,'0')}/${_fechaSeleccionada.month.toString().padLeft(2,'0')}/${_fechaSeleccionada.year}";

    Map<String, int> conteoBatidos = {};
    for (var v in ventas) {
      conteoBatidos[v['concepto']] = (conteoBatidos[v['concepto']] ?? 0) + 1;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Text('REPORTE DIARIO DE BARRA DE BATIDOS - GALA GYM', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Fecha del reporte: $fechaStr', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RESUMEN DE CAJA (CUENTA INDEPENDIENTE)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Divider(),
                  pw.Text('Efectivo USD: \$${tUsd.toStringAsFixed(2)}'),
                  pw.Text('Efectivo BS (Equivalente USD): \$${tBs.toStringAsFixed(2)}'),
                  pw.Text('Digital/Bancos: \$${tDig.toStringAsFixed(2)}'),
                  pw.SizedBox(height: 5),
                  pw.Text('TOTAL GENERAL VENTAS: \$${(tUsd + tBs + tDig).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.green800)),
                ]
              )
            ),
            pw.SizedBox(height: 20),
            pw.Text('Resumen de Productos Vendidos (Inventario):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Producto / Batido', 'Cantidad Vendida'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
              data: conteoBatidos.entries.map((e) => [e.key, e.value.toString()]).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Detalle de Transacciones:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Hora', 'Cliente', 'Batido', 'Método', 'Monto'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
              data: ventas.map((v) => [v['hora'], v['cliente'], v['concepto'], v['metodoPago'], '\$${v['monto'].toStringAsFixed(2)}']).toList(),
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Reporte_Batidos_GalaGym');
  }

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = widget.usuarioActual['rol'] == 'Administrador';
    final permisos = Map<String, dynamic>.from(widget.usuarioActual['permisos'] ?? {});
    final bool puedeGestionar = esAdmin || (permisos['gestionar_inventario'] == true);
    final bool puedeVerReportes = esAdmin || (permisos['ver_reportes'] == true);
    final bool puedeVerCuadre = esAdmin || (permisos['ver_cuadre'] == true);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Barra de Batidos - Gala Gym'),
          backgroundColor: Colors.orange[800],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.local_cafe), text: 'Punto de Venta'),
              Tab(icon: Icon(Icons.analytics), text: 'Cuadre y Reportes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Menú Disponible', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (puedeGestionar)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir al Menú'),
                          onPressed: () => _showCrearBatidoForm(context),
                        )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: Hive.box('batidosMenuBox').listenable(),
                      builder: (context, box, _) {
                        final batidos = box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                        if (batidos.isEmpty) {
                          return const Center(child: Text('El menú está vacío.', style: TextStyle(color: Colors.grey)));
                        }

                        return GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
                          itemCount: batidos.length,
                          itemBuilder: (context, index) {
                            final batido = batidos[index];
                            return Card(
                              color: Colors.orange[50],
                              child: InkWell(
                                onTap: () => _venderBatido(context, batido),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.local_cafe, size: 40, color: Colors.orange),
                                    const SizedBox(height: 10),
                                    Text(batido['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                                    Text('\$${batido['precio'].toStringAsFixed(2)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                                    if (puedeGestionar)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                        onPressed: () => box.delete(batido['id'])
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                    ),
                  )
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final String fechaBusqueda = "${_fechaSeleccionada.day.toString().padLeft(2,'0')}/${_fechaSeleccionada.month.toString().padLeft(2,'0')}/${_fechaSeleccionada.year}";

                return ValueListenableBuilder(
                  valueListenable: Hive.box('ventasBatidosBox').listenable(),
                  builder: (context, box, _) {
                    final ventas = box.values.map((e) => Map<String, dynamic>.from(e as Map)).where((v) => v['fecha'] == fechaBusqueda).toList();
                    double tUsd = 0, tBs = 0, tDig = 0;
                    for (var v in ventas) {
                      double m = v['monto'];
                      if (v['metodoPago'] == 'Efectivo USD') {
                        tUsd += m;
                      } else if (v['metodoPago'] == 'Efectivo BS') {
                        tBs += m;
                      } else {
                        tDig += m;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_month),
                                label: Text('Fecha: $fechaBusqueda'),
                                onPressed: () async {
                                  DateTime? picked = await showDatePicker(context: context, initialDate: _fechaSeleccionada, firstDate: DateTime(2023), lastDate: DateTime.now());
                                  if (picked != null) {
                                    setState(() => _fechaSeleccionada = picked);
                                  }
                                },
                              ),
                              const Spacer(),
                              if (puedeVerReportes)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                                  icon: const Icon(Icons.print),
                                  label: const Text('IMPRIMIR REPORTE DE BATIDOS', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: ventas.isEmpty ? null : () => _imprimirReporteBatidos(ventas, tUsd, tBs, tDig),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (puedeVerCuadre) ...[
                            Row(
                              children: [
                                _resumenMini('Total USD', tUsd, Colors.green),
                                _resumenMini('Total BS', tBs, Colors.purple),
                                _resumenMini('Bancos', tDig, Colors.orange),
                                _resumenMini('TOTAL DÍA', tUsd + tBs + tDig, Colors.orange[800]!),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                          const Text('Historial de Ventas del Día', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          Expanded(
                            child: ventas.isEmpty 
                              ? const Center(child: Text('No hay ventas de batidos registradas en esta fecha.'))
                              : ListView.builder(
                                  itemCount: ventas.length,
                                  itemBuilder: (context, i) {
                                    final v = ventas[ventas.length - 1 - i]; 
                                    return Card(
                                      child: ListTile(
                                        leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.local_cafe, color: Colors.white)),
                                        title: Text("${v['concepto']} - \$${v['monto'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text("${v['cliente']} | ${v['metodoPago']}"),
                                        trailing: Text(v['hora']),
                                      ),
                                    );
                                  }
                                )
                          )
                        ],
                      ),
                    );
                  }
                );
              }
            )
          ],
        ),
      ),
    );
  }

  Widget _resumenMini(String titulo, double monto, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Column(
          children: [
            Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 5),
            Text('\$${monto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
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

  // --- MODIFICAR O ELIMINAR VENTA (ACTUALIZANDO REPORTES AL INSTANTE) ---
  void _modificarVenta(String ventaKey, Map<String, dynamic> ventaActual) {
    bool esAdmin = widget.usuarioActual['rol'] == 'Administrador' || widget.usuarioActual['permisosEdicion'] == true;
    if (!esAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tiene permisos para modificar ventas.'), backgroundColor: Colors.red));
      return;
    }

    final TextEditingController conceptoCtrl = TextEditingController(text: ventaActual['concepto'] ?? '');
    final TextEditingController montoCtrl = TextEditingController(text: ventaActual['monto'].toString());

    List<String> metodosPermitidos = ['Efectivo USD', 'Efectivo BS', 'Pago Móvil', 'Transferencia BS', 'Zelle', 'Binance', 'MIXTO'];
    String metodoSeleccionado = ventaActual['metodoPago'] ?? 'Efectivo USD';
    if (!metodosPermitidos.contains(metodoSeleccionado)) {
      metodosPermitidos.add(metodoSeleccionado);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modificar Venta Registrada', style: TextStyle(color: Colors.blue)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: conceptoCtrl, decoration: const InputDecoration(labelText: 'Concepto / Producto', border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  TextField(controller: montoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto (USD)', border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  
                  DropdownButtonFormField<String>(
                    value: metodoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Forma de Pago', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payment)),
                    items: metodosPermitidos.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => metodoSeleccionado = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete),
                  label: const Text('Eliminar Venta'),
                  onPressed: () async {
                    await Hive.box(obtenerNombreBoxSede('ventasBox')).delete(ventaKey);
                    if (mounted) setState(() {}); // Refresca la vista local de la lista
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta eliminada y reportes actualizados.'), backgroundColor: Colors.red));
                    }
                  },
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                  onPressed: () async {
                    double nuevoMonto = double.tryParse(montoCtrl.text.replaceAll(',', '.')) ?? ventaActual['monto'];
                    var ventaModificada = Map<String, dynamic>.from(ventaActual);
                    ventaModificada['concepto'] = conceptoCtrl.text.trim();
                    ventaModificada['monto'] = nuevoMonto;
                    ventaModificada['metodoPago'] = metodoSeleccionado;

                    // Si se cambió a un método específico, ajustamos también el desglose interno para los reportes
                    ventaModificada['pagosDetalle'] = [
                      {'metodo': metodoSeleccionado, 'monto': nuevoMonto}
                    ];

                    await Hive.box(obtenerNombreBoxSede('ventasBox')).put(ventaKey, ventaModificada);
                    if (mounted) setState(() {}); // Refresca la vista local de la lista
                    
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta y reportes actualizados con éxito.'), backgroundColor: Colors.green));
                    }
                  },
                  child: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- VENTANA PARA NUEVA VENTA GENERAL CON RASTREADOR DE INVENTARIO ---
  Future<void> _abrirModalNuevaVenta(BuildContext context) async {
    String boxSede = obtenerNombreBoxSede('inventarioBox');
    if (!Hive.isBoxOpen(boxSede)) await Hive.openBox(boxSede);
    if (!Hive.isBoxOpen('inventarioBox')) await Hive.openBox('inventarioBox');

    var invSede = Hive.box(boxSede);
    var invGlobal = Hive.box('inventarioBox');

    Map<String, double> productosUnicos = {};

    void extraerProductos(Box box) {
      for (var e in box.values) {
        var p = Map<String, dynamic>.from(e as Map);
        String n = (p['nombre'] ?? p['producto'] ?? p['articulo'] ?? p['descripcion'] ?? '').toString().trim();
        if (n.isNotEmpty) {
           double pr = double.tryParse(p['precioVenta']?.toString() ?? p['precio']?.toString() ?? p['costo']?.toString() ?? '0') ?? 0.0;
           productosUnicos[n] = pr;
        }
      }
    }

    extraerProductos(invSede);
    extraerProductos(invGlobal);

    if (productosUnicos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay productos ni membresías registradas en el módulo de Inventario.'), backgroundColor: Colors.orange));
      }
      return;
    }

    String boxClientesNombre = obtenerNombreBoxSede('clientsBox');
    var boxClientes = Hive.box(boxClientesNombre);

    final double tasaUsd = Hive.box('configBox').get('tasa_usd', defaultValue: 1.0);
    
    String? productoSeleccionado;
    double precioUnitario = 0.0;
    bool esMembresiaOAsociado = false;
    String? clienteIdSeleccionado;

    final TextEditingController efvoUsdCtrl = TextEditingController();
    final TextEditingController zelleCtrl = TextEditingController();
    final TextEditingController binanceCtrl = TextEditingController();
    final TextEditingController efvoBsCtrl = TextEditingController();
    final TextEditingController pagoMovilBsCtrl = TextEditingController();
    final TextEditingController transfBsCtrl = TextEditingController();

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void recalcular() => setDialogState(() {});
            double parseD(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;

            double pagadoDirectoUsd = parseD(efvoUsdCtrl.text) + parseD(zelleCtrl.text) + parseD(binanceCtrl.text);
            double dolaresParaPagarEnBs = parseD(efvoBsCtrl.text) + parseD(pagoMovilBsCtrl.text) + parseD(transfBsCtrl.text);
            double totalBsFisicosACobrar = dolaresParaPagarEnBs * tasaUsd;
            
            double totalPagadoEnUsd = pagadoDirectoUsd + dolaresParaPagarEnBs;
            double restanteUsd = precioUnitario - totalPagadoEnUsd;

            return AlertDialog(
              title: const Text('Registrar Nueva Venta'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 550,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tasa BCV:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Bs. ${tasaUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 15),

                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Seleccionar Producto o Membresía', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shopping_bag)),
                        value: productoSeleccionado,
                        items: productosUnicos.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text("${entry.key} - \$${entry.value.toStringAsFixed(2)}"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              productoSeleccionado = val;
                              precioUnitario = productosUnicos[val] ?? 0.0;
                              
                              String lower = val.toLowerCase();
                              esMembresiaOAsociado = lower.contains('membresía') || lower.contains('mensualidad') || lower.contains('inscripcion') || lower.contains('pase');
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 15),

                      if (esMembresiaOAsociado) ...[
                        const Text('Asociar a Cliente (Membresía):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 8),
                        Autocomplete<Map<String, dynamic>>(
                          displayStringForOption: (option) => "${option['nombre']} ${option['apellido'] ?? ''} - C.I: ${option['cedula']}",
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                            return boxClientes.keys.map((k) {
                              var c = Map<String, dynamic>.from(boxClientes.get(k) as Map);
                              c['id'] = k;
                              return c;
                            }).where((c) {
                              String q = textEditingValue.text.toLowerCase();
                              String nom = "${c['nombre']} ${c['apellido'] ?? ''}".toLowerCase();
                              String ced = (c['cedula'] ?? '').toString().toLowerCase();
                              return nom.contains(q) || ced.contains(q);
                            });
                          },
                          onSelected: (selection) {
                            setDialogState(() {
                              clienteIdSeleccionado = selection['id'].toString();
                            });
                          },
                          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              decoration: const InputDecoration(labelText: 'Buscar por Nombre o Cédula del Cliente', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_search)),
                            );
                          },
                        ),
                        const SizedBox(height: 15),
                      ],

                      const Divider(),
                      const Text('Métodos de Pago (USD)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: efvoUsdCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Efectivo USD'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: zelleCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Zelle'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: binanceCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Binance'))),
                        ],
                      ),
                      const SizedBox(height: 15),

                      const Text('Métodos de Pago (BS) - Ingrese el monto en USD equivalente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: efvoBsCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Efvo BS (USD)'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: pagoMovilBsCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pago Móvil (USD)'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: transfBsCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Transf. (USD)'))),
                        ],
                      ),
                      const SizedBox(height: 15),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: restanteUsd <= 0.05 ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total a Pagar:', style: TextStyle(fontWeight: FontWeight.bold)), Text('\$${precioUnitario.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                            const Divider(),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Ingresado (USD):'), Text('\$${totalPagadoEnUsd.toStringAsFixed(2)}')]),
                            if (dolaresParaPagarEnBs > 0)
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('A cobrar en Bolívares (BS):', style: TextStyle(fontStyle: FontStyle.italic)), Text('Bs. ${totalBsFisicosACobrar.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))]),
                            const Divider(),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(restanteUsd > 0 ? 'Falta por pagar:' : 'Vuelto / Sobrante:', style: TextStyle(fontWeight: FontWeight.bold, color: restanteUsd > 0 ? Colors.red : Colors.green)),
                              Text('\$${restanteUsd.abs().toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: restanteUsd > 0 ? Colors.red : Colors.green)),
                            ]),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.save),
                  label: const Text('Procesar Venta'),
                  onPressed: productoSeleccionado == null || restanteUsd > 0.05 || (esMembresiaOAsociado && clienteIdSeleccionado == null) ? null : () async {
                    List<Map<String, dynamic>> desglose = [];
                    List<String> metodos = [];

                    if (parseD(efvoUsdCtrl.text) > 0) { desglose.add({'metodo': 'Efectivo USD', 'monto': parseD(efvoUsdCtrl.text)}); metodos.add('Efectivo USD'); }
                    if (parseD(zelleCtrl.text) > 0) { desglose.add({'metodo': 'Zelle', 'monto': parseD(zelleCtrl.text)}); metodos.add('Zelle'); }
                    if (parseD(binanceCtrl.text) > 0) { desglose.add({'metodo': 'Binance', 'monto': parseD(binanceCtrl.text)}); metodos.add('Binance'); }
                    if (parseD(efvoBsCtrl.text) > 0) { desglose.add({'metodo': 'Efectivo BS', 'monto': parseD(efvoBsCtrl.text)}); metodos.add('Efectivo BS'); }
                    if (parseD(pagoMovilBsCtrl.text) > 0) { desglose.add({'metodo': 'Pago Móvil', 'monto': parseD(pagoMovilBsCtrl.text)}); metodos.add('Pago Móvil'); }
                    if (parseD(transfBsCtrl.text) > 0) { desglose.add({'metodo': 'Transferencia BS', 'monto': parseD(transfBsCtrl.text)}); metodos.add('Transf. BS'); }

                    final hoy = DateTime.now();
                    final idVenta = hoy.millisecondsSinceEpoch.toString();
                    
                    final nuevaVenta = {
                      'id': idVenta,
                      'concepto': productoSeleccionado,
                      'monto': precioUnitario,
                      'metodoPago': metodos.length == 1 ? metodos.first : 'MIXTO',
                      'pagosDetalle': desglose,
                      'clienteId': clienteIdSeleccionado,
                      'fecha': "${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}",
                      'hora': "${hoy.hour}:${hoy.minute.toString().padLeft(2, '0')}",
                    };

                    await Hive.box(obtenerNombreBoxSede('ventasBox')).put(idVenta, nuevaVenta);
                    if (mounted) setState(() {}); // Refresca localmente

                    if (esMembresiaOAsociado && clienteIdSeleccionado != null) {
                      var clienteBox = Hive.box(obtenerNombreBoxSede('clientsBox'));
                      var cliData = clienteBox.get(clienteIdSeleccionado);
                      if (cliData != null) {
                        var cMap = Map<String, dynamic>.from(cliData as Map);
                        DateTime fInicio = DateTime.now();
                        DateTime fVence = DateTime.now().add(const Duration(days: 30));
                        cMap['fechaInicio'] = "${fInicio.day.toString().padLeft(2, '0')}/${fInicio.month.toString().padLeft(2, '0')}/${fInicio.year}";
                        cMap['fechaVencimiento'] = "${fVence.day.toString().padLeft(2, '0')}/${fVence.month.toString().padLeft(2, '0')}/${fVence.year}";
                        cMap['metodoPago'] = nuevaVenta['metodoPago'];
                        await clienteBox.put(clienteIdSeleccionado, cMap);
                      }
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta procesada con éxito.'), backgroundColor: Colors.green));
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

  @override
  Widget build(BuildContext context) {
    String boxVentasNombre = obtenerNombreBoxSede('ventasBox');
    bool esAdmin = widget.usuarioActual['rol'] == 'Administrador' || widget.usuarioActual['permisosEdicion'] == true;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ventas Diarias', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                  onPressed: () => _abrirModalNuevaVenta(context),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('VENDER PRODUCTO / MEMBRESÍA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 2),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box(boxVentasNombre).listenable(),
                builder: (context, Box box, _) {
                  if (box.isEmpty) return const Center(child: Text('No hay ventas registradas.', style: TextStyle(color: Colors.grey, fontSize: 16)));

                  final hoy = DateTime.now();
                  final fechaHoy = "${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}";

                  var ventasHoyKeys = box.keys.where((k) {
                    var v = box.get(k);
                    if (v == null) return false;
                    var mapV = Map<String, dynamic>.from(v as Map);
                    return mapV['fecha'] == fechaHoy;
                  }).toList().reversed.toList();

                  if (ventasHoyKeys.isEmpty) {
                    return const Center(child: Text('No hay ventas registradas para el día de hoy.', style: TextStyle(color: Colors.grey, fontSize: 16)));
                  }

                  return ListView.builder(
                    itemCount: ventasHoyKeys.length,
                    itemBuilder: (context, index) {
                      String key = ventasHoyKeys[index].toString();
                      var venta = Map<String, dynamic>.from(box.get(key) as Map);

                      String concepto = venta['concepto'] ?? 'Producto General';
                      double monto = double.tryParse(venta['monto']?.toString() ?? '0') ?? 0.0;
                      String metodo = venta['metodoPago'] ?? 'Efectivo USD';
                      String hora = venta['hora'] ?? '';

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long, color: Colors.blue, size: 30),
                              const SizedBox(width: 20),
                              
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(concepto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('Hora: $hora', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),

                              Expanded(
                                flex: 1,
                                child: Text('\$${monto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                              ),

                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                  child: Text(metodo, textAlign: TextAlign.center, style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),

                              const SizedBox(width: 20),

                              if (esAdmin)
                                IconButton(
                                  icon: const Icon(Icons.edit_note, color: Colors.orange, size: 28),
                                  tooltip: 'Modificar o Eliminar Venta',
                                  onPressed: () => _modificarVenta(key, venta),
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
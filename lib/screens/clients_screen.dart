import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../helpers.dart';
import '../pantalla_registro.dart';

class ClientsScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioActual;
  final String? clienteIdSeleccionado;

  const ClientsScreen({super.key, required this.usuarioActual, this.clienteIdSeleccionado});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  @override
  void initState() {
    super.initState();
    _revisarBusquedaGlobal();
  }

  @override
  void didUpdateWidget(covariant ClientsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clienteIdSeleccionado != oldWidget.clienteIdSeleccionado) {
      _revisarBusquedaGlobal();
    }
  }

  void _revisarBusquedaGlobal() {
    if (widget.clienteIdSeleccionado != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarFichaDialog(widget.clienteIdSeleccionado!);
      });
    }
  }

  Uint8List? _obtenerImagenSegura(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;
    try {
      String cleanString = base64String.contains(',') ? base64String.split(',').last : base64String;
      cleanString = cleanString.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(cleanString);
    } catch (e) {
      return null;
    }
  }

  void _mostrarFichaDialog(String clienteId) {
    bool esAdmin = widget.usuarioActual['rol'] == 'Administrador';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: SizedBox(
          width: 550,
          height: 600,
          child: FichaClienteWidget(clienteId: clienteId, esAdmin: esAdmin),
        ),
      ),
    );
  }

  Future<void> _registrarAccesoManual(String clienteId, Map<String, dynamic> cliente) async {
    var boxAccesos = Hive.box(obtenerNombreBoxSede('accesosBox'));
    final hoy = DateTime.now();
    final idAcceso = hoy.millisecondsSinceEpoch.toString();

    bool estaActivo = false;
    String fVencimiento = cliente['fechaVencimiento']?.toString() ?? '';
    if (fVencimiento.isNotEmpty && fVencimiento.contains('/')) {
      try {
        var parts = fVencimiento.split('/');
        DateTime vDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        DateTime hoyDate = DateTime(hoy.year, hoy.month, hoy.day);
        if (vDate.isAfter(hoyDate) || vDate.isAtSameMomentAs(hoyDate)) estaActivo = true;
      } catch (e) {}
    }

    final nuevoAcceso = {
      'id': idAcceso,
      'clienteId': clienteId,
      'nombre': "${cliente['nombre']} ${cliente['apellido'] ?? ''}",
      'cedula': cliente['cedula'],
      'fecha': "${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}",
      'hora': "${hoy.hour}:${hoy.minute.toString().padLeft(2, '0')}",
      'estado': estaActivo ? 'ACCESO PERMITIDO' : 'ACCESO DENEGADO (VENCIDO)',
      'metodo': 'MANUAL',
    };

    await boxAccesos.put(idAcceso, nuevoAcceso);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(estaActivo ? 'Acceso concedido exitosamente.' : 'Acceso denegado. Membresía vencida.'),
        backgroundColor: estaActivo ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    String boxClientesNombre = obtenerNombreBoxSede('clientsBox');

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Directorio de Clientes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                  onPressed: () => showDialog(context: context, builder: (_) => const PantallaRegistro()),
                  icon: const Icon(Icons.person_add),
                  label: const Text('REGISTRAR NUEVO CLIENTE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  SizedBox(width: 40, child: Text('N°', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 50, child: Text('Foto', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Nombre y Apellido', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Cédula', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 150, child: Text('Acciones', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box(boxClientesNombre).listenable(),
                builder: (context, Box box, _) {
                  if (box.isEmpty) return const Center(child: Text('No hay clientes registrados.', style: TextStyle(color: Colors.grey, fontSize: 16)));

                  var clientesKeys = box.keys.toList();

                  return ListView.builder(
                    itemCount: clientesKeys.length,
                    itemBuilder: (context, index) {
                      String key = clientesKeys[index].toString();
                      var cliente = Map<String, dynamic>.from(box.get(key) as Map);
                      Uint8List? img = _obtenerImagenSegura(cliente['fotoBase64']);

                      bool estaActivo = false;
                      String fVencimiento = cliente['fechaVencimiento']?.toString() ?? '';
                      if (fVencimiento.isNotEmpty && fVencimiento.contains('/')) {
                        try {
                          var parts = fVencimiento.split('/');
                          DateTime vDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                          DateTime hoyDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                          if (vDate.isAfter(hoyDate) || vDate.isAtSameMomentAs(hoyDate)) estaActivo = true;
                        } catch (e) {}
                      }

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 40, child: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey))),
                              SizedBox(
                                width: 50,
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: img != null ? MemoryImage(img) : null,
                                  backgroundColor: Colors.blue.shade50,
                                  child: img == null ? const Icon(Icons.person, size: 24, color: Colors.blue) : null,
                                ),
                              ),
                              Expanded(flex: 2, child: Text("${cliente['nombre']} ${cliente['apellido'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                              Expanded(flex: 1, child: Text("${cliente['cedula']}", style: TextStyle(color: Colors.grey.shade700))),
                              Expanded(
                                flex: 1,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: estaActivo ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(10)),
                                    child: Text(estaActivo ? 'ACTIVO' : 'INACTIVO', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Tooltip(
                                      message: 'Dar Entrada Manual',
                                      child: IconButton(icon: const Icon(Icons.login, color: Colors.green), onPressed: () => _registrarAccesoManual(key, cliente)),
                                    ),
                                    Tooltip(
                                      message: 'Ver Ficha',
                                      child: IconButton(icon: const Icon(Icons.assignment_ind, color: Colors.blue), onPressed: () => _mostrarFichaDialog(key)),
                                    ),
                                  ],
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
      ),
    );
  }
}

// --- WIDGET PARA LA FICHA FLOTANTE ---
class FichaClienteWidget extends StatefulWidget {
  final String clienteId;
  final bool esAdmin;

  const FichaClienteWidget({super.key, required this.clienteId, required this.esAdmin});

  @override
  State<FichaClienteWidget> createState() => _FichaClienteWidgetState();
}

class _FichaClienteWidgetState extends State<FichaClienteWidget> {
  Uint8List? _obtenerImagenSegura(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;
    try {
      String cleanString = base64String.contains(',') ? base64String.split(',').last : base64String;
      cleanString = cleanString.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(cleanString);
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      var parts = dateStr.split('/');
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    } catch (e) {
      return null;
    }
  }

  void _editarMembresiaAdmin(BuildContext context, Map<String, dynamic> cliente) {
    DateTime fechaInicio = _parseDate(cliente['fechaInicio']) ?? DateTime.now();
    DateTime fechaVence = _parseDate(cliente['fechaVencimiento']) ?? DateTime.now().add(const Duration(days: 30));

    String metodoPagoSeleccionado = cliente['metodoPago'] ?? 'Efectivo USD';
    List<String> metodosPermitidos = ['Efectivo USD', 'Efectivo BS', 'Pago Móvil', 'Transferencia BS', 'Zelle', 'Binance', 'MIXTO'];
    if (!metodosPermitidos.contains(metodoPagoSeleccionado) && metodoPagoSeleccionado.isNotEmpty) {
      metodosPermitidos.add(metodoPagoSeleccionado);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> seleccionarFecha(bool esInicio) async {
              final DateTime? seleccion = await showDatePicker(context: context, initialDate: esInicio ? fechaInicio : fechaVence, firstDate: DateTime(2020), lastDate: DateTime(2035));
              if (seleccion != null) setDialogState(() {
                if (esInicio) fechaInicio = seleccion; else fechaVence = seleccion;
              });
            }

            return AlertDialog(
              title: Text('Editar Membresía (ADMIN) - ${cliente['nombre']}', style: const TextStyle(color: Colors.blue)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: () => seleccionarFecha(true),
                        child: Column(children: [const Text('Inició el:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), Text("${fechaInicio.day.toString().padLeft(2, '0')}/${fechaInicio.month.toString().padLeft(2, '0')}/${fechaInicio.year}")]),
                      ),
                      const Icon(Icons.edit_calendar, color: Colors.grey),
                      InkWell(
                        onTap: () => seleccionarFecha(false),
                        child: Column(children: [const Text('Vence el:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), Text("${fechaVence.day.toString().padLeft(2, '0')}/${fechaVence.month.toString().padLeft(2, '0')}/${fechaVence.year}")]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  DropdownButtonFormField<String>(
                    value: metodoPagoSeleccionado.isEmpty ? 'Efectivo USD' : metodoPagoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Forma de Pago Registrada', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payment)),
                    items: metodosPermitidos.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => metodoPagoSeleccionado = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                  onPressed: () async {
                    String fInicioStr = "${fechaInicio.day.toString().padLeft(2, '0')}/${fechaInicio.month.toString().padLeft(2, '0')}/${fechaInicio.year}";
                    String fVenceStr = "${fechaVence.day.toString().padLeft(2, '0')}/${fechaVence.month.toString().padLeft(2, '0')}/${fechaVence.year}";
                    var clienteFicha = Map<String, dynamic>.from(cliente);
                    clienteFicha['fechaInicio'] = fInicioStr;
                    clienteFicha['fechaVencimiento'] = fVenceStr;
                    clienteFicha['metodoPago'] = metodoPagoSeleccionado;
                    await Hive.box(obtenerNombreBoxSede('clientsBox')).put(widget.clienteId, clienteFicha);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      }
    );
  }

  // --- LÓGICA DE VENTAS CON CÁLCULO INVERTIDO (SE INGRESA USD, SE COBRAN BS) ---
  Future<void> _venderMembresia(BuildContext context, Map<String, dynamic> cliente) async {
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
      productosUnicos['Membresía Básica (Por defecto)'] = 30.0;
    }

    final double tasaUsd = Hive.box('configBox').get('tasa_usd', defaultValue: 1.0);
    
    String? productoSeleccionado;
    double totalFacturaUsd = 0.0; 
    
    final TextEditingController efvoUsdCtrl = TextEditingController();
    final TextEditingController zelleCtrl = TextEditingController();
    final TextEditingController binanceCtrl = TextEditingController();
    final TextEditingController efvoBsCtrl = TextEditingController();
    final TextEditingController pagoMovilBsCtrl = TextEditingController();
    final TextEditingController transfBsCtrl = TextEditingController();

    DateTime fechaInicio = DateTime.now();
    DateTime fechaCierre = DateTime.now().add(const Duration(days: 30));

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void recalcular() => setDialogState(() {});
            double parseD(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;

            // Pagos Directos en USD
            double pagadoDirectoUsd = parseD(efvoUsdCtrl.text) + parseD(zelleCtrl.text) + parseD(binanceCtrl.text);
            
            // EL CAJERO INGRESA USD A PAGAR EN BS -> EL SISTEMA CALCULA CUÁNTOS BS DEBE COBRAR
            double dolaresParaPagarEnBs = parseD(efvoBsCtrl.text) + parseD(pagoMovilBsCtrl.text) + parseD(transfBsCtrl.text);
            double totalBsFisicosACobrar = dolaresParaPagarEnBs * tasaUsd;
            
            double totalPagadoEnUsd = pagadoDirectoUsd + dolaresParaPagarEnBs;
            double restanteUsd = totalFacturaUsd - totalPagadoEnUsd;

            return AlertDialog(
              title: Text('Vender Membresía - ${cliente['nombre']}'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 600,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                        decoration: const InputDecoration(labelText: 'Seleccionar Producto o Membresía', border: OutlineInputBorder(), prefixIcon: Icon(Icons.inventory_2)),
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
                              totalFacturaUsd = productosUnicos[val] ?? 0.0; 
                            });
                          }
                        },
                      ),
                      const Divider(height: 30),
                      
                      const Align(alignment: Alignment.centerLeft, child: Text('Métodos de Pago (USD)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
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
                      const SizedBox(height: 20),
                      
                      const Align(alignment: Alignment.centerLeft, child: Text('Métodos de Pago (BS) - Ingrese el monto en USD a pagar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: efvoBsCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Efvo BS (en USD)'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: pagoMovilBsCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pago Móvil (en USD)'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: transfBsCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Transf. BS (en USD)'))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // --- TICKET DE SUBTOTAL DETALLADO ---
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: restanteUsd <= 0.05 ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: restanteUsd <= 0.05 ? Colors.green : Colors.red.shade300)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DETALLE DEL COBRO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total a Pagar:', style: TextStyle(fontSize: 16)), Text('\$${totalFacturaUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                            const Divider(),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Pagado en Divisas (USD):', style: TextStyle(color: Colors.green)), Text('\$${pagadoDirectoUsd.toStringAsFixed(2)}')]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Pagado en Bolívares (Valor en USD):', style: TextStyle(color: Colors.blue)), Text('\$${dolaresParaPagarEnBs.toStringAsFixed(2)}')]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Monto a transferir/pagar en Bolívares:', style: TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)), Text('Bs. ${totalBsFisicosACobrar.toStringAsFixed(2)}', style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold))]),
                            const Divider(thickness: 2),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL INGRESADO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('\$${totalPagadoEnUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                            const SizedBox(height: 5),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(restanteUsd > 0 ? 'FALTA POR PAGAR:' : 'VUELTO / SOBRANTE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: restanteUsd > 0 ? Colors.red : Colors.green)),
                              Text('\$${restanteUsd.abs().toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: restanteUsd > 0 ? Colors.red : Colors.green)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  icon: const Icon(Icons.save),
                  label: const Text('Procesar y Activar', style: TextStyle(fontSize: 16)),
                  onPressed: (totalFacturaUsd <= 0 || restanteUsd > 0.05 || productoSeleccionado == null) ? null : () async {
                    List<Map<String, dynamic>> desglose = [];
                    List<String> nombresMetodos = [];
                    
                    if (parseD(efvoUsdCtrl.text) > 0) { desglose.add({'metodo': 'Efectivo USD', 'monto': parseD(efvoUsdCtrl.text)}); nombresMetodos.add('Efectivo USD'); }
                    if (parseD(zelleCtrl.text) > 0) { desglose.add({'metodo': 'Zelle', 'monto': parseD(zelleCtrl.text)}); nombresMetodos.add('Zelle'); }
                    if (parseD(binanceCtrl.text) > 0) { desglose.add({'metodo': 'Binance', 'monto': parseD(binanceCtrl.text)}); nombresMetodos.add('Binance'); }
                    if (parseD(efvoBsCtrl.text) > 0) { desglose.add({'metodo': 'Efectivo BS', 'monto': parseD(efvoBsCtrl.text)}); nombresMetodos.add('Efectivo BS'); }
                    if (parseD(pagoMovilBsCtrl.text) > 0) { desglose.add({'metodo': 'Pago Móvil', 'monto': parseD(pagoMovilBsCtrl.text)}); nombresMetodos.add('Pago Móvil'); }
                    if (parseD(transfBsCtrl.text) > 0) { desglose.add({'metodo': 'Transferencia BS', 'monto': parseD(transfBsCtrl.text)}); nombresMetodos.add('Transferencia BS'); }

                    final idVenta = DateTime.now().millisecondsSinceEpoch.toString();
                    final nuevaVenta = {
                      'id': idVenta,
                      'concepto': productoSeleccionado != null ? 'Venta: $productoSeleccionado' : 'Membresía (${fechaInicio.day}/${fechaInicio.month} al ${fechaCierre.day}/${fechaCierre.month})',
                      'monto': totalFacturaUsd,
                      'metodoPago': 'MIXTO',
                      'pagosDetalle': desglose,
                      'clienteId': widget.clienteId, 
                      'fecha': "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}",
                      'hora': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                    };
                    await Hive.box(obtenerNombreBoxSede('ventasBox')).put(idVenta, nuevaVenta);

                    String fInicioStr = "${fechaInicio.day.toString().padLeft(2, '0')}/${fechaInicio.month.toString().padLeft(2, '0')}/${fechaInicio.year}";
                    String fVenceStr = "${fechaCierre.day.toString().padLeft(2, '0')}/${fechaCierre.month.toString().padLeft(2, '0')}/${fechaCierre.year}";
                    
                    var clienteFicha = Map<String, dynamic>.from(cliente);
                    clienteFicha['fechaInicio'] = fInicioStr;
                    clienteFicha['fechaVencimiento'] = fVenceStr;
                    clienteFicha['metodoPago'] = nombresMetodos.length == 1 ? nombresMetodos.first : 'MIXTO';
                    
                    await Hive.box(obtenerNombreBoxSede('clientsBox')).put(widget.clienteId, clienteFicha);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta procesada exitosamente.'), backgroundColor: Colors.green));
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
    String boxClientesNombre = obtenerNombreBoxSede('clientsBox');
    String boxAccesosNombre = obtenerNombreBoxSede('accesosBox');

    return ValueListenableBuilder(
      valueListenable: Hive.box(boxClientesNombre).listenable(),
      builder: (context, Box box, _) {
        var c = box.get(widget.clienteId);
        if (c == null) return const Center(child: Text('Cliente no encontrado'));
        var cliente = Map<String, dynamic>.from(c as Map);
        cliente['id'] = widget.clienteId; 
        Uint8List? profileImg = _obtenerImagenSegura(cliente['fotoBase64']);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.black12)), borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
              child: Row(
                children: [
                  CircleAvatar(radius: 40, backgroundColor: Colors.blue.shade50, backgroundImage: profileImg != null ? MemoryImage(profileImg) : null, child: profileImg == null ? const Icon(Icons.camera_alt, size: 30, color: Colors.grey) : null),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${cliente['nombre']} ${cliente['apellido'] ?? ''}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text("C.I: ${cliente['cedula']}", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (widget.esAdmin)
                              OutlinedButton.icon(icon: const Icon(Icons.edit, size: 14), label: const Text('Editar', style: TextStyle(fontSize: 12)), onPressed: () => _editarMembresiaAdmin(context, cliente)),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 15)),
                              icon: const Icon(Icons.payment, size: 14),
                              label: const Text('Vender / Renovar', style: TextStyle(fontSize: 12)),
                              onPressed: () => _venderMembresia(context, cliente),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))
                ],
              ),
            ),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(labelColor: Colors.blue, unselectedLabelColor: Colors.grey, tabs: [Tab(text: 'Datos'), Tab(text: 'Accesos')]),
                    Expanded(
                      child: TabBarView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(25.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Teléfono: ${cliente['telefono'] ?? 'N/D'}', style: const TextStyle(fontSize: 14)),
                                const Divider(height: 25),
                                Text('Dirección: ${cliente['direccion'] ?? 'N/D'}', style: const TextStyle(fontSize: 14)),
                                const Divider(height: 25),
                                Text('Forma de Pago: ${cliente['metodoPago'] ?? 'No registrada'}', style: const TextStyle(fontSize: 14)),
                                const Divider(height: 25),
                                Text('Inicio: ${cliente['fechaInicio'] ?? 'N/D'}', style: const TextStyle(fontSize: 14, color: Colors.blue)),
                                const SizedBox(height: 8),
                                Text('Vencimiento: ${cliente['fechaVencimiento'] == '' ? 'INACTIVO' : cliente['fechaVencimiento']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                          ),
                          ValueListenableBuilder(
                            valueListenable: Hive.box(boxAccesosNombre).listenable(),
                            builder: (context, boxAccesos, _) {
                              var accesosCliente = boxAccesos.values.map((e) => Map<String, dynamic>.from(e as Map)).where((a) => a['clienteId'] == widget.clienteId).toList().reversed.toList();
                              if (accesosCliente.isEmpty) return const Center(child: Text('Sin entradas.', style: TextStyle(fontSize: 14)));
                              return ListView.builder(
                                itemCount: accesosCliente.length,
                                itemBuilder: (context, i) {
                                  var acc = accesosCliente[i];
                                  bool ok = acc['estado'] == 'ACCESO PERMITIDO';
                                  return ListTile(
                                    leading: Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? Colors.green : Colors.red, size: 20),
                                    title: Text(acc['fecha'] ?? '', style: const TextStyle(fontSize: 14)),
                                    trailing: Text(acc['hora'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
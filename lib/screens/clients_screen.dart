import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../helpers.dart';
import '../pantalla_registro.dart'; // Importación corregida apuntando a lib/

class ClientsScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioActual;

  const ClientsScreen({super.key, required this.usuarioActual});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _clienteSeleccionado;
  String? _clienteSeleccionadoId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _seleccionarCliente(String id, Map<String, dynamic> cliente) {
    setState(() {
      _clienteSeleccionadoId = id;
      _clienteSeleccionado = cliente;
    });
  }

  void _registrarPagoMixto(BuildContext context) {
    if (_clienteSeleccionado == null) {
      return;
    }

    final configBox = Hive.box('configBox');
    final double tasaUsd = configBox.get('tasa_usd', defaultValue: 1.0);

    final TextEditingController montoTotalUsdCtrl = TextEditingController();
    final TextEditingController pagoEfectivoUsdCtrl = TextEditingController();
    final TextEditingController pagoZelleCtrl = TextEditingController();
    final TextEditingController pagoEfectivoBsCtrl = TextEditingController();
    final TextEditingController pagoMovilBsCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void recalcular() {
              setDialogState(() {});
            }

            double parseDouble(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;

            double totalFacturaUsd = parseDouble(montoTotalUsdCtrl.text);
            double ingresadoUsd = parseDouble(pagoEfectivoUsdCtrl.text) + parseDouble(pagoZelleCtrl.text);
            double ingresadoBs = parseDouble(pagoEfectivoBsCtrl.text) + parseDouble(pagoMovilBsCtrl.text);
            
            // Convertir los Bs a USD para el cálculo
            double ingresadoBsEnUsd = ingresadoBs > 0 && tasaUsd > 0 ? ingresadoBs / tasaUsd : 0.0;
            double totalIngresadoUsd = ingresadoUsd + ingresadoBsEnUsd;
            double restanteUsd = totalFacturaUsd - totalIngresadoUsd;

            return AlertDialog(
              title: Text('Pago de Membresía - ${_clienteSeleccionado!['nombre']}'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.blue.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TASA BCV ACTUAL:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Bs. ${tasaUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: montoTotalUsdCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => recalcular(),
                        decoration: const InputDecoration(labelText: 'Monto Total de Membresía (USD)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                      ),
                      const SizedBox(height: 20),
                      const Text('Formas de Pago Mixto:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: pagoEfectivoUsdCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Efectivo (USD)', prefixIcon: Icon(Icons.money)))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: pagoZelleCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Zelle / Digital (USD)', prefixIcon: Icon(Icons.phone_android)))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: pagoEfectivoBsCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Efectivo (BS)', prefixIcon: Icon(Icons.payments, color: Colors.green)))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: pagoMovilBsCtrl, onChanged: (_) => recalcular(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pago Móvil (BS)', prefixIcon: Icon(Icons.account_balance, color: Colors.green)))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: restanteUsd <= 0.01 ? Colors.green.shade100 : Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('Total Ingresado:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('\$${totalIngresadoUsd.toStringAsFixed(2)}  /  Bs. ${(totalIngresadoUsd * tasaUsd).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ]),
                            const Divider(),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(restanteUsd > 0 ? 'Falta por pagar:' : 'Vuelto / Sobrante:', style: TextStyle(fontWeight: FontWeight.bold, color: restanteUsd > 0 ? Colors.red : Colors.green)),
                              Text('\$${restanteUsd.abs().toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: restanteUsd > 0 ? Colors.red : Colors.green)),
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
                  label: const Text('Procesar Factura'),
                  onPressed: totalFacturaUsd <= 0 || restanteUsd > 0.05 ? null : () async {
                    List<Map<String, dynamic>> desglose = [];
                    if (parseDouble(pagoEfectivoUsdCtrl.text) > 0) desglose.add({'metodo': 'Efectivo USD', 'monto': parseDouble(pagoEfectivoUsdCtrl.text)});
                    if (parseDouble(pagoZelleCtrl.text) > 0) desglose.add({'metodo': 'Zelle', 'monto': parseDouble(pagoZelleCtrl.text)});
                    if (parseDouble(pagoEfectivoBsCtrl.text) > 0) desglose.add({'metodo': 'Efectivo BS', 'monto': parseDouble(pagoEfectivoBsCtrl.text) / tasaUsd});
                    if (parseDouble(pagoMovilBsCtrl.text) > 0) desglose.add({'metodo': 'Pago Móvil', 'monto': parseDouble(pagoMovilBsCtrl.text) / tasaUsd});

                    final hoy = DateTime.now();
                    final nuevaVenta = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'concepto': 'Renovación Membresía',
                      'monto': totalFacturaUsd,
                      'metodoPago': 'MIXTO',
                      'pagosDetalle': desglose,
                      'clienteId': _clienteSeleccionadoId,
                      'cliente': _clienteSeleccionado!['nombre'],
                      'fecha': "${hoy.day.toString().padLeft(2,'0')}/${hoy.month.toString().padLeft(2,'0')}/${hoy.year}",
                      'hora': "${hoy.hour}:${hoy.minute.toString().padLeft(2, '0')}",
                    };
                    
                    await Hive.box(obtenerNombreBoxSede('ventasBox')).put(nuevaVenta['id'], nuevaVenta);
                    
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago de membresía registrado con éxito'), backgroundColor: Colors.green));
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
    bool esAdmin = widget.usuarioActual['rol'] == 'Administrador';

    return Scaffold(
      appBar: AppBar(
        title: Text('Gala Gym - Gestión de Clientes (${obtenerSedeActual().toUpperCase()})'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // --- PANEL IZQUIERDO: BUSCADOR Y LISTA DE CLIENTES ---
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Buscar por Cédula o Nombre',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                        icon: const Icon(Icons.person_add),
                        label: const Text('NUEVO CLIENTE', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          // Const eliminado para evitar error de compilación
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PantallaRegistro()), 
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: Hive.box(boxClientesNombre).listenable(),
                      builder: (context, Box box, _) {
                        if (box.isEmpty) {
                          return const Center(child: Text('No hay clientes registrados en esta sede.', style: TextStyle(fontSize: 16, color: Colors.grey)));
                        }

                        var clientesFiltrados = box.keys.where((key) {
                          var c = box.get(key);
                          String nombreCompleto = "${c['nombre']} ${c['apellido'] ?? ''}".toLowerCase();
                          String cedula = (c['cedula'] ?? '').toString().toLowerCase();
                          return nombreCompleto.contains(_searchQuery) || cedula.contains(_searchQuery);
                        }).toList();

                        if (clientesFiltrados.isEmpty) {
                          return const Center(child: Text('No se encontraron coincidencias.', style: TextStyle(color: Colors.grey)));
                        }

                        return ListView.builder(
                          itemCount: clientesFiltrados.length,
                          itemBuilder: (context, index) {
                            String key = clientesFiltrados[index].toString();
                            var cliente = Map<String, dynamic>.from(box.get(key) as Map);
                            bool seleccionado = key == _clienteSeleccionadoId;

                            return Card(
                              color: seleccionado ? Colors.blue.shade50 : Colors.white,
                              elevation: seleccionado ? 3 : 1,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: cliente['fotoBase64'] != null && cliente['fotoBase64'].toString().isNotEmpty
                                      ? MemoryImage(base64Decode(cliente['fotoBase64']))
                                      : null,
                                  child: cliente['fotoBase64'] == null || cliente['fotoBase64'].toString().isEmpty
                                      ? const Icon(Icons.person, color: Colors.blue) : null,
                                ),
                                title: Text("${cliente['nombre']} ${cliente['apellido'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('C.I: ${cliente['cedula']}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _seleccionarCliente(key, cliente),
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
          ),
          
          const VerticalDivider(width: 1, thickness: 1),

          // --- PANEL DERECHO: FICHA COMPLETA DEL CLIENTE ---
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade50,
              child: _clienteSeleccionado == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_ind, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Seleccione un cliente para ver su ficha', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // ENCABEZADO DE LA FICHA
                        Container(
                          padding: const EdgeInsets.all(20),
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(bottom: BorderSide(color: Colors.black12)),
                          ),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.blue.shade50,
                                backgroundImage: _clienteSeleccionado!['fotoBase64'] != null && _clienteSeleccionado!['fotoBase64'].toString().isNotEmpty
                                    ? MemoryImage(base64Decode(_clienteSeleccionado!['fotoBase64']))
                                    : null,
                                child: _clienteSeleccionado!['fotoBase64'] == null || _clienteSeleccionado!['fotoBase64'].toString().isEmpty
                                    ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey) : null,
                              ),
                              const SizedBox(height: 15),
                              Text("${_clienteSeleccionado!['nombre']} ${_clienteSeleccionado!['apellido'] ?? ''}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text("C.I: ${_clienteSeleccionado!['cedula']}", style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                              const SizedBox(height: 15),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (esAdmin)
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Editar Ficha'),
                                      onPressed: () {
                                        // Aquí puedes conectar tu lógica de edición
                                      },
                                    ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    icon: const Icon(Icons.payment, size: 16),
                                    label: const Text('Registrar Pago'),
                                    onPressed: () => _registrarPagoMixto(context),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        
                        // PESTAÑAS (TABS)
                        Expanded(
                          child: DefaultTabController(
                            length: 3,
                            child: Column(
                              children: [
                                const TabBar(
                                  labelColor: Colors.blue,
                                  unselectedLabelColor: Colors.grey,
                                  tabs: [
                                    Tab(text: 'Datos'),
                                    Tab(text: 'Notas'),
                                    Tab(text: 'Accesos'),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    children: [
                                      // TAB 1: DATOS GENERALES
                                      Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _DetalleItem(icono: Icons.phone, titulo: 'Teléfono', valor: _clienteSeleccionado!['telefono'] ?? 'N/D'),
                                            const Divider(),
                                            _DetalleItem(icono: Icons.location_on, titulo: 'Dirección', valor: _clienteSeleccionado!['direccion'] ?? 'N/D'),
                                            const Divider(),
                                            _DetalleItem(icono: Icons.calendar_month, titulo: 'Vencimiento', valor: _clienteSeleccionado!['fechaVencimiento'] ?? 'N/D'),
                                            const Divider(),
                                            Row(
                                              children: [
                                                Icon(Icons.fingerprint, color: _clienteSeleccionado!['huella'] != null ? Colors.green : Colors.grey),
                                                const SizedBox(width: 15),
                                                Text(_clienteSeleccionado!['huella'] != null ? 'Huella Registrada' : 'Sin huella registrada', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // TAB 2: NOTAS
                                      Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(15),
                                                decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.yellow.shade400)),
                                                child: Text(_clienteSeleccionado!['notas'] ?? 'No hay notas para este cliente.', style: const TextStyle(fontStyle: FontStyle.italic)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // TAB 3: REGISTRO DE ENTRADA
                                      ValueListenableBuilder(
                                        valueListenable: Hive.box(boxAccesosNombre).listenable(),
                                        builder: (context, boxAccesos, _) {
                                          var accesosCliente = boxAccesos.values
                                              .map((e) => Map<String, dynamic>.from(e as Map))
                                              .where((a) => a['clienteId'] == _clienteSeleccionadoId)
                                              .toList()
                                              .reversed
                                              .toList();

                                          if (accesosCliente.isEmpty) {
                                            return const Center(child: Text('No hay registros de entrada aún.'));
                                          }

                                          return ListView.builder(
                                            itemCount: accesosCliente.length,
                                            itemBuilder: (context, i) {
                                              var acc = accesosCliente[i];
                                              bool ok = acc['estado'] == 'ACCESO PERMITIDO';
                                              return ListTile(
                                                leading: Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? Colors.green : Colors.red),
                                                title: Text(acc['fecha'] ?? ''),
                                                subtitle: Text(acc['estado']),
                                                trailing: Text(acc['hora'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetalleItem extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;

  const _DetalleItem({required this.icono, required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
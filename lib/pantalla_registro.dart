import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'helpers.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _apellidoCtrl = TextEditingController();
  final TextEditingController _cedulaCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();

  List<CameraDescription> _availableCams = [];
  CameraController? _cameraController;
  
  bool _isCameraActive = false;
  bool _isInitializing = false; // Seguro anti doble-ejecución
  int _selectedCameraIndex = 0;
  String? _fotoBase64;
  bool _huellaRegistrada = false;

  @override
  void dispose() {
    _cameraController?.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cambiarCamara(int index) async {
    if (_availableCams.isEmpty || index >= _availableCams.length) return;
    
    // Evitar que el usuario presione varias veces mientras carga
    if (_isInitializing) return;

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _isCameraActive = false;
        _selectedCameraIndex = index;
      });
    }

    try {
      // Si ya hay una cámara, la cerramos y le damos tiempo a Windows para que la suelte
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
        await Future.delayed(const Duration(milliseconds: 300)); // El truco para evitar el error de hardware
      }

      _cameraController = CameraController(
        _availableCams[index],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraActive = true;
        });
      }
    } catch (e) {
      debugPrint("Error al inicializar la cámara: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fallo al conectar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _activarCamara() async {
    if (_isInitializing) return;
    
    try {
      if (mounted) {
        setState(() { _isInitializing = true; });
      }

      _availableCams = await availableCameras();
      
      if (_availableCams.isEmpty) {
        if (mounted) {
          setState(() { _isInitializing = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se detectó ninguna cámara conectada.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      if (mounted) {
        setState(() { _isInitializing = false; });
      }

      await _cambiarCamara(0);
    } catch (e) {
      debugPrint("Error al listar cámaras: $e");
      if (mounted) {
        setState(() { _isInitializing = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al acceder a los dispositivos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _tomarFoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      
      await _cameraController?.dispose();
      _cameraController = null;
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        setState(() {
          _fotoBase64 = base64Encode(bytes);
          _isCameraActive = false;
        });
      }
    } catch (e) {
      debugPrint("Error tomando foto: $e");
    }
  }

  Future<void> _guardarCliente(BuildContext context) async {
    if (_nombreCtrl.text.trim().isEmpty || _cedulaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre y la cédula son obligatorios.'), backgroundColor: Colors.red),
      );
      return;
    }

    String boxClientesNombre = obtenerNombreBoxSede('clientsBox');
    if (!Hive.isBoxOpen(boxClientesNombre)) await Hive.openBox(boxClientesNombre);
    var boxClientes = Hive.box(boxClientesNombre);

    final hoy = DateTime.now();
    final idCliente = hoy.millisecondsSinceEpoch.toString();
    final fInicioStr = "${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}";
    final fVence = hoy.add(const Duration(days: 30));
    final fVenceStr = "${fVence.day.toString().padLeft(2, '0')}/${fVence.month.toString().padLeft(2, '0')}/${fVence.year}";

    final nuevoCliente = {
      'id': idCliente,
      'nombre': _nombreCtrl.text.trim().toUpperCase(),
      'apellido': _apellidoCtrl.text.trim().toUpperCase(),
      'cedula': _cedulaCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim().toUpperCase(),
      'fotoBase64': _fotoBase64,
      'huella': _huellaRegistrada ? 'HUELLA_REGISTRADA' : null,
      'fechaInicio': fInicioStr,
      'fechaVencimiento': fVenceStr,
      'metodoPago': 'Efectivo USD',
    };

    await boxClientes.put(idCliente, nuevoCliente);

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente registrado exitosamente.'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SizedBox(
        width: 750,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Registro de Nuevo Cliente', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      if (_cameraController != null) {
                        await _cameraController!.dispose();
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          if (_availableCams.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(6)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedCameraIndex,
                                    isDense: true,
                                    isExpanded: true,
                                    items: List.generate(_availableCams.length, (index) {
                                      String nombreCam = _availableCams[index].name;
                                      return DropdownMenuItem(
                                        value: index,
                                        child: Text(
                                          nombreCam.length > 25 ? "${nombreCam.substring(0, 25)}..." : nombreCam,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    }),
                                    onChanged: _isInitializing ? null : (val) {
                                      if (val != null) _cambiarCamara(val);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                            child: _fotoBase64 != null && !_isCameraActive && !_isInitializing
                                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(_fotoBase64!.contains(',') ? _fotoBase64!.split(',').last : _fotoBase64!), fit: BoxFit.cover))
                                : _isInitializing 
                                    ? const Center(child: CircularProgressIndicator())
                                    : _isCameraActive && _cameraController != null && _cameraController!.value.isInitialized
                                        ? ClipRRect(borderRadius: BorderRadius.circular(10), child: CameraPreview(_cameraController!))
                                        : Center(
                                            child: TextButton.icon(
                                              icon: const Icon(Icons.camera_alt, size: 28),
                                              label: const Text('Activar Cámara', style: TextStyle(fontWeight: FontWeight.bold)),
                                              onPressed: _activarCamara,
                                            ),
                                          ),
                          ),
                          const SizedBox(height: 10),
                          if (_isCameraActive && !_isInitializing)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              onPressed: _tomarFoto,
                              icon: const Icon(Icons.camera),
                              label: const Text('Capturar Foto'),
                            ),
                          const Spacer(),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint, size: 40, color: _huellaRegistrada ? Colors.green : Colors.grey),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                                icon: const Icon(Icons.scanner),
                                label: Text(_huellaRegistrada ? 'Huella Registrada' : 'Escanear Huella'),
                                onPressed: () {
                                  setState(() { _huellaRegistrada = true; });
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Huella capturada correctamente.')));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 25),

                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Todos los campos son obligatorios.', style: TextStyle(color: Colors.red, fontSize: 12)),
                            const SizedBox(height: 15),
                            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombres', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
                            const SizedBox(height: 15),
                            TextField(controller: _apellidoCtrl, decoration: const InputDecoration(labelText: 'Apellidos', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
                            const SizedBox(height: 15),
                            TextField(controller: _cedulaCtrl, decoration: const InputDecoration(labelText: 'Cédula', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge))),
                            const SizedBox(height: 15),
                            TextField(controller: _telefonoCtrl, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
                            const SizedBox(height: 15),
                            TextField(controller: _direccionCtrl, decoration: const InputDecoration(labelText: 'Dirección de Habitación', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home))),
                            const SizedBox(height: 25),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _guardarCliente(context),
                                child: const Text('GUARDAR FICHA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
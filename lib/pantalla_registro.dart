import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'helpers.dart'; 

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  String? _fotoBase64;
  bool _huellaCapturada = false;
  bool _camaraActiva = false; // Cámara apagada por defecto

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _apellidoCtrl = TextEditingController();
  final TextEditingController _cedulaCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();
  
  late String _sedeSeleccionada;

  @override
  void initState() {
    super.initState();
    _sedeSeleccionada = obtenerSedeActual().toUpperCase();
  }

  Future<void> _activarCamara() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(_cameras![0], ResolutionPreset.low); // Low para hacerla rápida
        await _cameraController!.initialize();
        setState(() { _camaraActiva = true; });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontraron cámaras conectadas.')));
      }
    } catch (e) {
      debugPrint("Error inicializando cámara: $e");
    }
  }

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

  Future<void> _tomarFoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      setState(() {
        _fotoBase64 = base64Encode(bytes);
        _camaraActiva = false; // Apagamos cámara al capturar para ahorrar recursos
      });
      _cameraController!.dispose();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al capturar la foto'), backgroundColor: Colors.red));
    }
  }

  void _capturarHuellaMock() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coloque el dedo en el lector...')));
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _huellaCapturada = true);
    });
  }

  void _guardarCliente() async {
    if (_nombreCtrl.text.trim().isEmpty || _apellidoCtrl.text.trim().isEmpty ||
        _cedulaCtrl.text.trim().isEmpty || _telefonoCtrl.text.trim().isEmpty || _direccionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todos los campos son obligatorios.'), backgroundColor: Colors.red));
      return;
    }
    if (_fotoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe tomar una foto.'), backgroundColor: Colors.red));
      return;
    }
    if (!_huellaCapturada) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe registrar la huella.'), backgroundColor: Colors.red));
      return;
    }

    String boxNombre = obtenerNombreBoxSede('clientsBox');
    var box = Hive.box(boxNombre);
    final idUnico = DateTime.now().millisecondsSinceEpoch.toString();
    
    final nuevoCliente = {
      'id': idUnico,
      'nombre': _nombreCtrl.text.trim().toUpperCase(),
      'apellido': _apellidoCtrl.text.trim().toUpperCase(),
      'cedula': _cedulaCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim().toUpperCase(),
      'sede': _sedeSeleccionada,
      'fotoBase64': _fotoBase64,
      'huella': 'HUELLA_MOCK_$idUnico', 
      'fechaVencimiento': '', 
      'notas': 'Registrado el ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'
    };

    await box.put(idUnico, nuevoCliente);

    if (mounted) {
      Navigator.pop(context); // Cierra el Dialog
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ficha creada con éxito'), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: 850,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Cabecera del Dialog
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Registro de Nuevo Cliente', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Expanded(
              child: Row(
                children: [
                  // Lado Izquierdo: Biometría
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                          child: _fotoBase64 != null 
                              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(_fotoBase64!), fit: BoxFit.cover))
                              : _camaraActiva && _cameraController != null && _cameraController!.value.isInitialized
                                  ? ClipRRect(borderRadius: BorderRadius.circular(10), child: CameraPreview(_cameraController!))
                                  : Center(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.videocam),
                                        label: const Text('Activar Cámara'),
                                        onPressed: _activarCamara,
                                      ),
                                    ),
                        ),
                        const SizedBox(height: 10),
                        if (_camaraActiva)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            icon: const Icon(Icons.camera),
                            label: const Text('Capturar Foto'),
                            onPressed: _tomarFoto,
                          ),
                        if (_fotoBase64 != null)
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, color: Colors.red, size: 16),
                            label: const Text('Borrar y repetir', style: TextStyle(color: Colors.red, fontSize: 12)),
                            onPressed: () => setState(() => _fotoBase64 = null),
                          ),
                        const Spacer(),
                        Icon(Icons.fingerprint, size: 60, color: _huellaCapturada ? Colors.green : Colors.grey),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _huellaCapturada ? Colors.green : Colors.orange.shade800, foregroundColor: Colors.white),
                          icon: Icon(_huellaCapturada ? Icons.check_circle : Icons.scanner),
                          label: Text(_huellaCapturada ? 'Huella Registrada' : 'Escanear Huella'),
                          onPressed: _huellaCapturada ? null : _capturarHuellaMock,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 30, thickness: 1),
                  // Lado Derecho: Formulario
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Todos los campos son obligatorios.', style: TextStyle(color: Colors.red, fontSize: 12)),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_nombreCtrl, 'Nombres', Icons.person)),
                              const SizedBox(width: 15),
                              Expanded(child: _buildTextField(_apellidoCtrl, 'Apellidos', Icons.person_outline)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_cedulaCtrl, 'Cédula', Icons.badge)),
                              const SizedBox(width: 15),
                              Expanded(child: _buildTextField(_telefonoCtrl, 'Teléfono', Icons.phone, inputType: TextInputType.phone)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(_direccionCtrl, 'Dirección de Habitación', Icons.location_on),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              icon: const Icon(Icons.save),
                              label: const Text('GUARDAR FICHA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                              onPressed: _guardarCliente,
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
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade700, size: 20),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      ),
    );
  }
}
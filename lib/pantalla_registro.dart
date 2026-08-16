import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  Uint8List? fotoComprimida;
  bool estaCargando = false;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  String _sucursalOrigen = 'Sede Este';

  Future<void> seleccionarYComprimirFoto() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        estaCargando = true;
      });

      File archivoOriginal = File(result.files.single.path!);
      final bytesOriginales = await archivoOriginal.readAsBytes();
      
      img.Image? imagenDecodificada = img.decodeImage(bytesOriginales);
      
      if (imagenDecodificada != null) {
        img.Image imagenMiniatura = img.copyResize(
          imagenDecodificada, 
          width: 300,
        );
        
        List<int> bytesComprimidos = img.encodeJpg(imagenMiniatura, quality: 70);
        
        setState(() {
          fotoComprimida = Uint8List.fromList(bytesComprimidos);
          estaCargando = false;
        });

        debugPrint('Peso original: ${bytesOriginales.length} bytes');
        debugPrint('Peso final comprimido: ${bytesComprimidos.length} bytes');
      } else {
        setState(() {
          estaCargando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gala Gym - Registro de Cliente'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                          child: estaCargando 
                              ? const Center(child: CircularProgressIndicator())
                              : fotoComprimida != null
                                  ? ClipOval(
                                      child: Image.memory(
                                        fotoComprimida!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person, 
                                      size: 80, 
                                      color: Colors.grey,
                                    ),
                        ),
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          radius: 20,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                            onPressed: estaCargando ? null : seleccionarYComprimirFoto,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),

                    TextField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre y Apellido',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    TextField(
                      controller: _cedulaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cédula de Identidad',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _sucursalOrigen, // Cambiado de 'value' a 'initialValue'
                      decoration: const InputDecoration(
                        labelText: 'Sede de Registro',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Sede Este', child: Text('Sede Este')),
                        DropdownMenuItem(value: 'Sede Oeste', child: Text('Sede Oeste')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _sucursalOrigen = val;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Guardando cliente para $_sucursalOrigen...'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Guardar Cliente',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
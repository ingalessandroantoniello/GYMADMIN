class ClienteLocal {
  String id;
  String nombre;
  String apellido;
  String cedula;
  String telefono;
  String fechaNacimiento;
  String direccion;
  String estadoMembresia; 
  String fechaVencimiento;
  String fechaInscripcion;
  String notas; // NUEVO: Para guardar las observaciones del cliente
  bool subidoALaNube; 

  ClienteLocal({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.cedula,
    required this.telefono,
    required this.fechaNacimiento,
    required this.direccion,
    required this.estadoMembresia,
    required this.fechaVencimiento,
    required this.fechaInscripcion,
    this.notas = "", // Por defecto arranca en blanco
    this.subidoALaNube = false, 
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'cedula': cedula,
      'telefono': telefono,
      'fechaNacimiento': fechaNacimiento,
      'direccion': direccion,
      'estadoMembresia': estadoMembresia,
      'fechaVencimiento': fechaVencimiento,
      'fechaInscripcion': fechaInscripcion,
      'notas': notas,
      'subidoALaNube': subidoALaNube,
    };
  }
}
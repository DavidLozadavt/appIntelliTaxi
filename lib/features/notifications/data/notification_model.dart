class NotificationModel {
  int? id;
  String? fecha;
  String? hora;
  String? asunto;
  String? mensaje;
  String? estadoId;
  String? idUsuarioReceptor;
  String? idUsuarioRemitente;
  String? idTipoNotificacion;
  String? idEmpresa;
  String? createdAt;
  String? updatedAt;
  String? route;
  Estado? estado;
  Persona? personaReceptor;
  Persona? personaRemitente;
  TipoNotificacion? tipoNotificacion;
  Empresa? empresa;

  NotificationModel({
    this.id,
    this.fecha,
    this.hora,
    this.asunto,
    this.mensaje,
    this.estadoId,
    this.idUsuarioReceptor,
    this.idUsuarioRemitente,
    this.idTipoNotificacion,
    this.idEmpresa,
    this.createdAt,
    this.updatedAt,
    this.route,
    this.estado,
    this.personaReceptor,
    this.personaRemitente,
    this.tipoNotificacion,
    this.empresa,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
        id: json["id"],
        fecha: json["fecha"],
        hora: json["hora"],
        asunto: json["asunto"],
        mensaje: json["mensaje"],
        estadoId: json["estado_id"],
        idUsuarioReceptor: json["idUsuarioReceptor"],
        idUsuarioRemitente: json["idUsuarioRemitente"],
        idTipoNotificacion: json["idTipoNotificacion"],
        idEmpresa: json["idEmpresa"],
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
        route: json["route"],
        estado: json["estado"] != null ? Estado.fromJson(json["estado"]) : null,
        personaReceptor: json["personaReceptor"] != null
            ? Persona.fromJson(json["personaReceptor"])
            : null,
        personaRemitente: json["personaRemitente"] != null
            ? Persona.fromJson(json["personaRemitente"])
            : null,
        tipoNotificacion: json["tipoNotificacion"] != null
            ? TipoNotificacion.fromJson(json["tipoNotificacion"])
            : null,
        empresa: json["empresa"] != null ? Empresa.fromJson(json["empresa"]) : null,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "fecha": fecha,
        "hora": hora,
        "asunto": asunto,
        "mensaje": mensaje,
        "estado_id": estadoId,
        "idUsuarioReceptor": idUsuarioReceptor,
        "idUsuarioRemitente": idUsuarioRemitente,
        "idTipoNotificacion": idTipoNotificacion,
        "idEmpresa": idEmpresa,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "route": route,
        "estado": estado?.toJson(),
        "personaReceptor": personaReceptor?.toJson(),
        "personaRemitente": personaRemitente?.toJson(),
        "tipoNotificacion": tipoNotificacion?.toJson(),
        "empresa": empresa?.toJson(),
      };
}

class Estado {
  int? id;
  String? estado;
  String? descripcion;

  Estado({this.id, this.estado, this.descripcion});

  factory Estado.fromJson(Map<String, dynamic> json) => Estado(
        id: json["id"],
        estado: json["estado"],
        descripcion: json["descripcion"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "estado": estado,
        "descripcion": descripcion,
      };
}

class Persona {
  int? id;
  String? identificacion;
  String? nombre1;
  String? nombre2;
  String? apellido1;
  String? apellido2;
  String? fechaNac;
  String? direccion;
  String? email;
  String? telefonoFijo;
  String? celular;
  String? perfil;
  String? sexo;
  String? rh;
  String? rutaFoto;
  String? idTipoIdentificacion;
  String? idCiudad;
  String? idCiudadNac;
  String? idCiudadUbicacion;
  String? createdAt;
  String? updatedAt;
  String? rutaFotoUrl;

  Persona({
    this.id,
    this.identificacion,
    this.nombre1,
    this.nombre2,
    this.apellido1,
    this.apellido2,
    this.fechaNac,
    this.direccion,
    this.email,
    this.telefonoFijo,
    this.celular,
    this.perfil,
    this.sexo,
    this.rh,
    this.rutaFoto,
    this.idTipoIdentificacion,
    this.idCiudad,
    this.idCiudadNac,
    this.idCiudadUbicacion,
    this.createdAt,
    this.updatedAt,
    this.rutaFotoUrl,
  });

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
        id: json["id"],
        identificacion: json["identificacion"],
        nombre1: json["nombre1"],
        nombre2: json["nombre2"],
        apellido1: json["apellido1"],
        apellido2: json["apellido2"],
        fechaNac: json["fechaNac"],
        direccion: json["direccion"],
        email: json["email"],
        telefonoFijo: json["telefonoFijo"] == "null" ? null : json["telefonoFijo"],
        celular: json["celular"],
        perfil: json["perfil"],
        sexo: json["sexo"],
        rh: json["rh"],
        rutaFoto: json["rutaFoto"],
        idTipoIdentificacion: json["idTipoIdentificacion"],
        idCiudad: json["idCiudad"],
        idCiudadNac: json["idCiudadNac"],
        idCiudadUbicacion: json["idCiudadUbicacion"],
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
        rutaFotoUrl: json["rutaFotoUrl"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "identificacion": identificacion,
        "nombre1": nombre1,
        "nombre2": nombre2,
        "apellido1": apellido1,
        "apellido2": apellido2,
        "fechaNac": fechaNac,
        "direccion": direccion,
        "email": email,
        "telefonoFijo": telefonoFijo,
        "celular": celular,
        "perfil": perfil,
        "sexo": sexo,
        "rh": rh,
        "rutaFoto": rutaFoto,
        "idTipoIdentificacion": idTipoIdentificacion,
        "idCiudad": idCiudad,
        "idCiudadNac": idCiudadNac,
        "idCiudadUbicacion": idCiudadUbicacion,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "rutaFotoUrl": rutaFotoUrl,
      };
}

class TipoNotificacion {
  int? id;
  String? tipoNotificacion;
  String? observacion;
  String? createdAt;
  String? updatedAt;

  TipoNotificacion({
    this.id,
    this.tipoNotificacion,
    this.observacion,
    this.createdAt,
    this.updatedAt,
  });

  factory TipoNotificacion.fromJson(Map<String, dynamic> json) =>
      TipoNotificacion(
        id: json["id"],
        tipoNotificacion: json["tipoNotificacion"],
        observacion: json["observacion"],
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "tipoNotificacion": tipoNotificacion,
        "observacion": observacion,
        "created_at": createdAt,
        "updated_at": updatedAt,
      };
}

class Empresa {
  int? id;
  String? razonSocial;
  String? nit;
  String? rutaLogo;
  String? representanteLegal;
  String? digitoVerificacion;
  String? createdAt;
  String? updatedAt;
  String? rutaLogoUrl;

  Empresa({
    this.id,
    this.razonSocial,
    this.nit,
    this.rutaLogo,
    this.representanteLegal,
    this.digitoVerificacion,
    this.createdAt,
    this.updatedAt,
    this.rutaLogoUrl,
  });

  factory Empresa.fromJson(Map<String, dynamic> json) => Empresa(
        id: json["id"],
        razonSocial: json["razonSocial"],
        nit: json["nit"],
        rutaLogo: json["rutaLogo"],
        representanteLegal: json["representanteLegal"],
        digitoVerificacion: json["digitoVerificacion"],
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
        rutaLogoUrl: json["rutaLogoUrl"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "razonSocial": razonSocial,
        "nit": nit,
        "rutaLogo": rutaLogo,
        "representanteLegal": representanteLegal,
        "digitoVerificacion": digitoVerificacion,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "rutaLogoUrl": rutaLogoUrl,
      };
}

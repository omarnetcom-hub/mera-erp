/// Servicio de Integración con Portal de Transparencia
/// Ley 1712/2014 y normas complementarias
/// Publicación automática de información en portal de transparencia
library;

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../security/auditoria_service.dart';

enum TipoInformacion {
  presupuesto,
  contratacion,
  nomina,
  regalias,
  proyectos,
  otros,
}

class PortalTransparenciaService {
  final Dio dio;
  final AuditoriaService auditoriaService;
  final Uuid _uuid = const Uuid();

  // Configuración del portal de transparencia (ejemplo: Colombia Compra Eficiente)
  static const String _portalUrl = 'https://www.colombiacompra.gov.co/api/transparencia';
  static const String _apiKey = 'TU_API_KEY'; // Debe configurarse en variables de entorno

  PortalTransparenciaService({
    required this.dio,
    required this.auditoriaService,
  }) {
    dio.options.baseUrl = _portalUrl;
    dio.options.headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };
  }

  /// Publica información en el portal de transparencia
  Future<Map<String, dynamic>> publicarInformacion({
    required String entidadId,
    required String usuarioId,
    required TipoInformacion tipo,
    required Map<String, dynamic> datos,
    required DateTime fechaPublicacion,
    String? referenciaInterna,
  }) async {
    final id = _uuid.v4();

    try {
      // Validar datos según tipo
      _validarDatosTipo(tipo, datos);

      // Construir payload según especificación del portal
      final payload = _construirPayload(tipo, datos, entidadId, fechaPublicacion);

      // Enviar al portal
      final response = await dio.post(
        '/publicar',
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final portalId = response.data['id'] as String;
        final urlPublicacion = response.data['url'] as String;

        // Registrar publicación local
        await _registrarPublicacionLocal(
          id: id,
          entidadId: entidadId,
          usuarioId: usuarioId,
          tipo: tipo,
          portalId: portalId,
          urlPublicacion: urlPublicacion,
          referenciaInterna: referenciaInterna,
          fechaPublicacion: fechaPublicacion,
          estado: 'publicado',
        );

        await auditoriaService.registrarEvento(
          entidadId: entidadId,
          usuarioId: usuarioId,
          tipoEvento: TipoEventoAuditoria.creacionRegistro,
          modulo: 'transparencia',
          accion: 'publicacion_portal_transparencia',
          valorAnterior: {},
          valorNuevo: {
            'publicacion_id': id,
            'portal_id': portalId,
            'tipo': tipo.toString(),
            'url_publicacion': urlPublicacion,
          },
          referenciaId: id,
        );

        return {
          'publicacion_id': id,
          'portal_id': portalId,
          'url_publicacion': urlPublicacion,
          'estado': 'publicado',
        };
      } else {
        throw Exception('Error al publicar: ${response.statusCode}');
      }
    } catch (e) {
      // Registrar error
      await _registrarPublicacionLocal(
        id: id,
        entidadId: entidadId,
        usuarioId: usuarioId,
        tipo: tipo,
        portalId: '',
        urlPublicacion: '',
        referenciaInterna: referenciaInterna,
        fechaPublicacion: fechaPublicacion,
        estado: 'error',
        error: e.toString(),
      );

      throw Exception('Error al publicar en portal de transparencia: $e');
    }
  }

  /// Actualiza información publicada
  Future<Map<String, dynamic>> actualizarInformacion({
    required String entidadId,
    required String usuarioId,
    required String publicacionId,
    required String portalId,
    required Map<String, dynamic> nuevosDatos,
  }) async {
    try {
      final payload = {
        'id': portalId,
        'datos': nuevosDatos,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      };

      final response = await dio.put(
        '/actualizar/$portalId',
        data: payload,
      );

      if (response.statusCode == 200) {
        final nuevaUrl = response.data['url'] as String;

        await auditoriaService.registrarEvento(
          entidadId: entidadId,
          usuarioId: usuarioId,
          tipoEvento: TipoEventoAuditoria.modificacionRegistro,
          modulo: 'transparencia',
          accion: 'actualizacion_portal_transparencia',
          valorAnterior: {},
          valorNuevo: {
            'publicacion_id': publicacionId,
            'portal_id': portalId,
            'url_actualizada': nuevaUrl,
          },
          referenciaId: publicacionId,
        );

        return {
          'publicacion_id': publicacionId,
          'portal_id': portalId,
          'url_actualizada': nuevaUrl,
          'estado': 'actualizado',
        };
      } else {
        throw Exception('Error al actualizar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al actualizar en portal de transparencia: $e');
    }
  }

  /// Elimina información del portal
  Future<Map<String, dynamic>> eliminarInformacion({
    required String entidadId,
    required String usuarioId,
    required String publicacionId,
    required String portalId,
    required String motivo,
  }) async {
    try {
      final response = await dio.delete(
        '/eliminar/$portalId',
        data: {
          'motivo': motivo,
          'fecha_eliminacion': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        await auditoriaService.registrarEvento(
          entidadId: entidadId,
          usuarioId: usuarioId,
          tipoEvento: TipoEventoAuditoria.eliminacionRegistro,
          modulo: 'transparencia',
          accion: 'eliminacion_portal_transparencia',
          valorAnterior: {
            'portal_id': portalId,
          },
          valorNuevo: {
            'motivo': motivo,
          },
          referenciaId: publicacionId,
        );

        return {
          'publicacion_id': publicacionId,
          'portal_id': portalId,
          'estado': 'eliminado',
        };
      } else {
        throw Exception('Error al eliminar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al eliminar del portal de transparencia: $e');
    }
  }

  /// Consulta el estado de una publicación
  Future<Map<String, dynamic>> consultarEstadoPublicacion({
    required String portalId,
  }) async {
    try {
      final response = await dio.get(
        '/estado/$portalId',
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Error al consultar estado: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al consultar estado en portal de transparencia: $e');
    }
  }

  /// Sincroniza automáticamente información pendiente
  Future<Map<String, dynamic>> sincronizarPendientes({
    required String entidadId,
    required String usuarioId,
  }) async {
    // Obtener publicaciones pendientes o con error
    final pendientes = await _obtenerPublicacionesPendientes(entidadId);

    int exitosas = 0;
    int fallidas = 0;
    final errores = <String>[];

    for (final pendiente in pendientes) {
      try {
        final tipo = TipoInformacion.values.firstWhere(
          (e) => e.toString().split('.').last == pendiente['tipo'],
        );

        final datos = pendiente['datos'] as Map<String, dynamic>;
        final referenciaInterna = pendiente['referencia_interna'];
        final fechaPublicacion = DateTime.parse(pendiente['fecha_publicacion']);

        await publicarInformacion(
          entidadId: entidadId,
          usuarioId: usuarioId,
          tipo: tipo,
          datos: datos,
          fechaPublicacion: fechaPublicacion,
          referenciaInterna: referenciaInterna,
        );

        exitosas++;
      } catch (e) {
        fallidas++;
        errores.add('${pendiente['id']}: $e');
      }
    }

    return {
      'total_pendientes': pendientes.length,
      'exitosas': exitosas,
      'fallidas': fallidas,
      'errores': errores,
    };
  }

  /// Valida los datos según el tipo de información
  void _validarDatosTipo(TipoInformacion tipo, Map<String, dynamic> datos) {
    switch (tipo) {
      case TipoInformacion.presupuesto:
        if (!datos.containsKey('vigencia') || !datos.containsKey('aprobado')) {
          throw Exception('Datos de presupuesto deben incluir vigencia y aprobado');
        }
        break;
      case TipoInformacion.contratacion:
        if (!datos.containsKey('numero_contrato') || !datos.containsKey('valor')) {
          throw Exception('Datos de contratación deben incluir número de contrato y valor');
        }
        break;
      case TipoInformacion.nomina:
        if (!datos.containsKey('periodo') || !datos.containsKey('total')) {
          throw Exception('Datos de nómina deben incluir periodo y total');
        }
        break;
      case TipoInformacion.regalias:
        if (!datos.containsKey('periodo') || !datos.containsKey('monto')) {
          throw Exception('Datos de regalías deben incluir periodo y monto');
        }
        break;
      case TipoInformacion.proyectos:
        if (!datos.containsKey('codigo_bpin') || !datos.containsKey('nombre')) {
          throw Exception('Datos de proyectos deben incluir código BPIN y nombre');
        }
        break;
      case TipoInformacion.otros:
        // No hay validación específica
        break;
    }
  }

  /// Construye el payload según especificación del portal
  Map<String, dynamic> _construirPayload(
    TipoInformacion tipo,
    Map<String, dynamic> datos,
    String entidadId,
    DateTime fechaPublicacion,
  ) {
    return {
      'tipo': tipo.toString().split('.').last,
      'entidad_id': entidadId,
      'datos': datos,
      'fecha_publicacion': fechaPublicacion.toIso8601String(),
      'formato': 'json',
      'version': '1.0',
    };
  }

  /// Registra la publicación localmente
  Future<void> _registrarPublicacionLocal({
    required String id,
    required String entidadId,
    required String usuarioId,
    required TipoInformacion tipo,
    required String portalId,
    required String urlPublicacion,
    required String? referenciaInterna,
    required DateTime fechaPublicacion,
    required String estado,
    String? error,
  }) async {
    // Aquí se debería insertar en la base de datos local
    // Por ahora, solo registramos el evento de auditoría
    // En producción, usar db.insert('publicaciones_portal', {...})
  }

  /// Obtiene publicaciones pendientes
  Future<List<Map<String, dynamic>>> _obtenerPublicacionesPendientes(
    String entidadId,
  ) async {
    // Aquí se debería consultar la base de datos local
    // Por ahora, retorna lista vacía
    // En producción, usar db.query('publicaciones_portal', where: 'entidad_id = ? AND estado IN (?, ?)', ...)
    return [];
  }
}

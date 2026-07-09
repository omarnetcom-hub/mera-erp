import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';

class TaskExecutionResult {
  final String taskName;
  final String status;
  final String? message;

  TaskExecutionResult({
    required this.taskName,
    required this.status,
    this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'task': taskName,
      'status': status,
      if (message != null) 'message': message,
    };
  }
}

class TaskSchedulerService {
  TaskSchedulerService({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Ejecuta todas las tareas pendientes al iniciar la aplicación
  Future<List<TaskExecutionResult>> runPendingTasks() async {
    final results = <TaskExecutionResult>[];

    // Tarea A: Bloqueo de Lotes Vencidos (diaria)
    results.add(await _executeTask(
      taskName: 'bloqueo_lotes_vencidos',
      taskFunction: _executeBloqueoLotesVencidos,
      frequency: 'daily',
    ));

    // Tarea B: Actualización de Tasa de Cambio (diaria)
    results.add(await _executeTask(
      taskName: 'actualizacion_trm',
      taskFunction: _executeActualizacionTRM,
      frequency: 'daily',
    ));

    // Tarea C: Depreciación Mensual de Activos (mensual)
    results.add(await _executeTask(
      taskName: 'depreciacion_mensual',
      taskFunction: _executeDepreciacionMensual,
      frequency: 'monthly',
    ));

    return results;
  }

  /// Ejecuta una tarea individual verificando si debe ejecutarse según su frecuencia
  Future<TaskExecutionResult> _executeTask({
    required String taskName,
    required Future<void> Function() taskFunction,
    required String frequency,
  }) async {
    try {
      final db = await _db.database;
      final now = DateTime.now();
      final today = now.toIso8601String().split('T').first;

      // Obtener última ejecución
      final taskLogs = await db.query(
        'system_tasks_log',
        where: 'task_name = ?',
        whereArgs: [taskName],
        limit: 1,
      );

      bool shouldExecute = false;
      DateTime? lastExecution;

      if (taskLogs.isEmpty) {
        // Primera ejecución
        shouldExecute = true;
      } else {
        final lastExecutionStr = taskLogs.first['last_execution_date']?.toString();
        if (lastExecutionStr != null) {
          lastExecution = DateTime.parse(lastExecutionStr);
        }

        if (frequency == 'daily') {
          // Ejecutar si hoy es diferente al último día de ejecución
          final lastExecutionDay = lastExecution?.toIso8601String().split('T').first;
          shouldExecute = lastExecutionDay != today;
        } else if (frequency == 'monthly') {
          // Ejecutar si el mes actual es mayor al mes de la última ejecución
          if (lastExecution != null) {
            shouldExecute = (now.year > lastExecution.year) ||
                (now.year == lastExecution.year && now.month > lastExecution.month);
          } else {
            shouldExecute = true;
          }
        }
      }

      if (shouldExecute) {
        await taskFunction();

        // Actualizar log de ejecución exitosa
        if (taskLogs.isEmpty) {
          await db.insert('system_tasks_log', {
            'task_name': taskName,
            'last_execution_date': now.toIso8601String(),
            'last_execution_status': 'completed',
            'last_error': null,
          });
        } else {
          await db.update(
            'system_tasks_log',
            {
              'last_execution_date': now.toIso8601String(),
              'last_execution_status': 'completed',
              'last_error': null,
            },
            where: 'task_name = ?',
            whereArgs: [taskName],
          );
        }

        return TaskExecutionResult(
          taskName: taskName,
          status: 'completed',
          message: 'Tarea ejecutada exitosamente',
        );
      } else {
        return TaskExecutionResult(
          taskName: taskName,
          status: 'skipped',
          message: 'Ya ejecutada en el periodo actual',
        );
      }
    } catch (e) {
      // Registrar error en log
      final db = await _db.database;
      final now = DateTime.now();

      final taskLogs = await db.query(
        'system_tasks_log',
        where: 'task_name = ?',
        whereArgs: [taskName],
        limit: 1,
      );

      if (taskLogs.isEmpty) {
        await db.insert('system_tasks_log', {
          'task_name': taskName,
          'last_execution_date': now.toIso8601String(),
          'last_execution_status': 'failed',
          'last_error': e.toString(),
        });
      } else {
        await db.update(
          'system_tasks_log',
          {
            'last_execution_date': now.toIso8601String(),
            'last_execution_status': 'failed',
            'last_error': e.toString(),
          },
          where: 'task_name = ?',
          whereArgs: [taskName],
        );
      }

      // Registrar en auditoría
      await _db.registrarEventoAuditoria(
        accion: 'ERROR_TASK_SCHEDULER',
        entidad: 'system_tasks_log',
        detalle: 'Error en tarea $taskName: $e',
      );

      return TaskExecutionResult(
        taskName: taskName,
        status: 'failed',
        message: e.toString(),
      );
    }
  }

  /// Tarea A: Bloqueo de Lotes Vencidos
  Future<void> _executeBloqueoLotesVencidos() async {
    await _db.bloquearLotesVencidos();
  }

  /// Tarea B: Actualización de Tasa de Cambio (TRM)
  Future<void> _executeActualizacionTRM() async {
    try {
      // Verificar conectividad
      final connectivityResult = await _checkConnectivity();
      if (!connectivityResult) {
        throw Exception('No hay conexión a internet');
      }

      // Llamar a API pública (Frankfurter - gratuita y sin API key)
      final response = await http.get(
        Uri.parse('https://api.frankfurter.app/latest?from=USD&to=COP'),
      );

      if (response.statusCode == 200) {
        final data = _parseJson(response.body);
        final rate = data['rates']['COP'] as num;

        // Actualizar en base de datos
        final db = await _db.database;
        final companyId = await _db.obtenerEmpresaActivaId();
        final today = DateTime.now().toIso8601String().split('T').first;

        await db.insert(
          'exchange_rates',
          {
            'date': today,
            'currency_code': 'USD',
            'rate_to_base': rate.toDouble(),
            'company_id': companyId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await _db.registrarEventoAuditoria(
          accion: 'ACTUALIZAR_TRM',
          entidad: 'exchange_rates',
          detalle: 'TRM actualizada desde API: $rate',
        );
      } else {
        throw Exception('Error al obtener TRM: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en actualización TRM: $e');
    }
  }

  /// Tarea C: Depreciación Mensual de Activos
  Future<void> _executeDepreciacionMensual() async {
    await _db.procesarDepreciacionMensual();
  }

  /// Verifica conectividad a internet
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Parsea JSON de forma segura
  Map<String, dynamic> _parseJson(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error al parsear JSON: $e');
    }
  }
}

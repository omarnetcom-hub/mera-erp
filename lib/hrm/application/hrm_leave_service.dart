import '../../db_helper.dart';
import '../data/hrm_leave_repository.dart';
import '../domain/hrm_leave.dart';

class HrmLeaveService {
  HrmLeaveService({HrmLeaveRepository? repository})
    : _repository = repository ?? SqliteHrmLeaveRepository();
  final HrmLeaveRepository _repository;

  Future<int> create(HrmLeave value) => _repository.save(value);
  Future<List<HrmLeave>> listForEmployee(int employeeId) =>
      _repository.findForEmployee(employeeId);

  /// Aprobacion atomica: el saldo se valida en el servicio, nunca en la UI.
  /// La regla es days_used + length_days <= days_total.
  Future<void> approve({required int leaveId, required int approvedBy}) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'hrm_leaves',
        where: 'id = ? AND company_id = ?',
        whereArgs: [leaveId, companyId],
        limit: 1,
      );
      if (rows.isEmpty)
        throw StateError('La ausencia no existe en la empresa activa.');
      final leave = rows.single;
      if (leave['status'] != 'pendiente')
        throw StateError('Solo se puede aprobar una ausencia pendiente.');
      final entitlements = await txn.query(
        'hrm_leave_entitlements',
        where:
            'company_id = ? AND employee_id = ? AND leave_type_id = ? AND period_from <= ? AND period_to >= ?',
        whereArgs: [
          companyId,
          leave['employee_id'],
          leave['leave_type_id'],
          leave['date'],
          leave['date'],
        ],
        limit: 1,
      );
      if (entitlements.isEmpty)
        throw StateError(
          'No existe saldo asignado para el periodo de la ausencia.',
        );
      final entitlement = entitlements.single;
      final used = (entitlement['days_used'] as num).toDouble();
      final total = (entitlement['days_total'] as num).toDouble();
      final length = (leave['length_days'] as num).toDouble();
      if (used + length > total)
        throw StateError(
          'Saldo insuficiente: days_used + length_days excede days_total.',
        );
      await txn.update(
        'hrm_leave_entitlements',
        {'days_used': used + length},
        where: 'id = ?',
        whereArgs: [entitlement['id']],
      );
      await txn.update(
        'hrm_leaves',
        {'status': 'aprobado', 'approved_by': approvedBy},
        where: 'id = ?',
        whereArgs: [leaveId],
      );
      await txn.update(
        'hrm_leave_requests',
        {'status': 'aprobado'},
        where: 'id = ?',
        whereArgs: [leave['leave_request_id']],
      );
    });
  }

  /// Consulta local consumible por nomina y por futuros reportes DIAN.
  Future<List<Map<String, dynamic>>> approvedForPeriod({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final companyId = await DatabaseHelper.instance.obtenerEmpresaActivaId();
    return db.rawQuery(
      '''
      SELECT l.*, e.nombre AS employee_name, t.code AS leave_code, t.name AS leave_name
      FROM hrm_leaves l
      JOIN empleados e ON e.id = l.employee_id AND e.company_id = l.company_id
      JOIN hrm_leave_types t ON t.id = l.leave_type_id AND t.company_id = l.company_id
      WHERE l.company_id = ? AND l.status = 'aprobado' AND l.date >= ? AND l.date < ?
      ORDER BY l.date, e.nombre
    ''',
      [companyId, from.toIso8601String(), to.toIso8601String()],
    );
  }
}

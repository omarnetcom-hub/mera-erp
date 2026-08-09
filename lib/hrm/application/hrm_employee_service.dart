import '../data/hrm_employee_repository.dart';
import '../domain/hrm_employee.dart';
import '../../db_helper.dart';

class HrmEmployeeService {
  HrmEmployeeService({HrmEmployeeRepository? repository})
    : _repository = repository ?? SqliteHrmEmployeeRepository();
  final HrmEmployeeRepository _repository;
  Future<int> create(HrmEmployee value) {
    if (value.name.trim().isEmpty) {
      throw ArgumentError('El empleado requiere nombre.');
    }
    return _repository.save(value);
  }

  Future<void> update(HrmEmployee value) async {
    if (value.id == null) throw ArgumentError('El empleado requiere id.');
    await _repository.save(value);
  }

  Future<List<HrmEmployee>> list() => _repository.findAll();
  Future<HrmEmployee?> findById(int id) => _repository.findById(id);

  Future<void> terminate({
    required int employeeId,
    required DateTime terminationDate,
  }) async {
    final employee = await _repository.findById(employeeId);
    if (employee == null) {
      throw StateError('El empleado no existe en la empresa activa.');
    }
    if (employee.joinedDate != null &&
        terminationDate.isBefore(employee.joinedDate!)) {
      throw ArgumentError(
        'La fecha de terminacion no puede ser anterior al ingreso.',
      );
    }
    final db = await DatabaseHelper.instance.database;
    final pending = await db.query(
      'hrm_leaves',
      columns: ['id'],
      where: 'company_id = ? AND employee_id = ? AND status = ?',
      whereArgs: [employee.companyId, employeeId, 'pendiente'],
      limit: 1,
    );
    if (pending.isNotEmpty) {
      throw StateError(
        'No se puede terminar el empleado mientras tenga ausencias pendientes de aprobacion.',
      );
    }
    await _repository.save(
      employee.copyWith(status: 'retirado', terminationDate: terminationDate),
    );
  }
}

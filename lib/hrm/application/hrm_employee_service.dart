import '../data/hrm_employee_repository.dart';
import '../domain/hrm_employee.dart';

class HrmEmployeeService {
  HrmEmployeeService({HrmEmployeeRepository? repository})
    : _repository = repository ?? SqliteHrmEmployeeRepository();
  final HrmEmployeeRepository _repository;
  Future<int> create(HrmEmployee value) => _repository.save(value);
  Future<void> update(HrmEmployee value) async {
    if (value.id == null) throw ArgumentError('El empleado requiere id.');
    await _repository.save(value);
  }

  Future<List<HrmEmployee>> list() => _repository.findAll();
  Future<HrmEmployee?> findById(int id) => _repository.findById(id);
}

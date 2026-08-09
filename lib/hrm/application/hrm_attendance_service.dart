import '../data/hrm_attendance_record_repository.dart';
import '../domain/hrm_attendance_record.dart';

class HrmAttendanceService {
  HrmAttendanceService({HrmAttendanceRecordRepository? repository})
    : _repository = repository ?? SqliteHrmAttendanceRecordRepository();
  final HrmAttendanceRecordRepository _repository;
  Future<int> record(HrmAttendanceRecord value) => _repository.save(value);
  Future<List<HrmAttendanceRecord>> listForEmployee(int employeeId) =>
      _repository.findForEmployee(employeeId);
}

import '../data/hrm_leave_request_repository.dart';
import '../domain/hrm_leave_request.dart';

class HrmLeaveRequestService {
  HrmLeaveRequestService({HrmLeaveRequestRepository? repository})
    : _repository = repository ?? SqliteHrmLeaveRequestRepository();
  final HrmLeaveRequestRepository _repository;
  Future<int> create(HrmLeaveRequest value) {
    if (value.companyId <= 0 ||
        value.employeeId <= 0 ||
        value.leaveTypeId <= 0) {
      throw ArgumentError(
        'La solicitud requiere empresa, empleado y tipo validos.',
      );
    }
    if (value.status != 'pendiente') {
      throw ArgumentError('Una solicitud nueva debe iniciar como pendiente.');
    }
    return _repository.save(value);
  }

  Future<List<HrmLeaveRequest>> listForEmployee(int employeeId) =>
      _repository.findForEmployee(employeeId);
}

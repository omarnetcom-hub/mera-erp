import '../data/hrm_leave_request_repository.dart';
import '../domain/hrm_leave_request.dart';

class HrmLeaveRequestService {
  HrmLeaveRequestService({HrmLeaveRequestRepository? repository})
    : _repository = repository ?? SqliteHrmLeaveRequestRepository();
  final HrmLeaveRequestRepository _repository;
  Future<int> create(HrmLeaveRequest value) => _repository.save(value);
  Future<List<HrmLeaveRequest>> listForEmployee(int employeeId) =>
      _repository.findForEmployee(employeeId);
}

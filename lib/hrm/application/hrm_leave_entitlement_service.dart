import '../data/hrm_leave_entitlement_repository.dart';
import '../domain/hrm_leave_entitlement.dart';

class HrmLeaveEntitlementService {
  HrmLeaveEntitlementService({HrmLeaveEntitlementRepository? repository})
    : _repository = repository ?? SqliteHrmLeaveEntitlementRepository();
  final HrmLeaveEntitlementRepository _repository;
  Future<int> create(HrmLeaveEntitlement value) => _repository.save(value);
  Future<List<HrmLeaveEntitlement>> listForEmployee(int employeeId) =>
      _repository.findForEmployee(employeeId);
}

class HrmLeaveRequest {
  const HrmLeaveRequest({
    this.id,
    required this.companyId,
    required this.employeeId,
    required this.leaveTypeId,
    required this.dateApplied,
    this.comments,
    this.status = 'pendiente',
  });
  final int? id;
  final int companyId;
  final int employeeId;
  final int leaveTypeId;
  final DateTime dateApplied;
  final String? comments;
  final String status;
  Map<String, Object?> toMap() => {
    'company_id': companyId,
    'employee_id': employeeId,
    'leave_type_id': leaveTypeId,
    'date_applied': dateApplied.toIso8601String(),
    'comments': comments,
    'status': status,
  };
  factory HrmLeaveRequest.fromMap(Map<String, dynamic> m) => HrmLeaveRequest(
    id: (m['id'] as num?)?.toInt(),
    companyId: (m['company_id'] as num).toInt(),
    employeeId: (m['employee_id'] as num).toInt(),
    leaveTypeId: (m['leave_type_id'] as num).toInt(),
    dateApplied: DateTime.parse(m['date_applied'].toString()),
    comments: m['comments']?.toString(),
    status: m['status']?.toString() ?? 'pendiente',
  );
}

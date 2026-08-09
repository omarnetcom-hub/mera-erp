class MrpOperation {
  const MrpOperation({
    this.id,
    required this.companyId,
    required this.routingId,
    required this.workstationId,
    required this.operationName,
    this.sequenceOrder = 1,
    this.timeMinutes = 0,
  });
  final int? id;
  final int companyId;
  final int routingId;
  final int workstationId;
  final String operationName;
  final int sequenceOrder;
  final double timeMinutes;
  Map<String, Object?> toMap() => {
    'company_id': companyId,
    'routing_id': routingId,
    'workstation_id': workstationId,
    'operation_name': operationName,
    'sequence_order': sequenceOrder,
    'time_minutes': timeMinutes,
  };
  factory MrpOperation.fromMap(Map<String, dynamic> m) => MrpOperation(
    id: (m['id'] as num?)?.toInt(),
    companyId: (m['company_id'] as num).toInt(),
    routingId: (m['routing_id'] as num).toInt(),
    workstationId: (m['workstation_id'] as num).toInt(),
    operationName: m['operation_name'].toString(),
    sequenceOrder: (m['sequence_order'] as num?)?.toInt() ?? 1,
    timeMinutes: (m['time_minutes'] as num?)?.toDouble() ?? 0,
  );
}

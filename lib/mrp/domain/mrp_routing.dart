class MrpRouting {
  const MrpRouting({
    this.id,
    required this.companyId,
    required this.name,
    this.description,
  });
  final int? id;
  final int companyId;
  final String name;
  final String? description;
  Map<String, Object?> toMap() => {
    'company_id': companyId,
    'name': name,
    'description': description,
  };
  factory MrpRouting.fromMap(Map<String, dynamic> m) => MrpRouting(
    id: (m['id'] as num?)?.toInt(),
    companyId: (m['company_id'] as num).toInt(),
    name: m['name'].toString(),
    description: m['description']?.toString(),
  );
}

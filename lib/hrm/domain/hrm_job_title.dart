class HrmJobTitle {
  const HrmJobTitle({
    this.id,
    required this.companyId,
    required this.title,
    this.description,
    this.isDeleted = false,
  });
  final int? id;
  final int companyId;
  final String title;
  final String? description;
  final bool isDeleted;

  Map<String, Object?> toMap() => {
    'company_id': companyId,
    'title': title,
    'description': description,
    'is_deleted': isDeleted ? 1 : 0,
  };
  factory HrmJobTitle.fromMap(Map<String, dynamic> m) => HrmJobTitle(
    id: (m['id'] as num?)?.toInt(),
    companyId: (m['company_id'] as num).toInt(),
    title: m['title'].toString(),
    description: m['description']?.toString(),
    isDeleted: m['is_deleted'] == 1,
  );
}

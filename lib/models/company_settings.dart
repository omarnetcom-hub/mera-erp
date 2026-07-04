class CompanySettings {
  const CompanySettings({
    required this.companyId,
    required this.key,
    required this.value,
  });

  final int companyId;
  final String key;
  final String value;

  Map<String, dynamic> toMap() => {
    'company_id': companyId,
    'setting_key': key,
    'setting_value': value,
  };
}

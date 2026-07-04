class CompanyFeature {
  const CompanyFeature({
    required this.companyId,
    required this.featureKey,
    required this.enabled,
  });

  final int companyId;
  final String featureKey;
  final bool enabled;

  Map<String, dynamic> toMap() => {
    'company_id': companyId,
    'feature_key': featureKey,
    'enabled': enabled ? 1 : 0,
  };
}

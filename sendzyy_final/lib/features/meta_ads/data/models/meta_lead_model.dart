class MetaLeadModel {
  final String id;
  final String tenantId;
  final String name;
  final String mobileNumber;
  final String email;
  final String source;
  final String formName;
  final String status;
  final String? metaLeadgenId;
  final String? metaFormId;
  final String? metaCampaignId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  MetaLeadModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.mobileNumber,
    this.email = '',
    this.source = 'meta_ads',
    this.formName = '',
    this.status = 'new',
    this.metaLeadgenId,
    this.metaFormId,
    this.metaCampaignId,
    this.metadata = const {},
    this.createdAt,
  });

  factory MetaLeadModel.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : <String, dynamic>{};
    return MetaLeadModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Meta Lead',
      mobileNumber: json['mobileNumber']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      source: json['source']?.toString() ?? 'meta_ads',
      formName: json['formName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'new',
      metaLeadgenId: meta['metaLeadgenId']?.toString(),
      metaFormId: meta['metaFormId']?.toString(),
      metaCampaignId: meta['metaCampaignId']?.toString(),
      metadata: meta,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}

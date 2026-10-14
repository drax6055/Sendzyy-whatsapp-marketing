class MetaAccountStatus {
  final bool connected;
  final String status;
  final String? adAccountId;
  final String? adAccountName;
  final String? pageId;
  final String? pageName;
  final String? instagramActorId;
  final DateTime? connectedAt;
  final DateTime? expiresAt;
  final bool hasTenantOnboarding;
  final String? tenantBusinessId;
  final bool isPermanent;

  MetaAccountStatus({
    required this.connected,
    required this.status,
    this.adAccountId,
    this.adAccountName,
    this.pageId,
    this.pageName,
    this.instagramActorId,
    this.connectedAt,
    this.expiresAt,
    this.hasTenantOnboarding = false,
    this.tenantBusinessId,
    this.isPermanent = false,
  });

  factory MetaAccountStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map<String, dynamic> : json;
    final isPerm = json['isPermanent'] == true ||
        data['isPermanent'] == true ||
        (data['expiresAt'] == null && (json['connected'] == true || data['status'] == 'connected'));

    return MetaAccountStatus(
      connected: json['connected'] == true,
      status: (data['status'] ?? json['status'] ?? 'disconnected').toString(),
      adAccountId: data['adAccountId']?.toString(),
      adAccountName: data['adAccountName']?.toString(),
      pageId: data['pageId']?.toString(),
      pageName: data['pageName']?.toString(),
      instagramActorId: data['instagramActorId']?.toString(),
      connectedAt: data['connectedAt'] != null ? DateTime.tryParse(data['connectedAt'].toString()) : null,
      expiresAt: data['expiresAt'] != null ? DateTime.tryParse(data['expiresAt'].toString()) : null,
      hasTenantOnboarding: json['hasTenantOnboarding'] == true || data['hasTenantOnboarding'] == true,
      tenantBusinessId: (json['tenantBusinessId'] ?? data['tenantBusinessId'])?.toString(),
      isPermanent: isPerm,
    );
  }

  bool get isExpired =>
      !isPermanent &&
      (status == 'expired' ||
          (expiresAt != null && DateTime.now().isAfter(expiresAt!)));

  MetaAccountStatus copyWith({
    bool? connected,
    String? status,
    String? adAccountId,
    String? adAccountName,
    String? pageId,
    String? pageName,
    String? instagramActorId,
    DateTime? connectedAt,
    DateTime? expiresAt,
    bool? hasTenantOnboarding,
    String? tenantBusinessId,
    bool? isPermanent,
  }) {
    return MetaAccountStatus(
      connected: connected ?? this.connected,
      status: status ?? this.status,
      adAccountId: adAccountId ?? this.adAccountId,
      adAccountName: adAccountName ?? this.adAccountName,
      pageId: pageId ?? this.pageId,
      pageName: pageName ?? this.pageName,
      instagramActorId: instagramActorId ?? this.instagramActorId,
      connectedAt: connectedAt ?? this.connectedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      hasTenantOnboarding: hasTenantOnboarding ?? this.hasTenantOnboarding,
      tenantBusinessId: tenantBusinessId ?? this.tenantBusinessId,
      isPermanent: isPermanent ?? this.isPermanent,
    );
  }
}

class MetaAdAccountItem {
  final String id;
  final String name;
  final String accountId;
  final int accountStatus;
  final String currency;
  final String? timezoneName;
  final double amountSpent;

  MetaAdAccountItem({
    required this.id,
    required this.name,
    required this.accountId,
    required this.accountStatus,
    required this.currency,
    this.timezoneName,
    required this.amountSpent,
  });

  factory MetaAdAccountItem.fromJson(Map<String, dynamic> json) {
    return MetaAdAccountItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Account',
      accountId: json['account_id']?.toString() ?? '',
      accountStatus: int.tryParse(json['account_status']?.toString() ?? '1') ?? 1,
      currency: json['currency']?.toString() ?? 'INR',
      timezoneName: json['timezone_name']?.toString(),
      amountSpent: (double.tryParse(json['amount_spent']?.toString() ?? '0') ?? 0) / 100,
    );
  }
}

class MetaPageItem {
  final String id;
  final String name;
  final String? category;
  final String? instagramId;
  final String? instagramUsername;

  MetaPageItem({
    required this.id,
    required this.name,
    this.category,
    this.instagramId,
    this.instagramUsername,
  });

  factory MetaPageItem.fromJson(Map<String, dynamic> json) {
    final ig = json['instagram_business_account'];
    return MetaPageItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Page',
      category: json['category']?.toString(),
      instagramId: ig is Map ? ig['id']?.toString() : null,
      instagramUsername: ig is Map ? ig['username']?.toString() : null,
    );
  }
}

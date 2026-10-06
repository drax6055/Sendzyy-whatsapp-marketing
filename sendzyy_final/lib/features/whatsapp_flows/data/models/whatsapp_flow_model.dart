class WhatsAppFlowModel {
  final String id;
  final String flowId;
  final String name;
  final List<String> categories;
  final String status; // DRAFT, PUBLISHED, DEPRECATED
  final String ctaText;
  final String headerText;
  final String bodyText;
  final String footerText;
  final int submissionsCount;
  final Map<String, dynamic> flowJson;
  final List<dynamic> fieldsConfig;
  final DateTime? updatedAt;

  WhatsAppFlowModel({
    required this.id,
    required this.flowId,
    required this.name,
    this.categories = const ['LEAD_GENERATION'],
    this.status = 'DRAFT',
    this.ctaText = 'Open Form',
    this.headerText = '',
    this.bodyText = '',
    this.footerText = 'Powered by Sendzyy',
    this.submissionsCount = 0,
    this.flowJson = const {},
    this.fieldsConfig = const [],
    this.updatedAt,
  });

  factory WhatsAppFlowModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppFlowModel(
      id: json['_id']?.toString() ?? '',
      flowId: json['flowId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Flow',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['LEAD_GENERATION'],
      status: json['status']?.toString() ?? 'DRAFT',
      ctaText: json['ctaText']?.toString() ?? 'Open Form',
      headerText: json['headerText']?.toString() ?? '',
      bodyText: json['bodyText']?.toString() ?? '',
      footerText: json['footerText']?.toString() ?? 'Powered by Sendzyy',
      submissionsCount: json['submissionsCount'] is int
          ? json['submissionsCount']
          : int.tryParse(json['submissionsCount']?.toString() ?? '0') ?? 0,
      flowJson: json['flowJson'] is Map<String, dynamic>
          ? json['flowJson'] as Map<String, dynamic>
          : {},
      fieldsConfig: json['fieldsConfig'] as List<dynamic>? ?? [],
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flowId': flowId,
      'name': name,
      'categories': categories,
      'status': status,
      'ctaText': ctaText,
      'headerText': headerText,
      'bodyText': bodyText,
      'footerText': footerText,
      'submissionsCount': submissionsCount,
      'flowJson': flowJson,
      'fieldsConfig': fieldsConfig,
    };
  }
}

class FlowFormField {
  String name;
  String label;
  String type; // text, email, phone, textarea, dropdown, radio, checkbox, date, opt_in
  bool required;
  List<String> options;

  FlowFormField({
    required this.name,
    required this.label,
    this.type = 'text',
    this.required = true,
    this.options = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'label': label,
        'type': type,
        'required': required,
        if (options.isNotEmpty) 'options': options,
      };

  factory FlowFormField.fromJson(Map<String, dynamic> json) => FlowFormField(
        name: json['name']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        type: json['type']?.toString() ?? 'text',
        required: json['required'] != false,
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class FlowSubmissionModel {
  final String id;
  final String flowId;
  final String flowName;
  final String contactId;
  final String contactName;
  final Map<String, dynamic> responseData;
  final String source;
  final DateTime? createdAt;

  FlowSubmissionModel({
    required this.id,
    required this.flowId,
    this.flowName = '',
    required this.contactId,
    this.contactName = '',
    this.responseData = const {},
    this.source = 'chat',
    this.createdAt,
  });

  factory FlowSubmissionModel.fromJson(Map<String, dynamic> json) {
    return FlowSubmissionModel(
      id: json['_id']?.toString() ?? '',
      flowId: json['flowId']?.toString() ?? '',
      flowName: json['flowName']?.toString() ?? '',
      contactId: json['contactId']?.toString() ?? '',
      contactName: json['contactName']?.toString() ?? '',
      responseData: json['responseData'] is Map<String, dynamic>
          ? json['responseData'] as Map<String, dynamic>
          : {},
      source: json['source']?.toString() ?? 'chat',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

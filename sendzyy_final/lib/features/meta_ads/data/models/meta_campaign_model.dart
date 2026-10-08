class MetaCampaignModel {
  final String id;
  final String tenantId;
  final String? metaCampaignId;
  final String? metaAdSetId;
  final String? metaCreativeId;
  final String? metaAdId;
  final String? metaLeadFormId;

  // Step 1: Campaign
  final String name;
  final String objective;
  final List<String> specialAdCategories;
  final List<String> specialAdCategoryCountries;
  final bool advantageCampaignBudget;
  final BudgetConfig? campaignBudget;
  final String campaignBidStrategy;
  final bool isAbTest;

  // Step 2: Ad Set
  final String adSetName;
  final String optimizationGoal;
  final String destinationType;
  final String billingEvent;
  final BudgetConfig? adSetBudget;
  final String bidStrategy;
  final double? bidAmount;
  final ScheduleConfig schedule;
  final TargetingConfig targeting;
  final PlacementsConfig placements;

  // Step 3: Creative & Ad
  final String adName;
  final String? pageId;
  final String? instagramAccountId;
  final String format;
  final CreativeConfig creative;
  final LeadFormConfig? leadForm;

  // Status & Insights
  final String status;
  final CampaignInsights insights;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MetaCampaignModel({
    required this.id,
    required this.tenantId,
    this.metaCampaignId,
    this.metaAdSetId,
    this.metaCreativeId,
    this.metaAdId,
    this.metaLeadFormId,
    required this.name,
    required this.objective,
    this.specialAdCategories = const ['NONE'],
    this.specialAdCategoryCountries = const [],
    this.advantageCampaignBudget = false,
    this.campaignBudget,
    this.campaignBidStrategy = 'LOWEST_COST_WITHOUT_CAP',
    this.isAbTest = false,
    required this.adSetName,
    required this.optimizationGoal,
    required this.destinationType,
    this.billingEvent = 'IMPRESSIONS',
    this.adSetBudget,
    this.bidStrategy = 'LOWEST_COST_WITHOUT_CAP',
    this.bidAmount,
    required this.schedule,
    required this.targeting,
    required this.placements,
    required this.adName,
    this.pageId,
    this.instagramAccountId,
    this.format = 'SINGLE_IMAGE',
    required this.creative,
    this.leadForm,
    this.status = 'ACTIVE',
    required this.insights,
    this.createdAt,
    this.updatedAt,
  });

  factory MetaCampaignModel.fromJson(Map<String, dynamic> json) {
    return MetaCampaignModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      metaCampaignId: json['metaCampaignId']?.toString(),
      metaAdSetId: json['metaAdSetId']?.toString(),
      metaCreativeId: json['metaCreativeId']?.toString(),
      metaAdId: json['metaAdId']?.toString(),
      metaLeadFormId: json['metaLeadFormId']?.toString(),
      name: json['name']?.toString() ?? 'Untitled Campaign',
      objective: json['objective']?.toString() ?? 'OUTCOME_LEADS',
      specialAdCategories: (json['specialAdCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['NONE'],
      specialAdCategoryCountries: (json['specialAdCategoryCountries'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      advantageCampaignBudget: json['advantageCampaignBudget'] == true,
      campaignBudget: json['campaignBudget'] is Map
          ? BudgetConfig.fromJson(Map<String, dynamic>.from(json['campaignBudget'] as Map))
          : null,
      campaignBidStrategy: json['campaignBidStrategy']?.toString() ?? 'LOWEST_COST_WITHOUT_CAP',
      isAbTest: json['isAbTest'] == true,
      adSetName: json['adSetName']?.toString() ?? '',
      optimizationGoal: json['optimizationGoal']?.toString() ?? 'LEAD_GENERATION',
      destinationType: json['destinationType']?.toString() ?? 'ON_AD',
      billingEvent: json['billingEvent']?.toString() ?? 'IMPRESSIONS',
      adSetBudget: json['adSetBudget'] is Map
          ? BudgetConfig.fromJson(Map<String, dynamic>.from(json['adSetBudget'] as Map))
          : null,
      bidStrategy: json['bidStrategy']?.toString() ?? 'LOWEST_COST_WITHOUT_CAP',
      bidAmount: json['bidAmount'] != null ? double.tryParse(json['bidAmount'].toString()) : null,
      schedule: json['schedule'] is Map
          ? ScheduleConfig.fromJson(Map<String, dynamic>.from(json['schedule'] as Map))
          : ScheduleConfig.defaultConfig(),
      targeting: json['targeting'] is Map
          ? TargetingConfig.fromJson(Map<String, dynamic>.from(json['targeting'] as Map))
          : TargetingConfig.defaultConfig(),
      placements: json['placements'] is Map
          ? PlacementsConfig.fromJson(Map<String, dynamic>.from(json['placements'] as Map))
          : PlacementsConfig.defaultConfig(),
      adName: json['adName']?.toString() ?? '',
      pageId: json['identity'] is Map ? json['identity']['pageId']?.toString() : null,
      instagramAccountId: json['identity'] is Map ? json['identity']['instagramAccountId']?.toString() : null,
      format: json['format']?.toString() ?? 'SINGLE_IMAGE',
      creative: json['creative'] is Map
          ? CreativeConfig.fromJson(Map<String, dynamic>.from(json['creative'] as Map))
          : CreativeConfig.empty(),
      leadForm: json['leadForm'] is Map
          ? LeadFormConfig.fromJson(Map<String, dynamic>.from(json['leadForm'] as Map))
          : null,
      status: json['status']?.toString() ?? 'ACTIVE',
      insights: json['insights'] is Map
          ? CampaignInsights.fromJson(Map<String, dynamic>.from(json['insights'] as Map))
          : CampaignInsights.empty(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'objective': objective,
      'specialAdCategories': specialAdCategories,
      'specialAdCategoryCountries': specialAdCategoryCountries,
      'advantageCampaignBudget': advantageCampaignBudget,
      if (campaignBudget != null) 'campaignBudget': campaignBudget!.toJson(),
      'campaignBidStrategy': campaignBidStrategy,
      'isAbTest': isAbTest,
      'adSetName': adSetName,
      'optimizationGoal': optimizationGoal,
      'destinationType': destinationType,
      'billingEvent': billingEvent,
      if (adSetBudget != null) 'adSetBudget': adSetBudget!.toJson(),
      'bidStrategy': bidStrategy,
      if (bidAmount != null) 'bidAmount': bidAmount,
      'schedule': schedule.toJson(),
      'targeting': targeting.toJson(),
      'placements': placements.toJson(),
      'adName': adName,
      'identity': {
        'pageId': pageId,
        'instagramAccountId': instagramAccountId,
      },
      'format': format,
      'creative': creative.toJson(),
      if (leadForm != null) 'leadForm': leadForm!.toJson(),
      'status': status,
    };
  }
}

class BudgetConfig {
  final String type; // 'daily' or 'lifetime'
  final double amount; // in rupees
  final String currency;

  BudgetConfig({
    required this.type,
    required this.amount,
    this.currency = 'INR',
  });

  factory BudgetConfig.fromJson(Map<String, dynamic> json) {
    final rawAmount = double.tryParse(json['amount']?.toString() ?? '0') ?? 0;
    // backend amounts in paise (1/100 INR)
    final amountInRupees = rawAmount > 5000 ? rawAmount / 100 : rawAmount;
    return BudgetConfig(
      type: json['type']?.toString() ?? 'daily',
      amount: amountInRupees,
      currency: json['currency']?.toString() ?? 'INR',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'amount': (amount * 100).toInt(), // convert to paise
        'currency': currency,
      };
}

class ScheduleConfig {
  final DateTime startTime;
  final DateTime? endTime;
  final bool runContinuously;

  ScheduleConfig({
    required this.startTime,
    this.endTime,
    this.runContinuously = true,
  });

  factory ScheduleConfig.defaultConfig() => ScheduleConfig(
        startTime: DateTime.now(),
        runContinuously: true,
      );

  factory ScheduleConfig.fromJson(Map<String, dynamic> json) {
    return ScheduleConfig(
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'].toString()) : null,
      runContinuously: json['runContinuously'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        if (endTime != null && !runContinuously) 'endTime': endTime!.toIso8601String(),
        'runContinuously': runContinuously,
      };
}

class TargetingConfig {
  final String audienceType; // 'advantage_plus' or 'manual'
  final List<LocationTarget> locations;
  final String locationType;
  final int ageMin;
  final int ageMax;
  final String gender; // 'ALL', 'MALE', 'FEMALE'
  final List<String> languages;
  final List<TargetingItem> interests;
  final List<TargetingItem> behaviors;
  final bool targetingExpansion;

  TargetingConfig({
    this.audienceType = 'advantage_plus',
    this.locations = const [],
    this.locationType = 'home_or_recent',
    this.ageMin = 18,
    this.ageMax = 65,
    this.gender = 'ALL',
    this.languages = const [],
    this.interests = const [],
    this.behaviors = const [],
    this.targetingExpansion = true,
  });

  factory TargetingConfig.defaultConfig() => TargetingConfig(
        locations: [LocationTarget(name: 'India', key: 'IN', type: 'country', countryCode: 'IN')],
      );

  factory TargetingConfig.fromJson(Map<String, dynamic> json) {
    return TargetingConfig(
      audienceType: json['audienceType']?.toString() ?? 'advantage_plus',
      locations: (json['locations'] as List<dynamic>?)
              ?.map((e) => LocationTarget.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      locationType: json['locationType']?.toString() ?? 'home_or_recent',
      ageMin: int.tryParse(json['ageMin']?.toString() ?? '18') ?? 18,
      ageMax: int.tryParse(json['ageMax']?.toString() ?? '65') ?? 65,
      gender: json['gender']?.toString() ?? 'ALL',
      languages: (json['languages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => TargetingItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      behaviors: (json['behaviors'] as List<dynamic>?)
              ?.map((e) => TargetingItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      targetingExpansion: json['targetingExpansion'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'audienceType': audienceType,
        'locations': locations.map((e) => e.toJson()).toList(),
        'locationType': locationType,
        'ageMin': ageMin,
        'ageMax': ageMax,
        'gender': gender,
        'languages': languages,
        'interests': interests.map((e) => e.toJson()).toList(),
        'behaviors': behaviors.map((e) => e.toJson()).toList(),
        'targetingExpansion': targetingExpansion,
      };
}

class LocationTarget {
  final String type; // country, city, region
  final String name;
  final String key;
  final String countryCode;
  final double radius;
  final String distanceUnit;

  LocationTarget({
    this.type = 'country',
    required this.name,
    required this.key,
    this.countryCode = 'IN',
    this.radius = 0,
    this.distanceUnit = 'kilometer',
  });

  factory LocationTarget.fromJson(Map<String, dynamic> json) => LocationTarget(
        type: json['type']?.toString() ?? 'country',
        name: json['name']?.toString() ?? 'India',
        key: json['key']?.toString() ?? 'IN',
        countryCode: json['countryCode']?.toString() ?? 'IN',
        radius: double.tryParse(json['radius']?.toString() ?? '0') ?? 0,
        distanceUnit: json['distanceUnit']?.toString() ?? 'kilometer',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'key': key,
        'countryCode': countryCode,
        'radius': radius,
        'distanceUnit': distanceUnit,
      };
}

class TargetingItem {
  final String id;
  final String name;

  TargetingItem({required this.id, required this.name});

  factory TargetingItem.fromJson(Map<String, dynamic> json) => TargetingItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class PlacementsConfig {
  final String placementType; // 'advantage_plus' or 'manual'
  final List<String> platforms;
  final List<String> facebookPositions;
  final List<String> instagramPositions;
  final List<String> devicePlatforms;

  PlacementsConfig({
    this.placementType = 'advantage_plus',
    this.platforms = const ['facebook', 'instagram'],
    this.facebookPositions = const ['feed', 'story', 'facebook_reels'],
    this.instagramPositions = const ['stream', 'story', 'reels', 'explore'],
    this.devicePlatforms = const ['mobile', 'desktop'],
  });

  factory PlacementsConfig.defaultConfig() => PlacementsConfig();

  factory PlacementsConfig.fromJson(Map<String, dynamic> json) => PlacementsConfig(
        placementType: json['placementType']?.toString() ?? 'advantage_plus',
        platforms: (json['platforms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            ['facebook', 'instagram'],
        facebookPositions: (json['facebookPositions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            ['feed', 'story', 'facebook_reels'],
        instagramPositions: (json['instagramPositions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            ['stream', 'story', 'reels', 'explore'],
        devicePlatforms: (json['devicePlatforms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            ['mobile', 'desktop'],
      );

  Map<String, dynamic> toJson() => {
        'placementType': placementType,
        'platforms': platforms,
        'facebookPositions': facebookPositions,
        'instagramPositions': instagramPositions,
        'devicePlatforms': devicePlatforms,
      };
}

class CreativeConfig {
  final String headline;
  final List<String> headlineVariants;
  final String primaryText;
  final List<String> primaryTextVariants;
  final String description;
  final List<String> descriptionVariants;
  final String callToAction;
  final String websiteUrl;
  final String displayUrl;
  final String? imageUrl;
  final String? imageHash;
  final String? videoUrl;

  CreativeConfig({
    required this.headline,
    this.headlineVariants = const [],
    required this.primaryText,
    this.primaryTextVariants = const [],
    this.description = '',
    this.descriptionVariants = const [],
    this.callToAction = 'LEARN_MORE',
    this.websiteUrl = '',
    this.displayUrl = '',
    this.imageUrl,
    this.imageHash,
    this.videoUrl,
  });

  factory CreativeConfig.empty() => CreativeConfig(
        headline: '',
        primaryText: '',
      );

  factory CreativeConfig.fromJson(Map<String, dynamic> json) => CreativeConfig(
        headline: json['headline']?.toString() ?? '',
        headlineVariants:
            (json['headlineVariants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        primaryText: json['primaryText']?.toString() ?? '',
        primaryTextVariants:
            (json['primaryTextVariants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        description: json['description']?.toString() ?? '',
        descriptionVariants:
            (json['descriptionVariants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        callToAction: json['callToAction']?.toString() ?? 'LEARN_MORE',
        websiteUrl: json['websiteUrl']?.toString() ?? '',
        displayUrl: json['displayUrl']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
        imageHash: json['imageHash']?.toString(),
        videoUrl: json['videoUrl']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'headlineVariants': headlineVariants,
        'primaryText': primaryText,
        'primaryTextVariants': primaryTextVariants,
        'description': description,
        'descriptionVariants': descriptionVariants,
        'callToAction': callToAction,
        'websiteUrl': websiteUrl,
        'displayUrl': displayUrl,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (imageHash != null) 'imageHash': imageHash,
        if (videoUrl != null) 'videoUrl': videoUrl,
      };
}

class LeadFormConfig {
  final String formName;
  final String formType; // MORE_VOLUME, HIGHER_INTENT, RICH_CREATIVE
  final String language;
  final String introHeadline;
  final String introDescription;
  final List<LeadFormQuestion> questions;
  final String privacyPolicyUrl;
  final String completionHeadline;
  final String completionDescription;
  final String completionCtaType;
  final String completionCtaText;
  final String completionCtaUrl;

  LeadFormConfig({
    required this.formName,
    this.formType = 'MORE_VOLUME',
    this.language = 'en_US',
    this.introHeadline = '',
    this.introDescription = '',
    required this.questions,
    required this.privacyPolicyUrl,
    this.completionHeadline = 'Thank you!',
    this.completionDescription = 'Our team will contact you via WhatsApp shortly.',
    this.completionCtaType = 'SEND_WHATSAPP',
    this.completionCtaText = 'Chat on WhatsApp',
    this.completionCtaUrl = '',
  });

  factory LeadFormConfig.defaultForm() => LeadFormConfig(
        formName: 'Quick Inquiry Form',
        questions: [
          LeadFormQuestion(type: 'FULL_NAME', label: 'Full name'),
          LeadFormQuestion(type: 'PHONE', label: 'Phone number'),
          LeadFormQuestion(type: 'EMAIL', label: 'Email address'),
        ],
        privacyPolicyUrl: 'https://sendzyy.com/privacy',
      );

  factory LeadFormConfig.fromJson(Map<String, dynamic> json) {
    return LeadFormConfig(
      formName: json['formName']?.toString() ?? 'Lead Form',
      formType: json['formType']?.toString() ?? 'MORE_VOLUME',
      language: json['language']?.toString() ?? 'en_US',
      introHeadline: json['intro'] is Map ? json['intro']['headline']?.toString() ?? '' : '',
      introDescription: json['intro'] is Map ? json['intro']['description']?.toString() ?? '' : '',
      questions: (json['questions'] as List<dynamic>?)
              ?.map((e) => LeadFormQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      privacyPolicyUrl: json['privacyPolicy'] is Map ? json['privacyPolicy']['url']?.toString() ?? '' : '',
      completionHeadline:
          json['completion'] is Map ? json['completion']['headline']?.toString() ?? 'Thank you!' : 'Thank you!',
      completionDescription: json['completion'] is Map
          ? json['completion']['description']?.toString() ?? ''
          : '',
      completionCtaType: json['completion'] is Map
          ? json['completion']['ctaType']?.toString() ?? 'SEND_WHATSAPP'
          : 'SEND_WHATSAPP',
      completionCtaText: json['completion'] is Map
          ? json['completion']['ctaText']?.toString() ?? 'Chat on WhatsApp'
          : 'Chat on WhatsApp',
      completionCtaUrl: json['completion'] is Map ? json['completion']['ctaUrl']?.toString() ?? '' : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'formName': formName,
        'formType': formType,
        'language': language,
        'intro': {
          'headline': introHeadline,
          'description': introDescription,
        },
        'questions': questions.map((e) => e.toJson()).toList(),
        'privacyPolicy': {
          'url': privacyPolicyUrl,
          'linkText': 'Privacy Policy',
        },
        'completion': {
          'headline': completionHeadline,
          'description': completionDescription,
          'ctaType': completionCtaType,
          'ctaText': completionCtaText,
          'ctaUrl': completionCtaUrl,
        },
      };
}

class LeadFormQuestion {
  final String type; // FULL_NAME, PHONE, EMAIL, CITY, CUSTOM_SHORT_ANSWER, CUSTOM_MULTIPLE_CHOICE
  final String label;
  final List<String> options;

  LeadFormQuestion({
    required this.type,
    required this.label,
    this.options = const [],
  });

  factory LeadFormQuestion.fromJson(Map<String, dynamic> json) => LeadFormQuestion(
        type: json['type']?.toString() ?? 'FULL_NAME',
        label: json['label']?.toString() ?? 'Question',
        options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        if (options.isNotEmpty) 'options': options,
      };
}

class CampaignInsights {
  final double spend;
  final int reach;
  final int impressions;
  final int clicks;
  final double cpc;
  final double cpm;
  final double ctr;
  final int leadsCount;
  final double cpl;
  final DateTime? lastSyncedAt;

  CampaignInsights({
    this.spend = 0,
    this.reach = 0,
    this.impressions = 0,
    this.clicks = 0,
    this.cpc = 0,
    this.cpm = 0,
    this.ctr = 0,
    this.leadsCount = 0,
    this.cpl = 0,
    this.lastSyncedAt,
  });

  factory CampaignInsights.empty() => CampaignInsights();

  factory CampaignInsights.fromJson(Map<String, dynamic> json) => CampaignInsights(
        spend: double.tryParse(json['spend']?.toString() ?? '0') ?? 0,
        reach: int.tryParse(json['reach']?.toString() ?? '0') ?? 0,
        impressions: int.tryParse(json['impressions']?.toString() ?? '0') ?? 0,
        clicks: int.tryParse(json['clicks']?.toString() ?? '0') ?? 0,
        cpc: double.tryParse(json['cpc']?.toString() ?? '0') ?? 0,
        cpm: double.tryParse(json['cpm']?.toString() ?? '0') ?? 0,
        ctr: double.tryParse(json['ctr']?.toString() ?? '0') ?? 0,
        leadsCount: int.tryParse(json['leadsCount']?.toString() ?? '0') ?? 0,
        cpl: double.tryParse(json['cpl']?.toString() ?? '0') ?? 0,
        lastSyncedAt: json['lastSyncedAt'] != null ? DateTime.tryParse(json['lastSyncedAt'].toString()) : null,
      );

  Map<String, dynamic> toJson() => {
        'spend': spend,
        'reach': reach,
        'impressions': impressions,
        'clicks': clicks,
        'cpc': cpc,
        'cpm': cpm,
        'ctr': ctr,
        'leadsCount': leadsCount,
        'cpl': cpl,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      };
}

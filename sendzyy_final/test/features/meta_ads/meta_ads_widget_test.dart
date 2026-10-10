import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:iFloraBuzz/core/di/injection.dart' as di;
import 'package:iFloraBuzz/features/meta_ads/data/repositories/meta_ads_repository.dart';
import 'package:iFloraBuzz/features/meta_ads/presentation/bloc/meta_ads_bloc.dart';
import 'package:iFloraBuzz/features/meta_ads/presentation/pages/meta_ads_dashboard_page.dart';
import 'package:iFloraBuzz/features/meta_ads/presentation/pages/create_campaign_wizard_page.dart';
import 'package:iFloraBuzz/features/meta_ads/presentation/pages/meta_leads_page.dart';
import 'package:iFloraBuzz/features/meta_ads/presentation/pages/campaign_details_analytics_page.dart';
import 'package:iFloraBuzz/features/meta_ads/data/models/meta_account_model.dart';
import 'package:iFloraBuzz/features/meta_ads/data/models/meta_campaign_model.dart';
import 'package:iFloraBuzz/features/meta_ads/data/models/meta_lead_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMetaAdsRepository extends MetaAdsRepository {
  FakeMetaAdsRepository() : super(Dio());

  @override
  Future<MetaAccountStatus> getAccountStatus() async =>
      MetaAccountStatus(connected: false, status: 'disconnected');

  @override
  Future<List<MetaCampaignModel>> getCampaigns({String? status, String? search}) async => [];

  @override
  Future<List<MetaLeadModel>> getMetaLeads({String? campaignId}) async => [];

  @override
  Future<List<MetaAdAccountItem>> getAdAccounts() async => [];

  @override
  Future<List<MetaPageItem>> getPages() async => [];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await di.getIt.reset();
    di.getIt.registerLazySingleton<Dio>(() => Dio());
    di.getIt.registerLazySingleton<MetaAdsRepository>(() => FakeMetaAdsRepository());
    di.getIt.registerFactory<MetaAdsBloc>(() => MetaAdsBloc(di.getIt<MetaAdsRepository>()));
  });

  testWidgets('MetaAdsDashboardPage renders without throwing exception', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final bloc = di.getIt<MetaAdsBloc>();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<MetaAdsBloc>.value(
          value: bloc,
          child: const MetaAdsDashboardPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Meta Ads Manager'), findsOneWidget);
  });

  testWidgets('CreateCampaignWizardPage renders without throwing exception', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final bloc = di.getIt<MetaAdsBloc>();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<MetaAdsBloc>.value(
          value: bloc,
          child: const CreateCampaignWizardPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Create Meta Campaign Wizard'), findsOneWidget);
  });

  testWidgets('MetaLeadsPage renders without throwing exception', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final bloc = di.getIt<MetaAdsBloc>();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<MetaAdsBloc>.value(
          value: bloc,
          child: const MetaLeadsPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Meta Ads Leads'), findsOneWidget);
  });

  testWidgets('CampaignDetailsAnalyticsPage renders without throwing exception', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final campaign = MetaCampaignModel(
      id: 'camp_123',
      tenantId: 'tenant_1',
      name: 'Test Campaign',
      objective: 'OUTCOME_LEADS',
      adSetName: 'Test AdSet',
      optimizationGoal: 'LEAD_GENERATION',
      destinationType: 'ON_AD',
      schedule: ScheduleConfig(startTime: DateTime.now(), runContinuously: true),
      targeting: TargetingConfig(audienceType: 'advantage_plus'),
      placements: PlacementsConfig(placementType: 'advantage_plus'),
      adName: 'Test Ad',
      creative: CreativeConfig(headline: 'Test Headline', primaryText: 'Test Primary'),
      insights: CampaignInsights.empty(),
    );

    final bloc = di.getIt<MetaAdsBloc>();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<MetaAdsBloc>.value(
          value: bloc,
          child: CampaignDetailsAnalyticsPage(campaign: campaign),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Test Campaign'), findsOneWidget);
  });
}

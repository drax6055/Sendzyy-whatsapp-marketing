import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/meta_campaign_model.dart';
import '../../data/models/meta_account_model.dart';
import '../../data/repositories/meta_ads_repository.dart';
import '../bloc/meta_ads_bloc.dart';
import '../bloc/meta_ads_event.dart';
import '../bloc/meta_ads_state.dart';
import '../widgets/step1_campaign_level_widget.dart';
import '../widgets/step2_adset_level_widget.dart';
import '../widgets/step3_creative_level_widget.dart';
import '../widgets/step3b_lead_form_widget.dart';
import '../widgets/step4_review_publish_widget.dart';

class CreateCampaignWizardPage extends StatefulWidget {
  const CreateCampaignWizardPage({super.key});

  @override
  State<CreateCampaignWizardPage> createState() => _CreateCampaignWizardPageState();
}

class _CreateCampaignWizardPageState extends State<CreateCampaignWizardPage> {
  int _currentStep = 0;

  // ── Step 1 Controllers & State ─────────────────────────────────────────────
  final _campaignNameController = TextEditingController(text: 'New Meta Campaign');
  String _selectedObjective = 'OUTCOME_LEADS';
  List<String> _specialAdCategories = ['NONE'];
  bool _advantageBudget = false;
  String _campaignBudgetType = 'daily';
  final _campaignBudgetAmountController = TextEditingController(text: '500');
  String _campaignBidStrategy = 'LOWEST_COST_WITHOUT_CAP';
  bool _isAbTest = false;

  // ── Step 2 Controllers & State ─────────────────────────────────────────────
  final _adSetNameController = TextEditingController(text: 'Ad Set 1 - Primary Audience');
  String _destinationType = 'ON_AD';
  String _optimizationGoal = 'LEAD_GENERATION';
  String _adSetBudgetType = 'daily';
  final _adSetBudgetAmountController = TextEditingController(text: '500');
  bool _runContinuously = true;
  String _audienceType = 'advantage_plus';
  int _ageMin = 21;
  int _ageMax = 55;
  String _gender = 'ALL';
  List<String> _interests = ['Business & Industry', 'Small Business'];
  String _placementType = 'advantage_plus';
  List<String> _selectedPlatforms = ['facebook', 'instagram'];

  // ── Step 3 Controllers & State ─────────────────────────────────────────────
  final _adNameController = TextEditingController(text: 'Ad 1 - Primary Creative');
  String? _selectedPageId;
  String _adFormat = 'SINGLE_IMAGE';
  final _primaryTextController = TextEditingController(
    text: 'Grow your business with fast WhatsApp Marketing campaigns that convert. Get instant quotes today!',
  );
  final _headlineController = TextEditingController(text: 'Get 5x More Inquiries on WhatsApp');
  final _descriptionController = TextEditingController(text: 'Verified Meta Partner Solution');
  String _callToAction = 'LEARN_MORE';
  final _websiteUrlController = TextEditingController(text: 'https://sendzyy.com');
  String? _selectedImagePath;

  // ── Step 3B Lead Form State ────────────────────────────────────────────────
  final _formNameController = TextEditingController(text: 'WhatsApp Inquiry Form');
  String _formType = 'MORE_VOLUME';
  final _introHeadlineController = TextEditingController(text: 'Ready to automate your marketing?');
  final _introDescController = TextEditingController(text: 'Fill in your details below to get a customized demo.');
  List<LeadFormQuestion> _questions = [
    LeadFormQuestion(type: 'FULL_NAME', label: 'Full name'),
    LeadFormQuestion(type: 'PHONE', label: 'Phone number'),
    LeadFormQuestion(type: 'EMAIL', label: 'Email address'),
  ];
  final _privacyPolicyController = TextEditingController(text: 'https://sendzyy.com/privacy');
  final _completionHeadlineController = TextEditingController(text: 'Thank You! Details Received.');
  final _completionDescController = TextEditingController(text: 'Our team will reach out to you via WhatsApp shortly.');
  String _completionCtaType = 'SEND_WHATSAPP';
  final _completionCtaTextController = TextEditingController(text: 'Chat on WhatsApp');
  final _completionCtaUrlController = TextEditingController(text: 'https://sendzyy.com');

  @override
  void initState() {
    super.initState();
    final bloc = context.read<MetaAdsBloc>();
    _selectedPageId = bloc.state.accountStatus?.pageId ??
        (bloc.state.pages.isNotEmpty ? bloc.state.pages.first.id : null);
  }

  @override
  void dispose() {
    _campaignNameController.dispose();
    _campaignBudgetAmountController.dispose();
    _adSetNameController.dispose();
    _adSetBudgetAmountController.dispose();
    _adNameController.dispose();
    _primaryTextController.dispose();
    _headlineController.dispose();
    _descriptionController.dispose();
    _websiteUrlController.dispose();
    _formNameController.dispose();
    _introHeadlineController.dispose();
    _introDescController.dispose();
    _privacyPolicyController.dispose();
    _completionHeadlineController.dispose();
    _completionDescController.dispose();
    _completionCtaTextController.dispose();
    _completionCtaUrlController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitCampaign(BuildContext context) async {
    final bloc = context.read<MetaAdsBloc>();
    String? imageHash;

    // Upload image if selected
    if (_selectedImagePath != null) {
      try {
        final repo = getIt<MetaAdsRepository>();
        final uploadResult = await repo.uploadCreativeImage(_selectedImagePath!);
        imageHash = uploadResult.hash;
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload warning: ${e.toString()}'), backgroundColor: Colors.amber),
        );
      }
    }

    final double budgetAmount = _advantageBudget
        ? (double.tryParse(_campaignBudgetAmountController.text) ?? 500)
        : (double.tryParse(_adSetBudgetAmountController.text) ?? 500);

    final effectivePageId = _selectedPageId ??
        bloc.state.accountStatus?.pageId ??
        (bloc.state.pages.isNotEmpty ? bloc.state.pages.first.id : null);

    if (effectivePageId == null || effectivePageId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please connect and select a Facebook Page before creating ads.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final payload = {
      'name': _campaignNameController.text.trim(),
      'objective': _selectedObjective,
      'specialAdCategories': _specialAdCategories,
      'advantageCampaignBudget': _advantageBudget,
      if (_advantageBudget)
        'campaignBudget': {
          'type': _campaignBudgetType,
          'amount': (budgetAmount * 100).toInt(),
          'currency': 'INR',
        },
      'campaignBidStrategy': _campaignBidStrategy,
      'isAbTest': _isAbTest,
      'adSetName': _adSetNameController.text.trim(),
      'destinationType': _destinationType,
      'optimizationGoal': _optimizationGoal,
      if (!_advantageBudget)
        'adSetBudget': {
          'type': _adSetBudgetType,
          'amount': (budgetAmount * 100).toInt(),
          'currency': 'INR',
        },
      'schedule': {
        'runContinuously': _runContinuously,
      },
      'targeting': {
        'audienceType': _audienceType,
        'ageMin': _ageMin,
        'ageMax': _ageMax,
        'gender': _gender,
        'interests': _interests.map((i) => {'id': i, 'name': i}).toList(),
      },
      'placements': {
        'placementType': _placementType,
        'platforms': _selectedPlatforms,
      },
      'adName': _adNameController.text.trim(),
      'identity': {
        'pageId': effectivePageId,
      },
      'format': _adFormat,
      'creative': {
        'headline': _headlineController.text.trim(),
        'primaryText': _primaryTextController.text.trim(),
        'description': _descriptionController.text.trim(),
        'callToAction': _callToAction,
        'websiteUrl': _websiteUrlController.text.trim(),
        if (imageHash != null) 'imageHash': imageHash,
      },
      if (_selectedObjective == 'OUTCOME_LEADS' && _destinationType == 'ON_AD')
        'leadForm': {
          'formName': _formNameController.text.trim(),
          'formType': _formType,
          'intro': {
            'headline': _introHeadlineController.text.trim(),
            'description': _introDescController.text.trim(),
          },
          'questions': _questions.map((q) => q.toJson()).toList(),
          'privacyPolicy': {
            'url': _privacyPolicyController.text.trim(),
            'linkText': 'Privacy Policy',
          },
          'completion': {
            'headline': _completionHeadlineController.text.trim(),
            'description': _completionDescController.text.trim(),
            'ctaType': _completionCtaType,
            'ctaText': _completionCtaTextController.text.trim(),
            'ctaUrl': _completionCtaUrlController.text.trim(),
          },
        },
    };

    bloc.add(CreateMetaCampaignEvent(payload));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MetaAdsBloc, MetaAdsState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
          );
        } else if (state.successMessage != null && state.successMessage!.contains('published')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.successMessage!), backgroundColor: const Color(0xFF10B981)),
          );
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Meta Campaign Wizard'),
          backgroundColor: const Color(0xFF1877F2), // Meta Blue
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Stepper Navigation Header
            _buildStepperHeader(),

            // Step Content
            Expanded(
              child: BlocBuilder<MetaAdsBloc, MetaAdsState>(
                builder: (context, state) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: _buildCurrentStepContent(state),
                  );
                },
              ),
            ),

            // Bottom Navigation Actions
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    final steps = ['Campaign', 'Ad Set', 'Creative', 'Review'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: List.generate(steps.length, (index) {
          final isCompleted = _currentStep > index;
          final isCurrent = _currentStep == index;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isCurrent
                            ? const Color(0xFF1877F2)
                            : isCompleted
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade300,
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        steps[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent ? const Color(0xFF1877F2) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 24,
                    height: 2,
                    color: isCompleted ? const Color(0xFF10B981) : Colors.grey.shade300,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent(MetaAdsState state) {
    switch (_currentStep) {
      case 0:
        return Step1CampaignLevelWidget(
          nameController: _campaignNameController,
          selectedObjective: _selectedObjective,
          onObjectiveChanged: (val) => setState(() => _selectedObjective = val),
          specialAdCategories: _specialAdCategories,
          onSpecialCategoriesChanged: (val) => setState(() => _specialAdCategories = val),
          advantageBudget: _advantageBudget,
          onAdvantageBudgetChanged: (val) => setState(() => _advantageBudget = val),
          budgetType: _campaignBudgetType,
          onBudgetTypeChanged: (val) => setState(() => _campaignBudgetType = val),
          budgetAmountController: _campaignBudgetAmountController,
          bidStrategy: _campaignBidStrategy,
          onBidStrategyChanged: (val) => setState(() => _campaignBidStrategy = val),
          isAbTest: _isAbTest,
          onAbTestChanged: (val) => setState(() => _isAbTest = val),
        );
      case 1:
        return Step2AdSetLevelWidget(
          adSetNameController: _adSetNameController,
          destinationType: _destinationType,
          onDestinationChanged: (val) => setState(() => _destinationType = val),
          optimizationGoal: _optimizationGoal,
          onOptimizationGoalChanged: (val) => setState(() => _optimizationGoal = val),
          advantageBudgetAtCampaign: _advantageBudget,
          adSetBudgetType: _adSetBudgetType,
          onAdSetBudgetTypeChanged: (val) => setState(() => _adSetBudgetType = val),
          adSetBudgetAmountController: _adSetBudgetAmountController,
          runContinuously: _runContinuously,
          onRunContinuouslyChanged: (val) => setState(() => _runContinuously = val),
          audienceType: _audienceType,
          onAudienceTypeChanged: (val) => setState(() => _audienceType = val),
          ageMin: _ageMin,
          ageMax: _ageMax,
          onAgeRangeChanged: (values) {
            setState(() {
              _ageMin = values.start.round();
              _ageMax = values.end.round();
            });
          },
          gender: _gender,
          onGenderChanged: (val) => setState(() => _gender = val),
          interests: _interests,
          onInterestsChanged: (val) => setState(() => _interests = val),
          placementType: _placementType,
          onPlacementTypeChanged: (val) => setState(() => _placementType = val),
          selectedPlatforms: _selectedPlatforms,
          onPlatformsChanged: (val) => setState(() => _selectedPlatforms = val),
        );
      case 2:
        return SingleChildScrollView(
          child: Column(
            children: [
              Step3CreativeLevelWidget(
                adNameController: _adNameController,
                pages: state.pages,
                selectedPageId: _selectedPageId ?? (state.pages.isNotEmpty ? state.pages.first.id : null),
                onPageChanged: (val) => setState(() => _selectedPageId = val),
                adFormat: _adFormat,
                onFormatChanged: (val) => setState(() => _adFormat = val),
                primaryTextController: _primaryTextController,
                headlineController: _headlineController,
                descriptionController: _descriptionController,
                callToAction: _callToAction,
                onCtaChanged: (val) => setState(() => _callToAction = val),
                websiteUrlController: _websiteUrlController,
                selectedImagePath: _selectedImagePath,
                onImageSelected: (path) => setState(() => _selectedImagePath = path),
              ),
              if (_selectedObjective == 'OUTCOME_LEADS' && _destinationType == 'ON_AD') ...[
                const SizedBox(height: 20),
                Step3bLeadFormWidget(
                  formNameController: _formNameController,
                  formType: _formType,
                  onFormTypeChanged: (val) => setState(() => _formType = val),
                  introHeadlineController: _introHeadlineController,
                  introDescController: _introDescController,
                  questions: _questions,
                  onQuestionsChanged: (val) => setState(() => _questions = val),
                  privacyPolicyController: _privacyPolicyController,
                  completionHeadlineController: _completionHeadlineController,
                  completionDescController: _completionDescController,
                  completionCtaType: _completionCtaType,
                  onCompletionCtaTypeChanged: (val) => setState(() => _completionCtaType = val),
                  completionCtaTextController: _completionCtaTextController,
                  completionCtaUrlController: _completionCtaUrlController,
                ),
              ],
            ],
          ),
        );
      case 3:
      default:
        final selectedPage = state.pages.firstWhere(
          (p) => p.id == _selectedPageId,
          orElse: () => state.pages.isNotEmpty
              ? state.pages.first
              : MetaPageItem(id: '', name: 'Your Business Page'),
        );
        final budgetDisplay = _advantageBudget
            ? '₹ ${_campaignBudgetAmountController.text} / $_campaignBudgetType'
            : '₹ ${_adSetBudgetAmountController.text} / $_adSetBudgetType';
        return Step4ReviewPublishWidget(
          campaignName: _campaignNameController.text,
          objective: _selectedObjective,
          budgetDisplay: budgetDisplay,
          adSetName: _adSetNameController.text,
          destinationType: _destinationType,
          audienceDisplay: 'India · Ages $_ageMin–$_ageMax · $_gender',
          primaryText: _primaryTextController.text,
          headline: _headlineController.text,
          description: _descriptionController.text,
          callToAction: _callToAction,
          imagePath: _selectedImagePath,
          pageName: selectedPage.name,
          isLeadFormIncluded: _selectedObjective == 'OUTCOME_LEADS' && _destinationType == 'ON_AD',
          questionsCount: _questions.length,
        );
    }
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: BlocBuilder<MetaAdsBloc, MetaAdsState>(
        builder: (context, state) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                OutlinedButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else
                const SizedBox.shrink(),
              if (_currentStep < 3)
                ElevatedButton.icon(
                  onPressed: _nextStep,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Next Step'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: state.isPublishing ? null : () => _submitCampaign(context),
                  icon: state.isPublishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: Text(state.isPublishing ? 'Publishing to Meta...' : 'Publish Campaign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

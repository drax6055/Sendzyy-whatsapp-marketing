import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive_helper.dart';

class MetaTriggerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> forms;

  const MetaTriggerDialog({super.key, required this.forms});

  @override
  State<MetaTriggerDialog> createState() => _MetaTriggerDialogState();
}

class _MetaTriggerDialogState extends State<MetaTriggerDialog> {
  final Dio _dio = getIt<Dio>();

  bool _loading = true;
  List<Map<String, dynamic>> _triggers = [];
  List<Map<String, dynamic>> _chatbots = [];
  List<Map<String, dynamic>> _templates = [];

  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _metaBlue = Color(0xFF1877F2);
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchTriggers(),
      _fetchChatbots(),
      _fetchTemplates(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchTriggers() async {
    try {
      final res = await _dio.get('/api/leads/triggers');
      if (res.statusCode == 200) {
        final list = (res.data as List<dynamic>? ?? []);
        _triggers = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((t) => t['source'] == 'meta_ads' || t['source'] == 'any')
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchChatbots() async {
    try {
      final res = await _dio.get('/api/chatbots');
      if (res.statusCode == 200) {
        final list = (res.data as List<dynamic>? ?? []);
        _chatbots = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((b) => b['isActive'] == true)
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchTemplates() async {
    try {
      final res = await _dio.get('/fetch-templates');
      if (res.statusCode == 200) {
        final list = (res.data['data'] as List<dynamic>? ?? []);
        _templates = list
            .where((t) => (t['status'] as String? ?? '').toUpperCase() == 'APPROVED')
            .where((t) => (t['category'] as String? ?? '').toUpperCase() != 'AUTHENTICATION')
            .map((t) {
              final components = t['components'] as List<dynamic>? ?? [];
              final body = components.firstWhere(
                (c) => (c['type'] as String? ?? '').toUpperCase() == 'BODY',
                orElse: () => null,
              );
              final bodyText = body?['text'] as String? ?? '';
              final matches = RegExp(r'\{\{\d+\}\}').allMatches(bodyText);
              final varCount = matches.map((m) => m.group(0)).toSet().length;

              return {
                'name': t['name']?.toString() ?? '',
                'language': t['language']?.toString() ?? 'en_US',
                'varCount': varCount,
              };
            })
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _toggleTrigger(Map<String, dynamic> trigger) async {
    final id = trigger['_id'];
    final newVal = !(trigger['isActive'] == true);
    try {
      await _dio.put('/api/leads/triggers/$id', data: {'isActive': newVal});
      setState(() => trigger['isActive'] = newVal);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update trigger: $e')),
        );
      }
    }
  }

  Future<void> _deleteTrigger(String id) async {
    try {
      await _dio.delete('/api/leads/triggers/$id');
      setState(() {
        _triggers.removeWhere((t) => t['_id'] == id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete trigger: $e')),
        );
      }
    }
  }

  void _openCreateOrEditRuleModal({Map<String, dynamic>? existing}) {
    showDialog(
      context: context,
      builder: (_) => _MetaRuleEditorModal(
        existing: existing,
        forms: widget.forms,
        templates: _templates,
        chatbots: _chatbots,
        onSaved: () => _loadData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 40, vertical: 24),
      child: Container(
        width: 750,
        height: isMobile ? MediaQuery.of(context).size.height * 0.85 : 600,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _metaBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bolt_rounded, color: _metaBlue, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta Ads Automation Rules',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Auto-dispatch WhatsApp templates and launch chatbots for FB & IG leads',
                        style: TextStyle(fontSize: 11, color: _textMuted),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openCreateOrEditRuleModal(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(isMobile ? 'Add' : 'Add Rule'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _textMuted),
                ),
              ],
            ),
            const Divider(height: 24, color: _borderColor),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _triggers.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          itemCount: _triggers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _buildRuleItem(_triggers[i], isMobile),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No Automation Rules Configured',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a rule to instantly message leads when they submit a Meta Instant Form or initiate a CTWA conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openCreateOrEditRuleModal(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Create First Rule'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(Map<String, dynamic> trigger, bool isMobile) {
    final adType = trigger['adType']?.toString() ?? 'any';
    final isInstantForm = adType == 'instant_form';
    final formName = trigger['formName']?.toString();
    final templateName = trigger['templateName']?.toString();
    final chatbotId = trigger['chatbotId']?.toString();
    final isActive = trigger['isActive'] == true;

    final bot = _chatbots.firstWhere((b) => b['_id'] == chatbotId, orElse: () => {});
    final botName = bot['name']?.toString() ?? (chatbotId != null && chatbotId.isNotEmpty ? 'Linked Bot' : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isInstantForm ? _metaBlue : AppTheme.primaryColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isInstantForm ? Icons.assignment_outlined : Icons.touch_app_outlined,
              size: 20,
              color: isInstantForm ? _metaBlue : AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Text(
                        isInstantForm ? 'Instant Form' : (adType == 'ctwa' ? 'Click-to-WhatsApp' : 'All Meta Ads'),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textDark),
                      ),
                    ),
                    if (formName != null && formName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Form: $formName',
                          style: const TextStyle(fontSize: 11, color: _textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    if (templateName != null && templateName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.send_rounded, size: 12, color: AppTheme.secondaryColor),
                          const SizedBox(width: 4),
                          Text('Template: $templateName', style: const TextStyle(fontSize: 12, color: _textDark, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    if (botName != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy_outlined, size: 12, color: _metaBlue),
                          const SizedBox(width: 4),
                          Text('Bot: $botName', style: const TextStyle(fontSize: 12, color: _textMuted)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: (_) => _toggleTrigger(trigger),
            activeThumbColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          IconButton(
            onPressed: () => _openCreateOrEditRuleModal(existing: trigger),
            icon: const Icon(Icons.edit_outlined, size: 18, color: _textMuted),
            tooltip: 'Edit Rule',
          ),
          IconButton(
            onPressed: () => _deleteTrigger(trigger['_id']),
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
            tooltip: 'Delete Rule',
          ),
        ],
      ),
    );
  }
}

class _MetaRuleEditorModal extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> forms;
  final List<Map<String, dynamic>> templates;
  final List<Map<String, dynamic>> chatbots;
  final VoidCallback onSaved;

  const _MetaRuleEditorModal({
    this.existing,
    required this.forms,
    required this.templates,
    required this.chatbots,
    required this.onSaved,
  });

  @override
  State<_MetaRuleEditorModal> createState() => _MetaRuleEditorModalState();
}

class _MetaRuleEditorModalState extends State<_MetaRuleEditorModal> {
  final Dio _dio = getIt<Dio>();
  final _formKey = GlobalKey<FormState>();

  late String _adType; // 'instant_form' | 'ctwa' | 'any'
  String? _selectedFormId;
  String? _selectedTemplateName;
  String? _selectedTemplateLanguage;
  String? _selectedChatbotId;
  bool _requireConsent = false;
  int _cooldownDays = 7;
  bool _saving = false;

  Map<String, String> _variableMapping = {};
  int _varCount = 0;

  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  
  static const List<Map<String, String>> _leadFields = [
    {'value': 'name', 'label': 'Name'},
    {'value': 'mobileNumber', 'label': 'Mobile Number'},
    {'value': 'email', 'label': 'Email'},
    {'value': 'companyName', 'label': 'Company Name'},
    {'value': 'formName', 'label': 'Form Name'},
    {'value': 'adName', 'label': 'Ad Name'},
    {'value': 'campaignName', 'label': 'Campaign Name'},
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _adType = e?['adType']?.toString() ?? 'instant_form';
    _selectedFormId = e?['formId']?.toString();
    if (_selectedFormId != null && _selectedFormId!.isEmpty) _selectedFormId = null;

    _selectedTemplateName = e?['templateName']?.toString();
    _selectedTemplateLanguage = e?['templateLanguage']?.toString() ?? 'en_US';
    _selectedChatbotId = e?['chatbotId']?.toString();
    if (_selectedChatbotId != null && _selectedChatbotId!.isEmpty) _selectedChatbotId = null;

    _requireConsent = e?['requireConsent'] == true;
    _cooldownDays = (e?['cooldownDays'] as num?)?.toInt() ?? 7;

    if (e?['variableMapping'] != null && e!['variableMapping'] is Map) {
      _variableMapping = Map<String, String>.from(
        (e['variableMapping'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }

    _updateVarCount();
  }

  void _updateVarCount() {
    if (_selectedTemplateName == null) {
      _varCount = 0;
      return;
    }
    final tmpl = widget.templates.firstWhere(
      (t) => t['name'] == _selectedTemplateName,
      orElse: () => {'varCount': 0},
    );
    _varCount = (tmpl['varCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    String? formName;
    if (_selectedFormId != null) {
      final f = widget.forms.firstWhere((x) => x['formId'] == _selectedFormId, orElse: () => {});
      formName = f['name']?.toString();
    }

    final payload = <String, dynamic>{
      'source': 'meta_ads',
      'adType': _adType,
      'formId': _selectedFormId ?? '',
      'formName': formName ?? '',
      'action': _adType == 'ctwa' && (_selectedTemplateName == null || _selectedTemplateName!.isEmpty) ? 'start_chatbot' : 'send_template',
      'templateName': _selectedTemplateName ?? '',
      'templateLanguage': _selectedTemplateLanguage ?? 'en_US',
      'chatbotId': _selectedChatbotId ?? '',
      'variableMapping': _variableMapping,
      'cooldownDays': _cooldownDays,
      'requireConsent': _requireConsent,
      'isActive': true,
    };

    try {
      if (widget.existing != null) {
        await _dio.put('/api/leads/triggers/${widget.existing!['_id']}', data: payload);
      } else {
        await _dio.post('/api/leads/triggers', data: payload);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save rule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 40, vertical: 24),
      child: Container(
        width: 600,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existing != null ? 'Edit Automation Rule' : 'New Automation Rule',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textDark),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _textMuted),
                    ),
                  ],
                ),
                const Divider(height: 20, color: _borderColor),
                const SizedBox(height: 6),

                // Ad Type Selector
                const Text('Triggering Ad Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'instant_form', label: Text('Instant Forms', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'ctwa', label: Text('Click-to-WhatsApp', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'any', label: Text('Any Ad', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_adType},
                  onSelectionChanged: (set) => setState(() => _adType = set.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.secondaryColor.withValues(alpha: 0.12);
                      }
                      return Colors.white;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.secondaryColor;
                      }
                      return _textMuted;
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // Form selector (only for instant forms)
                if (_adType != 'ctwa') ...[
                  const Text('Apply to Instant Form', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedFormId,
                    decoration: _inputDecoration('All Instant Forms (Default)'),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: _textDark, fontSize: 13),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Instant Forms')),
                      ...widget.forms.map((f) => DropdownMenuItem(
                            value: f['formId']?.toString(),
                            child: Text(f['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedFormId = v),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Template Selector
                const Text('Auto-Send WhatsApp Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedTemplateName,
                  decoration: _inputDecoration('Select an Approved Template'),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: _textDark, fontSize: 13),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None (Skip automated greeting)')),
                    ...widget.templates.map((t) => DropdownMenuItem(
                          value: t['name']?.toString(),
                          child: Text('${t['name']} (${t['language']})', overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedTemplateName = v;
                      final tmpl = widget.templates.firstWhere((t) => t['name'] == v, orElse: () => {});
                      _selectedTemplateLanguage = tmpl['language']?.toString() ?? 'en_US';
                      _updateVarCount();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Variable Mapping Fields
                if (_varCount > 0) ...[
                  const Text('Template Variable Mapping', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      children: List.generate(_varCount, (i) {
                        final varKey = '{{${i + 1}}}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(varKey, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _variableMapping[varKey],
                                  decoration: _inputDecoration('Map from Lead field'),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(color: _textDark, fontSize: 13),
                                  items: _leadFields
                                      .map((f) => DropdownMenuItem(value: f['value'], child: Text(f['label']!)))
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      if (v != null) {
                                        _variableMapping[varKey] = v;
                                      } else {
                                        _variableMapping.remove(varKey);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Follow-up Chatbot Selector
                const Text('Connect Follow-Up Chatbot (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedChatbotId,
                  decoration: _inputDecoration('Select Chatbot flow'),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: _textDark, fontSize: 13),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No chatbot (Live agents handle reply)')),
                    ...widget.chatbots.map((b) => DropdownMenuItem(
                          value: b['_id']?.toString(),
                          child: Text(b['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedChatbotId = v),
                ),
                const SizedBox(height: 16),

                // Cooldown Setting
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cooldown Period (Days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
                          Text('Prevents repeated spam messages to the same lead within N days', style: TextStyle(fontSize: 11, color: _textMuted)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: _cooldownDays.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: _textDark),
                        decoration: _inputDecoration('7'),
                        onChanged: (v) => _cooldownDays = int.tryParse(v) ?? 7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: _textMuted)),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(widget.existing != null ? 'Save Changes' : 'Create Rule'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
    );
  }
}

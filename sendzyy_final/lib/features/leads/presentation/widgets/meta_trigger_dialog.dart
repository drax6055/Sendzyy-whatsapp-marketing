import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';

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
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 750,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFF1877F2), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta Ads Automation Rules',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Auto-dispatch WhatsApp templates and launch chatbots for FB & IG leads',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openCreateOrEditRuleModal(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Rule'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const Divider(height: 32, color: Colors.white12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _triggers.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          itemCount: _triggers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _buildRuleItem(_triggers[i]),
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
          Icon(Icons.bolt_outlined, size: 56, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          const Text(
            'No Meta Ads Automation Rules Configured',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a rule to instantly greet Instant Form and Click-to-WhatsApp leads on WhatsApp.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _openCreateOrEditRuleModal(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Create First Rule'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1877F2),
              side: const BorderSide(color: Color(0xFF1877F2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(Map<String, dynamic> trigger) {
    final adType = trigger['adType']?.toString() ?? 'any';
    final isInstantForm = adType == 'instant_form';
    final formName = trigger['formName']?.toString();
    final templateName = trigger['templateName']?.toString();
    final chatbotId = trigger['chatbotId']?.toString();
    final isActive = trigger['isActive'] == true;

    final bot = _chatbots.firstWhere((b) => b['_id'] == chatbotId, orElse: () => {});
    final botName = bot['name']?.toString() ?? (chatbotId != null && chatbotId.isNotEmpty ? 'Linked Bot' : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isInstantForm ? const Color(0xFF1877F2) : const Color(0xFF25D366)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isInstantForm ? Icons.assignment_outlined : Icons.touch_app_outlined,
              size: 20,
              color: isInstantForm ? const Color(0xFF1877F2) : const Color(0xFF25D366),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isInstantForm ? 'Instant Form' : (adType == 'ctwa' ? 'Click-to-WhatsApp' : 'All Meta Ads'),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ),
                    if (formName != null && formName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Form: $formName',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (templateName != null && templateName.isNotEmpty) ...[
                      const Icon(Icons.send_rounded, size: 13, color: Colors.greenAccent),
                      const SizedBox(width: 4),
                      Text('Template: $templateName', style: const TextStyle(fontSize: 13, color: Colors.white)),
                    ],
                    if (botName != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.smart_toy_outlined, size: 13, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text('Follow-up Bot: $botName', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: (_) => _toggleTrigger(trigger),
            activeColor: const Color(0xFF1877F2),
          ),
          IconButton(
            onPressed: () => _openCreateOrEditRuleModal(existing: trigger),
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white60),
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

    if (e?['variableMapping'] != null) {
      _variableMapping = Map<String, String>.from(e!['variableMapping'] as Map);
    }

    if (_selectedTemplateName != null) {
      _updateTemplateVarCount(_selectedTemplateName!);
    }
  }

  void _updateTemplateVarCount(String tplName) {
    final tpl = widget.templates.firstWhere((t) => t['name'] == tplName, orElse: () => {});
    setState(() {
      _varCount = (tpl['varCount'] as num?)?.toInt() ?? 0;
      _selectedTemplateLanguage = tpl['language']?.toString() ?? 'en_US';

      // Auto-assign default mappings if empty
      for (int i = 1; i <= _varCount; i++) {
        final k = i.toString();
        if (!_variableMapping.containsKey(k)) {
          _variableMapping[k] = i == 1 ? 'name' : (i == 2 ? 'formName' : 'mobileNumber');
        }
      }
    });
  }

  Future<void> _saveRule() async {
    if (_adType == 'instant_form' && (_selectedTemplateName == null || _selectedTemplateName!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an approved WhatsApp template for Instant Forms.')),
      );
      return;
    }

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
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Ad Type Segmented Selector
                const Text('Trigger Scope', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildScopeChip('Instant Forms', 'instant_form'),
                    const SizedBox(width: 8),
                    _buildScopeChip('Click-to-WhatsApp (CTWA)', 'ctwa'),
                    const SizedBox(width: 8),
                    _buildScopeChip('All Meta Ads', 'any'),
                  ],
                ),
                const SizedBox(height: 16),
                // Form dropdown (if instant_form)
                if (_adType == 'instant_form') ...[
                  const Text('Select Instant Form (Optional)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedFormId,
                    dropdownColor: AppTheme.cardColor,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDecoration('All Forms (Catch-all)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Forms (Catch-all)')),
                      ...widget.forms.map((f) => DropdownMenuItem<String?>(
                            value: f['formId']?.toString(),
                            child: Text(f['name']?.toString() ?? f['formId'].toString()),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedFormId = val),
                  ),
                  const SizedBox(height: 16),
                ],
                // 24-hr Policy Notice
                if (_adType == 'instant_form') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Meta Policy: Instant Form leads require an approved WhatsApp Template message first. If a chatbot is selected below, it will trigger automatically as soon as the lead replies.',
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Template dropdown
                const Text('WhatsApp Greeting Template', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTemplateName,
                  dropdownColor: AppTheme.cardColor,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('Select an approved template'),
                  items: widget.templates.map((t) {
                    final name = t['name']?.toString() ?? '';
                    final vars = t['varCount'] ?? 0;
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text('$name ($vars variables)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _selectedTemplateName = val;
                      _updateTemplateVarCount(val);
                    }
                  },
                ),
                // Variable Mappings
                if (_varCount > 0) ...[
                  const SizedBox(height: 16),
                  const Text('Template Variable Mappings', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (int i = 1; i <= _varCount; i++) _buildVarMappingRow(i.toString()),
                ],
                const SizedBox(height: 16),
                // Follow-up Chatbot
                const Text('Follow-up Chatbot (Optional)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedChatbotId,
                  dropdownColor: AppTheme.cardColor,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('None (Template only)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('None (Template only)')),
                    ...widget.chatbots.map((b) => DropdownMenuItem<String?>(
                          value: b['_id']?.toString(),
                          child: Text(b['name']?.toString() ?? 'Chatbot'),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedChatbotId = val),
                ),
                const SizedBox(height: 16),
                // Cooldown & Consent
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cooldown (Days)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: _cooldownDays.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration('7'),
                            onChanged: (val) => _cooldownDays = int.tryParse(val) ?? 7,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Require Opt-in Consent', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        value: _requireConsent,
                        activeColor: const Color(0xFF1877F2),
                        onChanged: (val) => setState(() => _requireConsent = val ?? false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _saveRule,
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                      child: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Rule'),
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

  Widget _buildScopeChip(String label, String value) {
    final selected = _adType == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white60)),
      selected: selected,
      selectedColor: const Color(0xFF1877F2),
      backgroundColor: Colors.white10,
      onSelected: (_) => setState(() => _adType = value),
    );
  }

  Widget _buildVarMappingRow(String varNum) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
            child: Text('{{$varNum}}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _variableMapping[varNum] ?? 'name',
              dropdownColor: AppTheme.cardColor,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: _inputDecoration('Field'),
              items: _leadFields.map((f) => DropdownMenuItem<String>(
                    value: f['value'],
                    child: Text(f['label']!),
                  )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _variableMapping[varNum] = val);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1877F2))),
    );
  }
}

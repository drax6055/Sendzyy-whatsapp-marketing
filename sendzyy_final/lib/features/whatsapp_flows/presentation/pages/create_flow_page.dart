import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/snackbar_utils.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/meta_flow_template.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/whatsapp_flow_model.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/repositories/whatsapp_flow_repository.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/presentation/widgets/flow_mobile_preview.dart';

class CreateFlowPage extends StatefulWidget {
  final WhatsAppFlowRepository repository;
  final VoidCallback? onFlowCreated;
  final List<WhatsAppFlowModel>? existingFlows;

  const CreateFlowPage({
    super.key,
    required this.repository,
    this.onFlowCreated,
    this.existingFlows,
  });

  @override
  State<CreateFlowPage> createState() => _CreateFlowPageState();
}

class _CreateFlowPageState extends State<CreateFlowPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _headerController = TextEditingController();
  final _bodyController = TextEditingController();
  final _footerController = TextEditingController(text: 'Powered by Sendzyy');
  final _ctaController = TextEditingController(text: 'Open Form');

  String _selectedCategory = 'LEAD_GENERATION';
  bool _isPublishing = false;

  MetaFlowEndpointType _selectedEndpointTab = MetaFlowEndpointType.withoutEndpoint;
  String _selectedTemplateId = 'default';

  final List<FlowFormField> _fields = [];

  @override
  void initState() {
    super.initState();
    final initialTemplate = kAllMetaFlowTemplates.firstWhere(
      (t) => t.id == 'default',
      orElse: () => kAllMetaFlowTemplates.first,
    );
    _applyTemplateData(initialTemplate, notify: false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headerController.dispose();
    _bodyController.dispose();
    _footerController.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  void _applyTemplateData(MetaFlowTemplate template, {bool notify = true}) {
    _selectedTemplateId = template.id;
    _selectedEndpointTab = template.endpointType;

    // Auto-generate unique name if a flow with this name already exists
    String computedTitle = template.flowTitle;
    final existingNames = (widget.existingFlows ?? [])
        .map((f) => f.name.toLowerCase().trim())
        .toSet();
    if (existingNames.contains(computedTitle.toLowerCase().trim())) {
      int counter = 2;
      while (existingNames.contains('$computedTitle ($counter)'.toLowerCase().trim())) {
        counter++;
      }
      computedTitle = '$computedTitle ($counter)';
    }

    _nameController.text = computedTitle;
    _bodyController.text = template.bodyText;
    _ctaController.text = template.ctaText;
    _selectedCategory = template.category;
    _fields.clear();
    _fields.addAll(template.cloneFields());

    if (notify && mounted) {
      SnackbarUtils.showSuccess(context, 'Applied Meta template: ${template.title}');
    }
  }

  void _selectMetaTemplate(MetaFlowTemplate template) {
    setState(() {
      _applyTemplateData(template, notify: true);
    });
  }

  void _addNewField() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Field Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _fieldTypeChip(ctx, 'Short Text', 'text', Icons.text_fields_rounded),
                    _fieldTypeChip(ctx, 'Email Address', 'email', Icons.email_outlined),
                    _fieldTypeChip(ctx, 'Phone Number', 'phone', Icons.phone_outlined),
                    _fieldTypeChip(ctx, 'Paragraph / Notes', 'textarea', Icons.notes_rounded),
                    _fieldTypeChip(ctx, 'Dropdown Menu', 'dropdown', Icons.arrow_drop_down_circle_outlined),
                    _fieldTypeChip(ctx, 'Single Choice (Radio)', 'radio', Icons.radio_button_checked),
                    _fieldTypeChip(ctx, 'Multiple Choice (Checkbox)', 'checkbox', Icons.check_box_outlined),
                    _fieldTypeChip(ctx, 'Date Picker', 'date', Icons.calendar_today_rounded),
                    _fieldTypeChip(ctx, 'Terms & Opt-in Consent', 'opt_in', Icons.verified_user_outlined),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fieldTypeChip(BuildContext ctx, String label, String type, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppTheme.primaryColor),
      label: Text(label),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () {
        Navigator.pop(ctx);
        setState(() {
          final count = _fields.length + 1;
          _fields.add(FlowFormField(
            name: 'field_$count',
            label: label,
            type: type,
            required: type != 'textarea',
            options: (type == 'dropdown' || type == 'radio' || type == 'checkbox')
                ? ['Option 1', 'Option 2', 'Option 3']
                : [],
          ));
        });
      },
    );
  }

  void _showTemplateInfoDialog(MetaFlowTemplate template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(template.icon, color: const Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                template.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              template.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Category: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          template.category,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pre-configured Questions (${template.fields.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  ...template.fields.map(
                    (f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF25D366)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${f.label} (${f.type})',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _selectMetaTemplate(template);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply Template'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveAndPublish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fields.isEmpty) {
      SnackbarUtils.showError(context, 'Please add at least one field to your Flow');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final created = await widget.repository.createFlow(
        name: _nameController.text.trim(),
        categories: [_selectedCategory],
        fields: _fields,
        headerText: _headerController.text.trim(),
        bodyText: _bodyController.text.trim(),
        footerText: _footerController.text.trim(),
        ctaText: _ctaController.text.trim(),
      );

      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Flow "${created.name}" created & published on WhatsApp!');
      widget.onFlowCreated?.call();
      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Failed to publish Flow: $e');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create WhatsApp Flow', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _isPublishing ? null : _handleSaveAndPublish,
              icon: _isPublishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rocket_launch_rounded, size: 18),
              label: Text(_isPublishing ? 'Publishing...' : 'Save & Publish to Meta'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    final screenHeight = MediaQuery.of(context).size.height;
    // Compute responsive preview dimensions so the entire phone frame always fits nicely
    final previewHeight = (screenHeight - 130).clamp(480.0, 600.0);
    final previewWidth = (previewHeight * 0.52).clamp(270.0, 310.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Builder Form & Meta Template Selector
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: _buildFormContent(),
          ),
        ),
        // Divider
        const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
        // Right Column: Mobile Screen Preview (Sticky in Viewport)
        Expanded(
          flex: 4,
          child: Container(
            height: screenHeight - 64, // Exact viewport height below AppBar
            color: const Color(0xFFF8FAFC),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      const Text(
                        'Live WhatsApp Preview',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Interactive',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FlowMobilePreview(
                        width: previewWidth,
                        height: previewHeight,
                        title: _nameController.text.isEmpty ? 'WhatsApp Flow' : _nameController.text,
                        description: _bodyController.text,
                        fields: _fields,
                        submitButtonText: _ctaController.text.isEmpty ? 'Submit' : _ctaController.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(icon: Icon(Icons.edit_note_rounded), text: 'Form Builder'),
              Tab(icon: Icon(Icons.phone_android_rounded), text: 'WhatsApp Preview'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildFormContent(),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: FlowMobilePreview(
                      title: _nameController.text.isEmpty ? 'WhatsApp Flow' : _nameController.text,
                      description: _bodyController.text,
                      fields: _fields,
                      submitButtonText: _ctaController.text.isEmpty ? 'Submit' : _ctaController.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF25D366), width: 1.5),
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta WhatsApp Flow Templates Section (Without endpoint / With endpoint)
          _buildMetaTemplateSection(),
          const SizedBox(height: 24),

          // Flow Details Section
          const Text('Flow Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: _buildInputDecoration(
              labelText: 'Flow Title *',
              hintText: 'e.g. Consultation Booking Form',
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('category_dropdown_$_selectedCategory'),
                  initialValue: _selectedCategory,
                  decoration: _buildInputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'LEAD_GENERATION', child: Text('Lead Generation')),
                    DropdownMenuItem(value: 'APPOINTMENT_BOOKING', child: Text('Appointment Booking')),
                    DropdownMenuItem(value: 'CUSTOMER_SUPPORT', child: Text('Customer Support')),
                    DropdownMenuItem(value: 'SURVEY', child: Text('Survey / Feedback')),
                    DropdownMenuItem(value: 'SIGN_UP', child: Text('Sign Up / Registration')),
                    DropdownMenuItem(value: 'SIGN_IN', child: Text('Sign In / Authentication')),
                    DropdownMenuItem(value: 'CONTACT_US', child: Text('Contact Us')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _ctaController,
                  onChanged: (_) => setState(() {}),
                  decoration: _buildInputDecoration(
                    labelText: 'Button Label (CTA)',
                    hintText: 'e.g. Open Form / Book Now',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bodyController,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: _buildInputDecoration(
              labelText: 'Introduction / Instruction Text',
              hintText: 'e.g. Please fill out your details below:',
            ),
          ),
          const SizedBox(height: 28),

          // Questions & Fields Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Form Questions & Fields', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${_fields.length} questions in this flow (drag handle to reorder)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addNewField,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Field'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reorderable list with default drag handles disabled (fixing duplicate handles on web/desktop)
          ReorderableListView.builder(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _fields.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _fields.removeAt(oldIndex);
                _fields.insert(newIndex, item);
              });
            },
            itemBuilder: (ctx, index) {
              final field = _fields[index];
              return _buildFieldEditorCard(field, index);
            },
          ),
        ],
      ),
    );
  }

  /// Meta Official Flow Templates Selector (Without endpoint / With endpoint)
  Widget _buildMetaTemplateSection() {
    final templates = _selectedEndpointTab == MetaFlowEndpointType.withoutEndpoint
        ? kMetaTemplatesWithoutEndpoint
        : kMetaTemplatesWithEndpoint;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Template',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Meta WhatsApp Flows',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),
          ),

          // Tabs: [ Without endpoint ] | [ With endpoint ]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildEndpointTabButton(
                  title: 'Without endpoint',
                  type: MetaFlowEndpointType.withoutEndpoint,
                ),
                const SizedBox(width: 8),
                _buildEndpointTabButton(
                  title: 'With endpoint',
                  type: MetaFlowEndpointType.withEndpoint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Radio Selection List for Templates
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),
            itemBuilder: (ctx, index) {
              final template = templates[index];
              final isSelected = _selectedTemplateId == template.id;
              return _buildTemplateListItem(template, isSelected);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEndpointTabButton({
    required String title,
    required MetaFlowEndpointType type,
  }) {
    final isSelected = _selectedEndpointTab == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedEndpointTab = type;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFBAE6FD) : Colors.transparent,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateListItem(MetaFlowTemplate template, bool isSelected) {
    return InkWell(
      onTap: () => _selectMetaTemplate(template),
      child: Container(
        color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular Radio Button (Styled like Meta's screenshot)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 14),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                    width: isSelected ? 6 : 1.5,
                  ),
                  color: Colors.white,
                ),
              ),
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          template.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${template.fields.length} fields',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (template.hasEndpointInfo) ...[
                    Row(
                      children: [
                        Text(
                          'Endpoint template available. ',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        InkWell(
                          onTap: () => _showTemplateInfoDialog(template),
                          child: const Text(
                            'More info',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    template.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFieldTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'email':
        return const Color(0xFF0891B2);
      case 'phone':
        return const Color(0xFF0284C7);
      case 'textarea':
        return const Color(0xFFD97706);
      case 'dropdown':
        return const Color(0xFF9333EA);
      case 'radio':
        return const Color(0xFF059669);
      case 'checkbox':
        return const Color(0xFF0D9488);
      case 'date':
        return const Color(0xFFE11D48);
      case 'opt_in':
        return const Color(0xFF7C3AED);
      case 'text':
      default:
        return const Color(0xFF2563EB);
    }
  }

  Widget _buildFieldEditorCard(FlowFormField field, int index) {
    final typeColor = _getFieldTypeColor(field.type);

    return Card(
      key: ValueKey('field_card_${field.name}_$index'),
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Top Row: Drag listener, Badge, Index, Required toggle, Delete button
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: 'Drag to reorder question',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.drag_indicator_rounded, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    field.type.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${index + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Text('Required', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569))),
                    const SizedBox(width: 4),
                    Switch(
                      value: field.required,
                      activeThumbColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setState(() => field.required = val);
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Delete field',
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                      onPressed: () {
                        setState(() => _fields.removeAt(index));
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question / Field Label
            TextFormField(
              key: ValueKey('field_label_${field.name}_$index'),
              initialValue: field.label,
              onChanged: (val) {
                field.label = val;
                setState(() {});
              },
              decoration: _buildInputDecoration(
                labelText: 'Question / Field Label',
                hintText: 'e.g. Full Name, Email, Preferred Date...',
              ),
            ),

            // Options Input for dropdown / radio / checkbox
            if (field.type == 'dropdown' || field.type == 'radio' || field.type == 'checkbox') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Answer Choices (one per line):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${field.options.length} options',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: ValueKey('field_options_${field.name}_$index'),
                initialValue: field.options.join('\n'),
                maxLines: 4,
                onChanged: (val) {
                  field.options = val
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  setState(() {});
                },
                decoration: _buildInputDecoration(
                  labelText: 'Choices',
                  hintText: 'Option 1\nOption 2\nOption 3',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

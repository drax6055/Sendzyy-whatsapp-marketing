import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/snackbar_utils.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/whatsapp_flow_model.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/repositories/whatsapp_flow_repository.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/presentation/widgets/flow_mobile_preview.dart';

class CreateFlowPage extends StatefulWidget {
  final WhatsAppFlowRepository repository;
  final VoidCallback? onFlowCreated;

  const CreateFlowPage({
    super.key,
    required this.repository,
    this.onFlowCreated,
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

  final List<FlowFormField> _fields = [
    FlowFormField(name: 'full_name', label: 'Full Name', type: 'text', required: true),
    FlowFormField(name: 'email', label: 'Email Address', type: 'email', required: true),
    FlowFormField(name: 'phone', label: 'Phone Number', type: 'phone', required: false),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _headerController.dispose();
    _bodyController.dispose();
    _footerController.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  void _applyTemplate(String templateName) {
    setState(() {
      if (templateName == 'lead') {
        _nameController.text = 'Lead Capture Form';
        _bodyController.text = 'Please provide your contact details so our team can reach out:';
        _ctaController.text = 'Get in Touch';
        _selectedCategory = 'LEAD_GENERATION';
        _fields.clear();
        _fields.addAll([
          FlowFormField(name: 'full_name', label: 'Full Name', type: 'text', required: true),
          FlowFormField(name: 'email', label: 'Work Email', type: 'email', required: true),
          FlowFormField(name: 'phone', label: 'Phone Number', type: 'phone', required: true),
          FlowFormField(name: 'company', label: 'Company Name', type: 'text', required: false),
          FlowFormField(
            name: 'interest',
            label: 'Service of Interest',
            type: 'dropdown',
            required: true,
            options: ['Marketing Automation', 'WhatsApp API', 'CRM Integration', 'Custom Bot'],
          ),
        ]);
      } else if (templateName == 'appointment') {
        _nameController.text = 'Book Appointment';
        _bodyController.text = 'Select your preferred consultation date and slot:';
        _ctaController.text = 'Book Now';
        _selectedCategory = 'APPOINTMENT_BOOKING';
        _fields.clear();
        _fields.addAll([
          FlowFormField(name: 'client_name', label: 'Your Name', type: 'text', required: true),
          FlowFormField(name: 'phone_num', label: 'WhatsApp Number', type: 'phone', required: true),
          FlowFormField(
            name: 'service_type',
            label: 'Appointment Type',
            type: 'radio',
            required: true,
            options: ['Online Consultation', 'In-Person Meeting', 'Product Demo'],
          ),
          FlowFormField(name: 'pref_date', label: 'Preferred Date', type: 'date', required: true),
          FlowFormField(name: 'notes', label: 'Special Requests / Notes', type: 'textarea', required: false),
        ]);
      } else if (templateName == 'feedback') {
        _nameController.text = 'Customer Feedback';
        _bodyController.text = 'Help us improve by rating your recent experience:';
        _ctaController.text = 'Submit Review';
        _selectedCategory = 'SURVEY';
        _fields.clear();
        _fields.addAll([
          FlowFormField(
            name: 'rating',
            label: 'How was your experience?',
            type: 'radio',
            required: true,
            options: ['⭐⭐⭐⭐⭐ Excellent', '⭐⭐⭐⭐ Good', '⭐⭐⭐ Average', '⭐ Needs Improvement'],
          ),
          FlowFormField(name: 'comments', label: 'Feedback / Suggestions', type: 'textarea', required: false),
          FlowFormField(name: 'recommend', label: 'Would you recommend us?', type: 'dropdown', required: true, options: ['Definitely', 'Maybe', 'No']),
        ]);
      }
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
                    _fieldTypeChip(ctx, 'Date Picker', 'date', Icons.calendar_today_rounded),
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
            required: true,
            options: (type == 'dropdown' || type == 'radio')
                ? ['Option 1', 'Option 2', 'Option 3']
                : [],
          ));
        });
      },
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Builder Form
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildFormContent(),
          ),
        ),
        // Divider
        const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
        // Right Column: Mobile Screen Preview
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FlowMobilePreview(
                  title: _nameController.text.isEmpty ? 'WhatsApp Flow' : _nameController.text,
                  description: _bodyController.text,
                  fields: _fields,
                  submitButtonText: 'Submit',
                ),
              ),
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
                      submitButtonText: 'Submit',
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

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Templates Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor.withValues(alpha: 0.08), Colors.blue.withValues(alpha: 0.04)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Quick Start Templates',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _applyTemplate('lead'),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: const Text('Lead Generation'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _applyTemplate('appointment'),
                      icon: const Icon(Icons.event_available_rounded, size: 16),
                      label: const Text('Book Appointment'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _applyTemplate('feedback'),
                      icon: const Icon(Icons.rate_review_outlined, size: 16),
                      label: const Text('Customer Feedback'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Flow Details Section
          const Text('Flow Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Flow Title *',
              hintText: 'e.g. Consultation Booking Form',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'LEAD_GENERATION', child: Text('Lead Generation')),
                    DropdownMenuItem(value: 'APPOINTMENT_BOOKING', child: Text('Appointment Booking')),
                    DropdownMenuItem(value: 'CUSTOMER_SUPPORT', child: Text('Customer Support')),
                    DropdownMenuItem(value: 'SURVEY', child: Text('Survey / Feedback')),
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
                  decoration: InputDecoration(
                    labelText: 'Button Label (CTA)',
                    hintText: 'e.g. Open Form / Book Now',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            decoration: InputDecoration(
              labelText: 'Introduction / Instruction Text',
              hintText: 'e.g. Please fill out your details below:',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 28),

          // Questions & Fields Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Form Questions & Fields', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _addNewField,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Field'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ReorderableListView.builder(
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

  Widget _buildFieldEditorCard(FlowFormField field, int index) {
    return Card(
      key: ValueKey(field.name + index.toString()),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    field.type.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Text('Required', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: field.required,
                      activeThumbColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setState(() => field.required = val);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() => _fields.removeAt(index));
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: field.label,
              onChanged: (val) {
                field.label = val;
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Question / Field Label',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (field.type == 'dropdown' || field.type == 'radio') ...[
              const SizedBox(height: 12),
              const Text('Options (one per line):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextFormField(
                initialValue: field.options.join('\n'),
                maxLines: 3,
                onChanged: (val) {
                  field.options = val
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Option 1\nOption 2\nOption 3',
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

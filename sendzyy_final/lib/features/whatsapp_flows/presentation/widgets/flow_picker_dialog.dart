import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/whatsapp_flow_model.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/repositories/whatsapp_flow_repository.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/presentation/pages/create_flow_page.dart';

class FlowPickerDialog extends StatefulWidget {
  final String? contactId;
  final Function(WhatsAppFlowModel selectedFlow, String bodyText, String ctaText)? onSendFlow;

  const FlowPickerDialog({
    super.key,
    this.contactId,
    this.onSendFlow,
  });

  static Future<WhatsAppFlowModel?> show(
    BuildContext context, {
    String? contactId,
    Function(WhatsAppFlowModel selectedFlow, String bodyText, String ctaText)? onSendFlow,
  }) {
    return showDialog<WhatsAppFlowModel>(
      context: context,
      builder: (ctx) => FlowPickerDialog(
        contactId: contactId,
        onSendFlow: onSendFlow,
      ),
    );
  }

  @override
  State<FlowPickerDialog> createState() => _FlowPickerDialogState();
}

class _FlowPickerDialogState extends State<FlowPickerDialog> {
  late final WhatsAppFlowRepository _repository;
  List<WhatsAppFlowModel> _flows = [];
  bool _loading = true;
  WhatsAppFlowModel? _selectedFlow;
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _ctaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = getIt<WhatsAppFlowRepository>();
    _loadFlows();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  Future<void> _loadFlows() async {
    setState(() => _loading = true);
    try {
      final flows = await _repository.getFlows();
      if (mounted) {
        setState(() {
          _flows = flows;
          _loading = false;
          if (_flows.isNotEmpty) {
            _selectFlow(_flows.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectFlow(WhatsAppFlowModel flow) {
    setState(() {
      _selectedFlow = flow;
      _bodyController.text = flow.bodyText.isNotEmpty
          ? flow.bodyText
          : 'Please complete the form below:';
      _ctaController.text = flow.ctaText.isNotEmpty ? flow.ctaText : 'Open Form';
    });
  }

  void _createNewFlow() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateFlowPage(
          repository: _repository,
        ),
      ),
    );
    if (created is WhatsAppFlowModel) {
      await _loadFlows();
      _selectFlow(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.schema_rounded, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Select WhatsApp Flow',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : _flows.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.dynamic_form_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No WhatsApp Flows Found',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create a new flow to send interactive forms directly in chat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _createNewFlow,
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Flow'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Choose Flow:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            TextButton.icon(
                              onPressed: _createNewFlow,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('+ New Flow', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<WhatsAppFlowModel>(
                          value: _selectedFlow,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          items: _flows.map((f) {
                            return DropdownMenuItem(
                              value: f,
                              child: Row(
                                children: [
                                  Expanded(child: Text(f.name, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: f.status.toUpperCase() == 'PUBLISHED'
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      f.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: f.status.toUpperCase() == 'PUBLISHED'
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) _selectFlow(val);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _bodyController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Message Body / Text',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _ctaController,
                          decoration: InputDecoration(
                            labelText: 'CTA Button Text',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_flows.isNotEmpty && _selectedFlow != null)
          ElevatedButton.icon(
            onPressed: () {
              final flow = _selectedFlow!;
              final body = _bodyController.text.trim();
              final cta = _ctaController.text.trim();

              if (widget.onSendFlow != null) {
                widget.onSendFlow!(flow, body, cta);
              }
              Navigator.pop(context, flow);
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(widget.onSendFlow != null ? 'Send Flow' : 'Select Flow'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
      ],
    );
  }
}

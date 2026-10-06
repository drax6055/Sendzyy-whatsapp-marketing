import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/whatsapp_flow_model.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/repositories/whatsapp_flow_repository.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/presentation/pages/create_flow_page.dart';

class WhatsAppFlowNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const WhatsAppFlowNodeForm({
    super.key,
    required this.node,
    required this.onChanged,
  });

  @override
  State<WhatsAppFlowNodeForm> createState() => _WhatsAppFlowNodeFormState();
}

class _WhatsAppFlowNodeFormState extends State<WhatsAppFlowNodeForm> {
  late final WhatsAppFlowRepository _repository;
  List<WhatsAppFlowModel> _flows = [];
  bool _loading = true;

  late final TextEditingController _bodyController;
  late final TextEditingController _ctaController;
  String? _selectedFlowId;

  @override
  void initState() {
    super.initState();
    _repository = getIt<WhatsAppFlowRepository>();
    _selectedFlowId = widget.node.data['flowId']?.toString();
    _bodyController = TextEditingController(
      text: widget.node.data['bodyText']?.toString() ?? 'Please complete this form:',
    );
    _ctaController = TextEditingController(
      text: widget.node.data['ctaText']?.toString() ?? 'Open Form',
    );
    _loadFlows();
  }

  @override
  void didUpdateWidget(covariant WhatsAppFlowNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _selectedFlowId = widget.node.data['flowId']?.toString();
      _bodyController.text =
          widget.node.data['bodyText']?.toString() ?? 'Please complete this form:';
      _ctaController.text =
          widget.node.data['ctaText']?.toString() ?? 'Open Form';
    }
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
      final list = await _repository.getFlows();
      if (mounted) {
        setState(() {
          _flows = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _emitChange({String? flowId, String? flowName}) {
    widget.onChanged({
      'flowId': flowId ?? _selectedFlowId ?? '',
      'flowName': flowName ?? widget.node.data['flowName'] ?? '',
      'bodyText': _bodyController.text.trim(),
      'ctaText': _ctaController.text.trim(),
    });
  }

  void _openCreateFlow() async {
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
      setState(() {
        _selectedFlowId = created.flowId;
      });
      _emitChange(flowId: created.flowId, flowName: created.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.schema_rounded, color: Color(0xFF6366F1), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sends an interactive in-app WhatsApp Flow to the contact.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Connect Existing Flow or Create New
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select WhatsApp Flow',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            TextButton.icon(
              onPressed: _openCreateFlow,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Create New Flow', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (_flows.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No flows found. Click "+ Create New Flow" above to create your first flow.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            value: _flows.any((f) => f.flowId == _selectedFlowId) ? _selectedFlowId : null,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Choose from created flows...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _flows.map((f) {
              return DropdownMenuItem(
                value: f.flowId,
                child: Text(
                  '${f.name} (${f.status})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedFlowId = val);
                final flow = _flows.firstWhere((f) => f.flowId == val);
                _emitChange(flowId: flow.flowId, flowName: flow.name);
              }
            },
          ),
        const SizedBox(height: 16),

        // Message Body
        const Text(
          'Introduction Message Text',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _bodyController,
          maxLines: 2,
          onChanged: (_) => _emitChange(),
          decoration: InputDecoration(
            hintText: 'e.g. Please fill out your details:',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 14),

        // CTA Button Text
        const Text(
          'CTA Button Label',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _ctaController,
          onChanged: (_) => _emitChange(),
          decoration: InputDecoration(
            hintText: 'e.g. Open Form / Book Now',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

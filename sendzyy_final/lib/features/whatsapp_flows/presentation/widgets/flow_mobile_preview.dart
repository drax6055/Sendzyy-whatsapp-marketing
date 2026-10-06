import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/whatsapp_flow_model.dart';

class FlowMobilePreview extends StatelessWidget {
  final String title;
  final String description;
  final List<FlowFormField> fields;
  final String submitButtonText;

  const FlowMobilePreview({
    super.key,
    required this.title,
    required this.description,
    required this.fields,
    this.submitButtonText = 'Submit',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 600,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // WhatsApp Status Bar & Header
            Container(
              color: const Color(0xFF075E54),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? 'WhatsApp Flow' : title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Business Form',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),

            // Form Body
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) ...[
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (fields.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(Icons.format_shapes_rounded,
                                    size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'Add fields to preview\nyour WhatsApp screen',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      ...fields.map((field) => _buildPreviewField(field)),
                    ],
                  ),
                ),
              ),
            ),

            // Submit Button Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    submitButtonText.isEmpty ? 'Submit' : submitButtonText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewField(FlowFormField field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                field.label.isEmpty ? 'Field Label' : field.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (field.required)
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (field.type == 'dropdown') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    field.options.isNotEmpty ? field.options.first : 'Select option',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ] else if (field.type == 'radio') ...[
            Column(
              children: (field.options.isNotEmpty ? field.options : ['Option 1', 'Option 2'])
                  .take(3)
                  .map((opt) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_unchecked,
                                size: 16, color: Color(0xFF25D366)),
                            const SizedBox(width: 8),
                            Text(opt, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ] else if (field.type == 'date') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Select date (DD/MM/YYYY)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                field.type == 'email'
                    ? 'example@domain.com'
                    : field.type == 'phone'
                        ? '+1 234 567 8900'
                        : 'Enter value...',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

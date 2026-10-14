import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/whatsapp_flow_model.dart';

class FlowMobilePreview extends StatelessWidget {
  final String title;
  final String description;
  final List<FlowFormField> fields;
  final String submitButtonText;
  final double? width;
  final double? height;

  const FlowMobilePreview({
    super.key,
    required this.title,
    required this.description,
    required this.fields,
    this.submitButtonText = 'Submit',
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final previewWidth = width ?? 310.0;
    final previewHeight = height ?? 560.0;

    return Container(
      width: previewWidth,
      height: previewHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF1E293B), width: 7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // WhatsApp Flow Header & Status Bar
            Container(
              color: const Color(0xFF075E54),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: SafeArea(
                bottom: false,
                top: false,
                child: Column(
                  children: [
                    // Speaker / Camera Notch Pill
                    Center(
                      child: Container(
                        width: 44,
                        height: 3.5,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? 'WhatsApp Flow' : title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Business Form',
                                style: TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Form Body
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) ...[
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (fields.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(Icons.format_shapes_rounded,
                                    size: 36, color: Colors.grey.shade400),
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
                      // Extra bottom padding so last field is never occluded by Submit button
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Submit Button Footer
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.zero,
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(21),
                        ),
                      ),
                      child: Text(
                        submitButtonText.isEmpty ? 'Submit' : submitButtonText,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Home indicator bar
                  Center(
                    child: Container(
                      width: 72,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewField(FlowFormField field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  field.label.isEmpty ? 'Field Label' : field.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              if (field.required)
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 7),
          if (field.type == 'dropdown') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      field.options.isNotEmpty ? field.options.first : 'Select option',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 18),
                ],
              ),
            ),
          ] else if (field.type == 'radio') ...[
            Column(
              children: (field.options.isNotEmpty ? field.options : ['Option 1', 'Option 2'])
                  .take(4)
                  .map((opt) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_unchecked,
                                size: 15, color: Color(0xFF25D366)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(opt, style: const TextStyle(fontSize: 11.5))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ] else if (field.type == 'checkbox') ...[
            Column(
              children: (field.options.isNotEmpty ? field.options : ['Option 1', 'Option 2'])
                  .take(4)
                  .map((opt) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outline_blank_rounded,
                                size: 15, color: Color(0xFF25D366)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(opt, style: const TextStyle(fontSize: 11.5))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ] else if (field.type == 'textarea') ...[
            Container(
              width: double.infinity,
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                'Enter details / notes...',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              ),
            ),
          ] else if (field.type == 'opt_in') ...[
            Row(
              children: [
                const Icon(Icons.check_box_rounded, size: 16, color: Color(0xFF25D366)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.label.isEmpty ? 'I agree to the terms and privacy policy' : field.label,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ] else if (field.type == 'date') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('DD / MM / YYYY',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                field.type == 'email'
                    ? 'example@domain.com'
                    : field.type == 'phone'
                        ? '+1 234 567 8900'
                        : 'Enter value...',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

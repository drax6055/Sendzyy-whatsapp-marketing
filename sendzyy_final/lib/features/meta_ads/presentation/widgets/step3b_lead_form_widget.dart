import 'package:flutter/material.dart';
import '../../data/models/meta_campaign_model.dart';

class Step3bLeadFormWidget extends StatelessWidget {
  final TextEditingController formNameController;
  final String formType;
  final ValueChanged<String> onFormTypeChanged;
  final TextEditingController introHeadlineController;
  final TextEditingController introDescController;
  final List<LeadFormQuestion> questions;
  final ValueChanged<List<LeadFormQuestion>> onQuestionsChanged;
  final TextEditingController privacyPolicyController;
  final TextEditingController completionHeadlineController;
  final TextEditingController completionDescController;
  final String completionCtaType;
  final ValueChanged<String> onCompletionCtaTypeChanged;
  final TextEditingController completionCtaTextController;
  final TextEditingController completionCtaUrlController;

  const Step3bLeadFormWidget({
    super.key,
    required this.formNameController,
    required this.formType,
    required this.onFormTypeChanged,
    required this.introHeadlineController,
    required this.introDescController,
    required this.questions,
    required this.onQuestionsChanged,
    required this.privacyPolicyController,
    required this.completionHeadlineController,
    required this.completionDescController,
    required this.completionCtaType,
    required this.onCompletionCtaTypeChanged,
    required this.completionCtaTextController,
    required this.completionCtaUrlController,
  });

  void _addQuestion(String type, String label) {
    final updated = List<LeadFormQuestion>.from(questions);
    updated.add(LeadFormQuestion(type: type, label: label));
    onQuestionsChanged(updated);
  }

  void _removeQuestion(int index) {
    final updated = List<LeadFormQuestion>.from(questions);
    updated.removeAt(index);
    onQuestionsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Form Settings
          _buildCard(
            title: 'Lead Form Configuration',
            icon: Icons.assignment_outlined,
            subtitle: 'Instant Forms allow users to submit contact details without leaving Facebook or Instagram.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: formNameController,
                  decoration: const InputDecoration(
                    labelText: 'Form Name *',
                    hintText: 'e.g. Sendzyy WhatsApp Lead Form 2026',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Form Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  value: 'MORE_VOLUME',
                  groupValue: formType,
                  title: const Text('More Volume (Default)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Fastest to complete on mobile devices; gets maximum lead volume'),
                  activeColor: const Color(0xFF1877F2),
                  onChanged: (val) => onFormTypeChanged(val!),
                ),
                RadioListTile<String>(
                  value: 'HIGHER_INTENT',
                  groupValue: formType,
                  title: const Text('Higher Intent', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Adds a review step so leads can confirm info before submitting'),
                  activeColor: const Color(0xFF1877F2),
                  onChanged: (val) => onFormTypeChanged(val!),
                ),
                RadioListTile<String>(
                  value: 'RICH_CREATIVE',
                  groupValue: formType,
                  title: const Text('Rich Creative', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Includes company introduction and customized benefits overview'),
                  activeColor: const Color(0xFF1877F2),
                  onChanged: (val) => onFormTypeChanged(val!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Intro Screen (Greeting)
          _buildCard(
            title: 'Greeting (Intro Screen)',
            icon: Icons.waving_hand_outlined,
            subtitle: 'Let people know why they should share their information with you.',
            child: Column(
              children: [
                TextField(
                  controller: introHeadlineController,
                  decoration: const InputDecoration(
                    labelText: 'Greeting Headline',
                    hintText: 'e.g. Looking for faster WhatsApp Marketing?',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: introDescController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Greeting Description',
                    hintText: 'e.g. Share your details and our team will send a free demo.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Questions
          _buildCard(
            title: 'Questions & User Fields',
            icon: Icons.help_outline_rounded,
            subtitle: 'Information you request will be pre-filled from the user’s Facebook profile where available.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: questions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(_getQuestionIcon(q.type), color: const Color(0xFF1877F2), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(q.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('Type: ${q.type}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          if (questions.length > 2)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _removeQuestion(index),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                const Text('Add Additional Field:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildAddQuestionChip('CITY', 'City', Icons.location_city),
                    _buildAddQuestionChip('COMPANY_NAME', 'Company Name', Icons.business),
                    _buildAddQuestionChip('JOB_TITLE', 'Job Title', Icons.work_outline),
                    _buildAddQuestionChip('CUSTOM_SHORT_ANSWER', 'Short Question', Icons.edit),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: Privacy Policy
          _buildCard(
            title: 'Privacy Policy',
            icon: Icons.privacy_tip_outlined,
            subtitle: 'Meta requires a valid link to your company’s privacy policy before publishing lead ads.',
            child: TextField(
              controller: privacyPolicyController,
              decoration: const InputDecoration(
                labelText: 'Privacy Policy URL *',
                hintText: 'https://sendzyy.com/privacy',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 5: Completion Screen
          _buildCard(
            title: 'Completion Screen (Thank You Page)',
            icon: Icons.task_alt_rounded,
            subtitle: 'Shown to the user immediately after they submit their lead info.',
            child: Column(
              children: [
                TextField(
                  controller: completionHeadlineController,
                  decoration: const InputDecoration(
                    labelText: 'Headline *',
                    hintText: 'Thank you! We received your details.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: completionDescController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Our team will contact you via WhatsApp shortly.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: completionCtaType,
                  decoration: const InputDecoration(labelText: 'Action Button'),
                  items: const [
                    DropdownMenuItem(value: 'SEND_WHATSAPP', child: Text('Chat on WhatsApp (Recommended)')),
                    DropdownMenuItem(value: 'VIEW_WEBSITE', child: Text('View Website')),
                    DropdownMenuItem(value: 'CALL_BUSINESS', child: Text('Call Business')),
                  ],
                  onChanged: (val) => onCompletionCtaTypeChanged(val ?? 'SEND_WHATSAPP'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: completionCtaTextController,
                  decoration: const InputDecoration(
                    labelText: 'Button Label',
                    hintText: 'e.g. Chat with us now',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: completionCtaUrlController,
                  decoration: InputDecoration(
                    labelText: completionCtaType == 'CALL_BUSINESS'
                        ? 'Phone Number'
                        : completionCtaType == 'SEND_WHATSAPP'
                            ? 'WhatsApp Link / URL'
                            : 'Website URL',
                    hintText: completionCtaType == 'CALL_BUSINESS'
                        ? '+91 98765 43210'
                        : 'https://wa.me/919876543210',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getQuestionIcon(String type) {
    switch (type) {
      case 'PHONE':
        return Icons.phone;
      case 'EMAIL':
        return Icons.email;
      case 'CITY':
        return Icons.location_city;
      case 'COMPANY_NAME':
        return Icons.business;
      case 'JOB_TITLE':
        return Icons.work;
      default:
        return Icons.person;
    }
  }

  Widget _buildAddQuestionChip(String type, String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF1877F2)),
      label: Text(label),
      onPressed: () => _addQuestion(type, label),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF1877F2), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

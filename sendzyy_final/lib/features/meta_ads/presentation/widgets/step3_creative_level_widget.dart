import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/meta_account_model.dart';

class Step3CreativeLevelWidget extends StatelessWidget {
  final TextEditingController adNameController;
  final List<MetaPageItem> pages;
  final String? selectedPageId;
  final ValueChanged<String?> onPageChanged;
  final String adFormat;
  final ValueChanged<String> onFormatChanged;
  final TextEditingController primaryTextController;
  final TextEditingController headlineController;
  final TextEditingController descriptionController;
  final String callToAction;
  final ValueChanged<String> onCtaChanged;
  final TextEditingController websiteUrlController;
  final String? selectedImagePath;
  final ValueChanged<String?> onImageSelected;

  const Step3CreativeLevelWidget({
    super.key,
    required this.adNameController,
    required this.pages,
    required this.selectedPageId,
    required this.onPageChanged,
    required this.adFormat,
    required this.onFormatChanged,
    required this.primaryTextController,
    required this.headlineController,
    required this.descriptionController,
    required this.callToAction,
    required this.onCtaChanged,
    required this.websiteUrlController,
    required this.selectedImagePath,
    required this.onImageSelected,
  });

  static const List<Map<String, String>> _ctaOptions = [
    {'id': 'LEARN_MORE', 'label': 'Learn More'},
    {'id': 'SIGN_UP', 'label': 'Sign Up'},
    {'id': 'GET_QUOTE', 'label': 'Get Quote'},
    {'id': 'WHATSAPP_MESSAGE', 'label': 'Send WhatsApp Message'},
    {'id': 'CONTACT_US', 'label': 'Contact Us'},
    {'id': 'BOOK_NOW', 'label': 'Book Now'},
    {'id': 'APPLY_NOW', 'label': 'Apply Now'},
    {'id': 'DOWNLOAD', 'label': 'Download'},
    {'id': 'ORDER_NOW', 'label': 'Order Now'},
    {'id': 'CALL_NOW', 'label': 'Call Now'},
    {'id': 'SUBSCRIBE', 'label': 'Subscribe'},
    {'id': 'SHOP_NOW', 'label': 'Shop Now'},
    {'id': 'GET_OFFER', 'label': 'Get Offer'},
    {'id': 'MESSAGE_PAGE', 'label': 'Send Message'},
  ];

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      onImageSelected(result.files.single.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Ad Name & Identity
          _buildCard(
            title: 'Ad Name & Identity',
            icon: Icons.badge_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: adNameController,
                  decoration: const InputDecoration(
                    labelText: 'Ad Name *',
                    hintText: 'e.g. Creative V1 - High Conversion',
                  ),
                ),
                const SizedBox(height: 14),
                if (pages.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedPageId ?? (pages.isNotEmpty ? pages.first.id : null),
                    decoration: const InputDecoration(
                      labelText: 'Facebook Page *',
                      prefixIcon: Icon(Icons.facebook, color: Color(0xFF1877F2)),
                    ),
                    items: pages.map((page) {
                      return DropdownMenuItem(
                        value: page.id,
                        child: Text(page.name),
                      );
                    }).toList(),
                    onChanged: onPageChanged,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No Facebook Pages loaded yet. You can connect your page in Meta Settings.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Ad Format
          _buildCard(
            title: 'Ad Format',
            icon: Icons.view_carousel_rounded,
            child: Row(
              children: [
                Expanded(
                  child: _buildFormatTile(
                    'SINGLE_IMAGE',
                    'Single Image or Video',
                    Icons.image_rounded,
                    '1 image or video',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFormatTile(
                    'CAROUSEL',
                    'Carousel',
                    Icons.view_carousel_outlined,
                    '2+ scrollable cards',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Media Upload
          _buildCard(
            title: 'Media Creative',
            icon: Icons.upload_file_rounded,
            subtitle: 'Recommended resolution: 1080×1080px (Square 1:1) or 1080×1350px (Portrait 4:5).',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedImagePath != null && File(selectedImagePath!).existsSync()) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.file(
                          File(selectedImagePath!),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 18),
                              onPressed: () => onImageSelected(null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(selectedImagePath == null ? 'Upload Image / Creative' : 'Change Image'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: Ad Copy (Primary Text, Headline, Description)
          _buildCard(
            title: 'Ad Text & Links',
            icon: Icons.text_fields_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: primaryTextController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Primary Text *',
                    hintText: 'Tell people what your offer is about. This appears above the ad image.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: headlineController,
                  decoration: const InputDecoration(
                    labelText: 'Headline *',
                    hintText: 'Write a short, catchy headline (e.g. Free Consultation Today)',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Additional details below headline',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: callToAction,
                  decoration: const InputDecoration(
                    labelText: 'Call to Action (CTA Button) *',
                  ),
                  items: _ctaOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt['id'],
                      child: Text(opt['label']!),
                    );
                  }).toList(),
                  onChanged: (val) => onCtaChanged(val ?? 'LEARN_MORE'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: websiteUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Website / Landing Page URL',
                    hintText: 'https://yourwebsite.com/promo',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatTile(String id, String title, IconData icon, String subtitle) {
    final isSelected = adFormat == id;
    return InkWell(
      onTap: () => onFormatChanged(id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1877F2).withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1877F2) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? const Color(0xFF1877F2) : Colors.grey.shade700),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? const Color(0xFF1877F2) : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), textAlign: TextAlign.center),
          ],
        ),
      ),
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
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
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

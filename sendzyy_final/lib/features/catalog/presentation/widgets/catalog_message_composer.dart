import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/catalog_dropdown_field.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/catalog_recipient_selector.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/product_browser_widget.dart';
import 'package:iFloraBuzz/features/messages/data/models/recipient_data.dart';
import 'package:iFloraBuzz/features/messages/presentation/widgets/campaign_result_dialog.dart';

/// Form to compose and send a Catalog Message.
/// Shows full catalog thumbnail + "View Catalog" button on WhatsApp.
class CatalogMessageComposer extends StatefulWidget {
  final String? initialTo;
  final String? initialThumbnailId;

  const CatalogMessageComposer({
    super.key,
    this.initialTo,
    this.initialThumbnailId,
  });

  @override
  State<CatalogMessageComposer> createState() => _CatalogMessageComposerState();
}

class _CatalogMessageComposerState extends State<CatalogMessageComposer> {
  final _formKey = GlobalKey<FormState>();
  final _recipientSelectorKey = GlobalKey<CatalogRecipientSelectorState>();
  List<RecipientData> _recipients = [];
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _footerCtrl;
  late final TextEditingController _thumbnailCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.initialTo != null && widget.initialTo!.trim().isNotEmpty) {
      _recipients = [RecipientData.fromNumber(widget.initialTo!)];
    }
    _bodyCtrl = TextEditingController();
    _footerCtrl = TextEditingController();
    _thumbnailCtrl = TextEditingController(text: widget.initialThumbnailId ?? '');
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _footerCtrl.dispose();
    _thumbnailCtrl.dispose();
    super.dispose();
  }

  void _send() {
    _recipientSelectorKey.currentState?.flushPendingInput();
    if (_recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select at least one recipient phone number.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final phoneNumbers = _recipients.map((r) => r.mobileNumber).toList();

    context.read<CatalogBloc>().add(
          SendCatalogMessageEvent(
            CatalogMessageRequest(
              to: phoneNumbers.first,
              recipients: phoneNumbers,
              bodyText: _bodyCtrl.text.trim(),
              footerText: _footerCtrl.text.trim().isEmpty
                  ? null
                  : _footerCtrl.text.trim(),
              thumbnailProductRetailerId: _thumbnailCtrl.text.trim().isEmpty
                  ? null
                  : _thumbnailCtrl.text.trim(),
            ),
          ),
        );
  }

  void _pickThumbnailProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<CatalogBloc>(),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (_, scrollCtrl) => ProductBrowserWidget(
            isPickerMode: true,
            onProductSelected: (p) {
              setState(() => _thumbnailCtrl.text = p.retailerId);
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogSettingsLoaded) {
          if (state.lastBulkResult != null && state.lastBulkResult!.total > 1) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => CampaignResultDialog(
                successCount: state.lastBulkResult!.successCount,
                failureCount: state.lastBulkResult!.failureCount,
                campaignId: 'catalog_${DateTime.now().millisecondsSinceEpoch}',
                dispatchedAt: state.lastBulkResult!.dispatchedAt,
                onDone: () {},
              ),
            );
          }
          if (state.successMessage != null) {
            _bodyCtrl.clear();
            _footerCtrl.clear();
            _thumbnailCtrl.clear();
            if (widget.initialTo == null) {
              setState(() => _recipients = []);
            }
          }
        }
      },
      builder: (context, state) {
        final isSending = state is CatalogSettingsLoaded && state.isSending;
        final sendingCurrent = state is CatalogSettingsLoaded ? state.sendingCurrent : 0;
        final sendingTotal = state is CatalogSettingsLoaded ? state.sendingTotal : 0;

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ComposerInfoBanner(
                icon: Icons.storefront_rounded,
                color: const Color(0xFF25D366),
                title: 'Catalog Message',
                description:
                    'Sends a message with a "View Catalog" button that allows customers to browse your full product inventory on WhatsApp.',
                note:
                    'WhatsApp 24-Hour Rule: Meta allows free-form catalog messages only if the recipient messaged your business in the last 24 hours. If they haven\'t, Meta rejects delivery (Error 131047). Send an approved Template first or ask the customer to reply.',
              ),
              const SizedBox(height: 20),

              // Reusable Recipient Selector (Manual + Clients + Group + CSV)
              CatalogRecipientSelector(
                key: _recipientSelectorKey,
                recipients: _recipients,
                onRecipientsChanged: (list) => setState(() => _recipients = list),
                label: 'Recipient Phone Numbers',
              ),
              const SizedBox(height: 14),

              _buildField(
                controller: _bodyCtrl,
                label: 'Message Body *',
                hint: 'e.g. Hello! Browse our catalog and find what you need.',
                icon: Icons.chat_bubble_outline_rounded,
                maxLines: 3,
                maxLength: 1024,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length > 1024) return 'Max 1024 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _footerCtrl,
                label: 'Footer Text (optional)',
                hint: 'e.g. Best deals on WhatsApp!',
                icon: Icons.notes_rounded,
                maxLength: 60,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _thumbnailCtrl,
                      label: 'Thumbnail Product SKU (optional)',
                      hint: 'e.g. 2lc20305pt — uses first product if omitted',
                      icon: Icons.image_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton.icon(
                      onPressed: _pickThumbnailProduct,
                      icon: const Icon(Icons.storefront_outlined, size: 16),
                      label: const Text('Pick SKU'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isSending ? null : _send,
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    isSending
                        ? (sendingTotal > 1
                            ? 'Sending ($sendingCurrent / $sendingTotal)...'
                            : 'Sending...')
                        : (_recipients.length > 1
                            ? 'Send Catalog Message to ${_recipients.length} Recipients'
                            : 'Send Catalog Message'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Single Product Composer ────────────────────────────────────────────────────

class SingleProductComposer extends StatefulWidget {
  final String? initialTo;
  final String? initialCatalogId;
  final String? initialProductId;

  const SingleProductComposer({
    super.key,
    this.initialTo,
    this.initialCatalogId,
    this.initialProductId,
  });

  @override
  State<SingleProductComposer> createState() => _SingleProductComposerState();
}

class _SingleProductComposerState extends State<SingleProductComposer> {
  final _formKey = GlobalKey<FormState>();
  final _recipientSelectorKey = GlobalKey<CatalogRecipientSelectorState>();
  List<RecipientData> _recipients = [];
  late final TextEditingController _catalogCtrl;
  late final TextEditingController _productCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.initialTo != null && widget.initialTo!.trim().isNotEmpty) {
      _recipients = [RecipientData.fromNumber(widget.initialTo!)];
    }
    _catalogCtrl = TextEditingController(text: widget.initialCatalogId ?? '');
    _productCtrl = TextEditingController(text: widget.initialProductId ?? '');
    _bodyCtrl = TextEditingController();
    _footerCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _catalogCtrl.dispose();
    _productCtrl.dispose();
    _bodyCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _send() {
    _recipientSelectorKey.currentState?.flushPendingInput();
    if (_recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select at least one recipient phone number.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final phoneNumbers = _recipients.map((r) => r.mobileNumber).toList();

    context.read<CatalogBloc>().add(
          SendSingleProductEvent(
            SingleProductRequest(
              to: phoneNumbers.first,
              recipients: phoneNumbers,
              catalogId: _catalogCtrl.text.trim(),
              productRetailerId: _productCtrl.text.trim(),
              bodyText: _bodyCtrl.text.trim().isEmpty
                  ? null
                  : _bodyCtrl.text.trim(),
              footerText: _footerCtrl.text.trim().isEmpty
                  ? null
                  : _footerCtrl.text.trim(),
            ),
          ),
        );
  }

  void _pickProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<CatalogBloc>(),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (_, scrollCtrl) => ProductBrowserWidget(
            isPickerMode: true,
            onProductSelected: (p) {
              setState(() {
                _productCtrl.text = p.retailerId;
              });
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogSettingsLoaded) {
          if (state.lastBulkResult != null && state.lastBulkResult!.total > 1) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => CampaignResultDialog(
                successCount: state.lastBulkResult!.successCount,
                failureCount: state.lastBulkResult!.failureCount,
                campaignId: 'product_${DateTime.now().millisecondsSinceEpoch}',
                dispatchedAt: state.lastBulkResult!.dispatchedAt,
                onDone: () {},
              ),
            );
          }
          if (state.successMessage != null) {
            _bodyCtrl.clear();
            _footerCtrl.clear();
            if (widget.initialTo == null) {
              setState(() => _recipients = []);
            }
          }
        }
      },
      builder: (context, state) {
        final isSending = state is CatalogSettingsLoaded && state.isSending;
        final sendingCurrent = state is CatalogSettingsLoaded ? state.sendingCurrent : 0;
        final sendingTotal = state is CatalogSettingsLoaded ? state.sendingTotal : 0;

        // Auto-fill catalog ID from active catalog if empty
        if (_catalogCtrl.text.isEmpty && state is CatalogSettingsLoaded && state.activeCatalogId != null) {
          _catalogCtrl.text = state.activeCatalogId!;
        }

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ComposerInfoBanner(
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF06B6D4),
                title: 'Single Product Message',
                description:
                    'Highlights one specific product with its image, price, and description. Customers can view details and add to cart.',
                note:
                    'WhatsApp 24-Hour Rule: Recipient must have messaged this business number within the last 24 hours. Outside 24h, Meta rejects interactive messages (Error 131047).',
              ),
              const SizedBox(height: 20),

              // Reusable Recipient Selector
              CatalogRecipientSelector(
                key: _recipientSelectorKey,
                recipients: _recipients,
                onRecipientsChanged: (list) => setState(() => _recipients = list),
                label: 'Recipient Phone Numbers',
              ),
              const SizedBox(height: 14),

              // Catalog ID field
              CatalogDropdownField(
                value: _catalogCtrl.text,
                onChanged: (val) {
                  setState(() => _catalogCtrl.text = val);
                },
              ),
              const SizedBox(height: 14),

              // Product SKU with Browse button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildField(
                      _productCtrl,
                      'Product SKU / Retailer ID *',
                      'e.g. 2lc20305pt',
                      Icons.qr_code_rounded,
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton.icon(
                      onPressed: _pickProduct,
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Browse'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF06B6D4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildField(_bodyCtrl, 'Body Text (optional)',
                  'e.g. Check out this amazing product!',
                  Icons.chat_bubble_outline_rounded, maxLines: 3),
              const SizedBox(height: 14),
              _buildField(_footerCtrl, 'Footer Text (optional)',
                  'e.g. Limited time offer', Icons.notes_rounded,
                  maxLength: 60),
              const SizedBox(height: 24),
              _SendButton(
                isSending: isSending,
                onTap: _send,
                label: _recipients.length > 1
                    ? 'Send Single Product to ${_recipients.length} Recipients'
                    : 'Send Single Product',
                sendingText: sendingTotal > 1 ? 'Sending ($sendingCurrent / $sendingTotal)...' : 'Sending...',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Shared Helpers ────────────────────────────────────────────────────────────

class _ComposerInfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String? note;

  const _ComposerInfoBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.amber.shade900,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback onTap;
  final String label;
  final String? sendingText;

  const _SendButton({
    required this.isSending,
    required this.onTap,
    required this.label,
    this.sendingText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: isSending ? null : onTap,
        icon: isSending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(isSending ? (sendingText ?? 'Sending...') : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}

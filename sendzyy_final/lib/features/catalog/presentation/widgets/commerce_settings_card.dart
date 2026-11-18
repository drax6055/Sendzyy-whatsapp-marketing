import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/snackbar_utils.dart';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';

class CommerceSettingsCard extends StatelessWidget {
  const CommerceSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is! CatalogSettingsLoaded) return const SizedBox.shrink();

        final settings = state.settings;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.05),
                AppTheme.secondaryColor.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isCompact = headerConstraints.maxWidth < 450;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'WhatsApp Commerce Settings',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1D1E),
                                  ),
                                ),
                                if (isCompact)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.2)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.sync_rounded, color: Color(0xFF1877F2), size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Meta API',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1877F2)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Direct sync with Meta WhatsApp Manager',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync_rounded, color: Color(0xFF1877F2), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Meta API',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1877F2)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _SettingToggleRow(
                icon: Icons.store_mall_directory_rounded,
                iconColor: const Color(0xFF6366F1),
                title: 'Show catalogue icon in chat header',
                subtitle:
                    'Adds an icon to your chat header and in your business profile for customers to easily access your catalogue.',
                value: settings.isCatalogVisible,
                onChanged: (val) {
                  context.read<CatalogBloc>().add(
                        UpdateCommerceSettings(catalogVisible: val),
                      );
                },
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _SettingToggleRow(
                icon: Icons.shopping_basket_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Show "Add to basket" button on product pages and chat',
                subtitle:
                    'Adds the basket button to product pages & the trolley icon in chat so customers can add items and order.',
                value: settings.isCartEnabled,
                onChanged: (val) {
                  context.read<CatalogBloc>().add(
                        UpdateCommerceSettings(cartEnabled: val),
                      );
                },
              ),
              const SizedBox(height: 20),
              _CatalogLinkSection(settings: settings),
              const SizedBox(height: 20),
              const _BankPayoutSettingsSection(),
            ],
          ),
        );
      },
    );
  }
}

class _SettingToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1A1D1E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppTheme.primaryColor,
        ),
      ],
    );
  }
}

class _CatalogLinkSection extends StatelessWidget {
  final CatalogCommerceSettings settings;

  const _CatalogLinkSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        String? displayPhone;
        if (authState is AuthAuthenticated) {
          final config = authState.tenant['whatsappConfig'] as Map<String, dynamic>?;
          displayPhone = config?['displayPhone']?.toString() ??
              config?['display_phone_number']?.toString() ??
              config?['phoneNumber']?.toString();
        }

        final cleanPhone = displayPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
        final hasPhone = cleanPhone.isNotEmpty;
        final catalogLink = hasPhone ? 'https://wa.me/c/$cleanPhone' : '';

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.link_rounded, size: 18, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Text(
                    'Direct Catalog Link',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Share this link directly with customers. When tapped, it opens your interactive product catalog inside WhatsApp.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0369A1),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              if (hasPhone) ...[
                // Copyable Link Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 500;
                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF0284C7)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    catalogLink,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: catalogLink));
                                      SnackbarUtils.showSuccess(
                                        context,
                                        'Catalog link copied to clipboard!',
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 14),
                                    label: const Text(
                                      'Copy Link',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Open in WhatsApp',
                                  onPressed: () => webOpenUrl(catalogLink),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF0284C7)),
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFFF0F9FF),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF0284C7)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              catalogLink,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: catalogLink));
                              SnackbarUtils.showSuccess(
                                context,
                                'Catalog link copied to clipboard!',
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text(
                              'Copy Link',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Open in WhatsApp',
                            onPressed: () => webOpenUrl(catalogLink),
                            icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF0284C7)),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF0F9FF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Linked to WhatsApp number: ${displayPhone ?? cleanPhone}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Connect your WhatsApp phone number in Settings to generate your business catalog link.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BankPayoutSettingsSection extends StatefulWidget {
  const _BankPayoutSettingsSection();

  @override
  State<_BankPayoutSettingsSection> createState() => _BankPayoutSettingsSectionState();
}

class _BankPayoutSettingsSectionState extends State<_BankPayoutSettingsSection> {
  final _businessNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _upiController = TextEditingController();
  final _razorpayAccountIdController = TextEditingController();

  bool _enabled = true;
  bool _autoSendOnOrder = true;
  bool _obscureAccount = true;
  bool _initialized = false;
  String _razorpayAccountId = '';

  @override
  void dispose() {
    _businessNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _upiController.dispose();
    _razorpayAccountIdController.dispose();
    super.dispose();
  }

  void _syncSettings(TenantPayoutSettings? payout, UpiPaymentSettings? upi) {
    if (payout != null) {
      _businessNameController.text = payout.businessName.isNotEmpty
          ? payout.businessName
          : (upi?.businessName ?? '');
      _accountHolderController.text = payout.accountHolderName;
      _accountNumberController.text = payout.accountNumber;
      _ifscController.text = payout.ifscCode;
      _bankNameController.text = payout.bankName;
      _upiController.text = payout.upiId.isNotEmpty
          ? payout.upiId
          : (upi?.upiId ?? '');
      _razorpayAccountIdController.text = payout.razorpayAccountId;
      _enabled = payout.enabled;
      _autoSendOnOrder = payout.autoSendOnOrder;
      _razorpayAccountId = payout.razorpayAccountId;
    } else if (upi != null) {
      _businessNameController.text = upi.businessName;
      _upiController.text = upi.upiId;
      _enabled = upi.enabled;
      _autoSendOnOrder = upi.autoSendOnOrder;
    }
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogBloc, CatalogState>(
      listenWhen: (prev, curr) {
        if (curr is! CatalogSettingsLoaded) return false;
        final prevLoaded = prev is CatalogSettingsLoaded ? prev : null;
        return prevLoaded?.payoutSettings != curr.payoutSettings ||
            prevLoaded?.upiSettings != curr.upiSettings;
      },
      listener: (context, state) {
        if (state is CatalogSettingsLoaded) {
          setState(() {
            _syncSettings(state.payoutSettings, state.upiSettings);
          });
        }
      },
      builder: (context, state) {
        if (state is! CatalogSettingsLoaded) return const SizedBox.shrink();

        if (!_initialized && (state.payoutSettings != null || state.upiSettings != null)) {
          _syncSettings(state.payoutSettings, state.upiSettings);
        }

        final isSaving = state.isSavingPayoutSettings || state.isSavingUpiSettings;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 650;

            return Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'Bank Settlement & Auto-Verified Payments',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF059669)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Auto-Mark Paid',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_razorpayAccountId.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Linked: $_razorpayAccountId',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _enabled ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _enabled ? 'Active' : 'Disabled',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _enabled ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Instant customer payments via UPI (GPay, PhonePe, Paytm, QR) & Cards. Automatic order verification with zero gateway setup.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Explanatory Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 16, color: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'How Automated Payments Work for Your Store:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildWorkflowBullet(
                          '1. Customer taps "Pay Now" on WhatsApp using UPI (Google Pay, PhonePe, Paytm, QR) or Card.',
                        ),
                        const SizedBox(height: 4),
                        _buildWorkflowBullet(
                          '2. Sendzyy webhook verifies the transaction in milliseconds and automatically marks the order as PAID.',
                        ),
                        const SizedBox(height: 4),
                        _buildWorkflowBullet(
                          '3. Payout settles directly into your designated Bank Account below.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Enable Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accept Auto-Verified Payments',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Send auto-verifiable payment buttons to customers on WhatsApp catalog checkout',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _enabled,
                        activeTrackColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setState(() => _enabled = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1),
                  const SizedBox(height: 18),

                  // Row 1: Primary UPI ID & Store Display Name
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildUpiIdField()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildBusinessNameField()),
                      ],
                    )
                  else ...[
                    _buildUpiIdField(),
                    const SizedBox(height: 16),
                    _buildBusinessNameField(),
                  ],
                  const SizedBox(height: 16),

                  // Row 2: Optional Bank Details
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildAccountNumberField()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildIfscField()),
                      ],
                    )
                  else ...[
                    _buildAccountNumberField(),
                    const SizedBox(height: 16),
                    _buildIfscField(),
                  ],
                  const SizedBox(height: 16),

                  // Row 3: Account Holder & Bank Name
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildAccountHolderField()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildBankNameField()),
                      ],
                    )
                  else ...[
                    _buildAccountHolderField(),
                    const SizedBox(height: 16),
                    _buildBankNameField(),
                  ],
                  const SizedBox(height: 16),

                  // Optional Razorpay Route Linked Account ID
                  _buildRazorpayAccountIdField(),
                  const SizedBox(height: 18),

                  // Auto-send toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Send Payment Link on Order',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Automatically dispatch the interactive payment link immediately when a customer orders from WhatsApp catalog',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _autoSendOnOrder,
                        activeTrackColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setState(() => _autoSendOnOrder = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Save Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving ? null : _savePayoutSettings,
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        isSaving ? 'Saving Bank Details...' : 'Save Bank Settlement Details',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWorkflowBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessNameField() {
    return TextField(
      controller: _businessNameController,
      decoration: InputDecoration(
        labelText: 'Store / Brand Display Name *',
        hintText: 'e.g. Acme Fashion Store',
        prefixIcon: const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF64748B)),
        helperText: 'Displayed as payee name to customer on WhatsApp & payment receipts.',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildAccountHolderField() {
    return TextField(
      controller: _accountHolderController,
      decoration: InputDecoration(
        labelText: 'Bank Account Holder Name (Optional)',
        hintText: 'e.g. John Doe / Acme Enterprises',
        prefixIcon: const Icon(Icons.badge_rounded, size: 18, color: Color(0xFF64748B)),
        helperText: 'Optional beneficiary name if accepting direct bank transfers.',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildAccountNumberField() {
    return TextField(
      controller: _accountNumberController,
      obscureText: _obscureAccount,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9•]')),
      ],
      decoration: InputDecoration(
        labelText: 'Bank Account Number (Optional)',
        hintText: 'e.g. 91234567890123',
        prefixIcon: const Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF64748B)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureAccount ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 18,
            color: const Color(0xFF64748B),
          ),
          onPressed: () {
            setState(() => _obscureAccount = !_obscureAccount);
          },
          tooltip: _obscureAccount ? 'Show Account Number' : 'Hide Account Number',
        ),
        helperText: 'Optional bank account number for manual wire transfers.',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildIfscField() {
    return TextField(
      controller: _ifscController,
      textCapitalization: TextCapitalization.characters,
      maxLength: 11,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
        TextInputFormatter.withFunction(
          (oldVal, newVal) => TextEditingValue(
            text: newVal.text.toUpperCase(),
            selection: newVal.selection,
          ),
        ),
      ],
      decoration: InputDecoration(
        counterText: '',
        labelText: 'Bank IFSC Code (Optional)',
        hintText: 'e.g. HDFC0001234',
        prefixIcon: const Icon(Icons.pin_rounded, size: 18, color: Color(0xFF64748B)),
        helperText: 'Optional 11-character Indian Financial System Code.',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBankNameField() {
    return TextField(
      controller: _bankNameController,
      decoration: InputDecoration(
        labelText: 'Bank Name (Optional)',
        hintText: 'e.g. HDFC Bank, ICICI Bank, SBI',
        prefixIcon: const Icon(Icons.corporate_fare_rounded, size: 18, color: Color(0xFF64748B)),
        helperText: 'Name of the bank for your records.',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildUpiIdField() {
    return TextField(
      controller: _upiController,
      decoration: InputDecoration(
        labelText: 'Store UPI ID / VPA *',
        hintText: 'e.g. store@okhdfcbank, 9876543210@paytm, name@okaxis',
        prefixIcon: const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFF059669)),
        helperText: 'Customers will pay directly to this UPI ID via Google Pay, PhonePe, Paytm, etc.',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRazorpayAccountIdField() {
    return TextField(
      controller: _razorpayAccountIdController,
      decoration: InputDecoration(
        labelText: 'Razorpay Route Linked Account ID (Optional)',
        hintText: 'e.g. acc_N1234567890abc',
        prefixIcon: const Icon(Icons.hub_rounded, size: 18, color: Color(0xFF2563EB)),
        helperText: 'Your Razorpay Route Account ID (acc_...). If empty, Sendzyy links automatically when Route is active.',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }

  void _savePayoutSettings() {
    final businessName = _businessNameController.text.trim();
    final accountHolder = _accountHolderController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();
    final bankName = _bankNameController.text.trim();
    final upi = _upiController.text.trim();
    final razorpayAcc = _razorpayAccountIdController.text.trim();

    if (_enabled) {
      if (businessName.isEmpty) {
        _showError('Please enter your Store / Brand Display Name.');
        return;
      }
      if (upi.isEmpty) {
        _showError('Please enter your Store UPI ID (e.g. yourname@okhdfcbank or 9876543210@paytm).');
        return;
      }
      if (!upi.contains('@') || upi.length < 5) {
        _showError('Invalid UPI ID format. Example: yourname@okhdfcbank or 9876543210@paytm');
        return;
      }
      if (accountNumber.isNotEmpty && !accountNumber.contains('•') && (accountNumber.length < 6 || accountNumber.length > 22)) {
        _showError('Bank Account Number must be between 6 and 22 digits.');
        return;
      }
      if (ifsc.isNotEmpty) {
        final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
        if (!ifscRegex.hasMatch(ifsc)) {
          _showError('Invalid IFSC Code format (e.g. HDFC0001234, SBIN0004567).');
          return;
        }
      }
    }

    final payoutSettings = TenantPayoutSettings(
      accountHolderName: accountHolder.isNotEmpty ? accountHolder : businessName,
      accountNumber: accountNumber,
      ifscCode: ifsc,
      bankName: bankName,
      upiId: upi,
      businessName: businessName,
      enabled: _enabled,
      autoSendOnOrder: _autoSendOnOrder,
      razorpayAccountId: razorpayAcc.isNotEmpty ? razorpayAcc : _razorpayAccountId,
    );

    context.read<CatalogBloc>().add(UpdatePayoutSettingsEvent(payoutSettings));

    // Keep upiSettings in sync for backwards-compatibility
    context.read<CatalogBloc>().add(
          UpdateUpiPaymentSettingsEvent(
            UpiPaymentSettings(
              upiId: upi,
              businessName: businessName,
              enabled: _enabled,
              autoSendOnOrder: _autoSendOnOrder,
            ),
          ),
        );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}



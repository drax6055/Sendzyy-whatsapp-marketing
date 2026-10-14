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
              Row(
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp Commerce Settings',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1D1E),
                          ),
                        ),
                        Text(
                          'Direct sync with Meta WhatsApp Manager',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  child: Row(
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
                      // Copy Button
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
                      // Open link button
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
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Linked to WhatsApp number: ${displayPhone ?? cleanPhone}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
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

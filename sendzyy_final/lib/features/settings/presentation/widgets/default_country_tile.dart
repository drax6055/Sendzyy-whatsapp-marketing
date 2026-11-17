import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/services/country_code_service.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/settings/presentation/widgets/country_selection_dialog.dart';

class DefaultCountryCodeTile extends StatefulWidget {
  final VoidCallback? onCountryChanged;

  const DefaultCountryCodeTile({
    super.key,
    this.onCountryChanged,
  });

  @override
  State<DefaultCountryCodeTile> createState() => _DefaultCountryCodeTileState();
}

class _DefaultCountryCodeTileState extends State<DefaultCountryCodeTile> {
  void _showCountryPickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => CountrySelectionDialog(
        currentIso: CountryCodeService.instance.defaultIso,
        onSelected: (iso, name, dialCode) async {
          final messenger = ScaffoldMessenger.of(context);
          final success = await CountryCodeService.instance.setDefaultCountry(
            iso,
            getIt<SharedPreferences>(),
            getIt<Dio>(),
          );
          if (mounted) {
            setState(() {});
            widget.onCountryChanged?.call();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Default country set to $name (+$dialCode)'
                      : 'Country saved locally. Failed to sync with server.',
                ),
                backgroundColor: success ? Colors.green : Colors.orange,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIso = CountryCodeService.instance.defaultIso;
    final currentName = CountryCodeService.instance.defaultCountryName;
    final currentDial = CountryCodeService.instance.defaultDialCode;
    final country = CountryCodeService.allCountries.firstWhere(
      (c) => c['iso'] == currentIso,
      orElse: () => {'flag': '🌐', 'name': currentName, 'dialCode': currentDial},
    );
    final flag = country['flag'] ?? '🌐';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 550;

        return InkWell(
          onTap: () => _showCountryPickerDialog(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 18,
              vertical: isMobile ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isMobile ? 38 : 44,
                  height: isMobile ? 38 : 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(flag, style: TextStyle(fontSize: isMobile ? 19 : 22)),
                ),
                SizedBox(width: isMobile ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Default Country Code',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+$currentDial ($currentIso)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Selected: $currentName (+$currentDial). Applied when numbers in CSV or manual input lack a country code.',
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 12),
                OutlinedButton(
                  onPressed: () => _showCountryPickerDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 14,
                      vertical: isMobile ? 6 : 8,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Change', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


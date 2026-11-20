import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';

/// Interactive, modern Meta Catalog Selector Dropdown.
/// Can be used in page headers, toolbars, and banner cards.
class CatalogSelectorDropdown extends StatelessWidget {
  /// Whether to render in compact chip mode (e.g. for toolbars/search bars).
  final bool isCompact;

  /// Optional custom background color.
  final Color? backgroundColor;

  /// Optional custom border color.
  final Color? borderColor;

  const CatalogSelectorDropdown({
    super.key,
    this.isCompact = false,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is! CatalogSettingsLoaded) {
          return const SizedBox.shrink();
        }

        final activeCat = state.activeCatalog;
        final catalogs = state.catalogs;
        final totalCatalogs = catalogs.length;
        final hasMultiple = totalCatalogs > 1;

        final displayName = activeCat?.name ??
            (catalogs.isNotEmpty
                ? catalogs.first.name
                : (state.activeCatalogId != null
                    ? 'Catalog ${state.activeCatalogId}'
                    : 'Select Catalog'));

        final displayId = state.activeCatalogId ?? activeCat?.catalogId ?? '';

        if (isCompact) {
          return InkWell(
            onTap: () => _openCatalogSelectorSheet(context, state),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor ?? const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasMultiple) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalCatalogs',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          );
        }

        // Full Header / Banner selector button
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openCatalogSelectorSheet(context, state),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor ?? const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor ?? const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 17,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasMultiple) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$totalCatalogs Catalogs',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (displayId.isNotEmpty)
                          Text(
                            'ID: $displayId',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _openCatalogSelectorSheet(
      BuildContext context, CatalogSettingsLoaded state) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: context.read<CatalogBloc>(),
          child: _CatalogSelectorContent(state: state),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => BlocProvider.value(
          value: context.read<CatalogBloc>(),
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
              child: _CatalogSelectorContent(state: state),
            ),
          ),
        ),
      );
    }
  }

  /// Opens the dialog to connect / link a Meta Catalog ID manually
  static void showAddCatalogDialog(BuildContext context) {
    final catalogIdCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_business_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 10),
            Text('Connect Meta Catalog', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the Catalog ID from your Meta Commerce Manager to link and select it in Sendzyy.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: catalogIdCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Meta Catalog ID *',
                  hintText: 'e.g. 1049858267742855',
                  prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a valid Meta Catalog ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Catalog Name (Optional)',
                  hintText: 'e.g. Catalogue_Apps_and_Software',
                  prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final catId = catalogIdCtrl.text.trim();
                final catName = nameCtrl.text.trim();
                context.read<CatalogBloc>().add(
                      SelectActiveCatalog(
                        catId,
                        name: catName.isNotEmpty ? catName : null,
                      ),
                    );
                Navigator.of(dlgContext).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Connect & Select'),
          ),
        ],
      ),
    );
  }
}

class _CatalogSelectorContent extends StatefulWidget {
  final CatalogSettingsLoaded state;
  const _CatalogSelectorContent({required this.state});

  @override
  State<_CatalogSelectorContent> createState() => _CatalogSelectorContentState();
}

class _CatalogSelectorContentState extends State<_CatalogSelectorContent> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, blocState) {
        final state = blocState is CatalogSettingsLoaded
            ? blocState
            : widget.state;
        final catalogs = state.catalogs;
        final activeId = state.activeCatalogId;

        final filteredCatalogs = catalogs.where((c) {
          if (_filter.isEmpty) return true;
          final q = _filter.toLowerCase();
          return c.name.toLowerCase().contains(q) ||
              c.catalogId.toLowerCase().contains(q) ||
              c.vertical.toLowerCase().contains(q);
        }).toList();

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Meta Catalog',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            catalogs.isNotEmpty
                                ? '${catalogs.length} catalog${catalogs.length > 1 ? "s" : ""} connected with Meta Commerce'
                                : 'Choose or connect a catalog',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: const Color(0xFF6B7280),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // Search bar if more than 3 catalogs
              if (catalogs.length > 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _filter = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search catalogues by name or ID...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),

              // Catalogs List
              Flexible(
                child: filteredCatalogs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No matching catalogs found',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Click "Sync Meta" below to fetch your catalogs.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: filteredCatalogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cat = filteredCatalogs[index];
                          final isSelected = cat.catalogId == activeId;

                          return InkWell(
                            onTap: () {
                              if (!isSelected) {
                                context
                                    .read<CatalogBloc>()
                                    .add(SelectActiveCatalog(cat.catalogId));
                              }
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.06)
                                    : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFE5E7EB),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Selected Radio/Check
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? const Color(0xFF10B981)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF9CA3AF),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                cat.name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  color: const Color(0xFF111827),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'ACTIVE',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF047857),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Catalog ID: ${cat.catalogId} • ${cat.vertical}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (cat.productCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: Text(
                                        '${cat.productCount} items',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // Bottom Action: Sync with Meta
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: state.isSyncingCatalogs
                        ? null
                        : () {
                            context
                                .read<CatalogBloc>()
                                .add(SyncCatalogsWithMeta());
                            Navigator.of(context).pop();
                          },
                    icon: state.isSyncingCatalogs
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(
                      state.isSyncingCatalogs ? 'Syncing...' : 'Sync Meta',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

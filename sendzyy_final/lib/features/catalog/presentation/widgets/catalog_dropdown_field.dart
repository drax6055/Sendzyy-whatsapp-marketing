import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/data/repositories/catalog_repository.dart';

/// Reusable Dropdown for selecting a Meta Catalog ID
class CatalogDropdownField extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final String labelText;
  final bool required;
  final EdgeInsetsGeometry? contentPadding;

  const CatalogDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Catalog ID *',
    this.required = true,
    this.contentPadding,
  });
  @override
  State<CatalogDropdownField> createState() => _CatalogDropdownFieldState();
}

class _CatalogDropdownFieldState extends State<CatalogDropdownField> {
  late final CatalogRepository _repository;
  List<CatalogInfo> _catalogs = [];
  String? _activeCatalogId;
  bool _isLoading = true;
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _repository = getIt<CatalogRepository>();
    _selectedValue = widget.value;
    _loadCatalogs();
  }

  @override
  void didUpdateWidget(covariant CatalogDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      setState(() {
        _selectedValue = widget.value;
      });
    }
  }

  Future<void> _loadCatalogs() async {
    try {
      final res = await _repository.getCatalogs();
      if (!mounted) return;
      setState(() {
        _catalogs = res.catalogs;
        _activeCatalogId = res.activeCatalogId;
        _isLoading = false;

        // Auto-select if currently empty
        if ((_selectedValue == null || _selectedValue!.trim().isEmpty)) {
          final autoId = _activeCatalogId ?? (_catalogs.isNotEmpty ? _catalogs.first.catalogId : null);
          if (autoId != null) {
            _selectedValue = autoId;
            widget.onChanged(autoId);
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return DropdownButtonFormField<String>(
        initialValue: null,
        decoration: InputDecoration(
          labelText: widget.labelText,
          prefixIcon: const Icon(Icons.storage_rounded, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: widget.contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
        hint: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading catalogs...', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        items: const [],
        onChanged: null,
      );
    }

    final items = <DropdownMenuItem<String>>[];

    // Add all discovered catalogs
    for (final cat in _catalogs) {
      items.add(
        DropdownMenuItem<String>(
          value: cat.catalogId,
          child: Text(
            '${cat.name} (${cat.catalogId})',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }

    // If current selected value is not in the list, add it as a preserved option
    if (_selectedValue != null &&
        _selectedValue!.isNotEmpty &&
        !_catalogs.any((c) => c.catalogId == _selectedValue)) {
      items.insert(
        0,
        DropdownMenuItem<String>(
          value: _selectedValue,
          child: Text(
            'Catalog (${_selectedValue!})',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }

    // If still empty and no catalogs at all
    if (items.isEmpty && _activeCatalogId != null && _activeCatalogId!.isNotEmpty) {
      items.add(
        DropdownMenuItem<String>(
          value: _activeCatalogId,
          child: Text(
            'Default Catalog (${_activeCatalogId!})',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }

    // Ensure selected value matches an available item
    final validSelection = items.any((item) => item.value == _selectedValue)
        ? _selectedValue
        : (items.isNotEmpty ? items.first.value : null);

    return DropdownButtonFormField<String>(
      initialValue: validSelection,
      isExpanded: true,
      validator: widget.required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Please select a catalog' : null
          : null,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: const Icon(Icons.storage_rounded, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: widget.contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      items: items,
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedValue = val);
          widget.onChanged(val);
        }
      },
    );
  }
}

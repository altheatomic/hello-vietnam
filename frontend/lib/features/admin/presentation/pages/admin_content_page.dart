import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import 'package:hellovietnam/features/admin/data/admin_content_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_content.dart';

import '../widgets/admin_form_components.dart';
import '../widgets/admin_section_header.dart';

class AdminContentPage extends StatefulWidget {
  const AdminContentPage({super.key, required this.config, this.repository, this.initialEditId});

  final AdminContentResourceConfig config;
  final AdminContentRepository? repository;
  final String? initialEditId;

  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<AdminContentRecord> _records = <AdminContentRecord>[];
  Timer? _searchDebounce;
  late final AdminContentRepository _repository;

  static const int _pageSize = 8;
  int _currentPage = 1;
  int _totalCount = 0;
  int _loadRequestId = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _openedInitialEdit = false;

  AdminContentResourceConfig get _config => widget.config;

  List<AdminContentFieldConfig> get _tableFields =>
      _config.fields.where((field) => field.visibleInTable).toList();

  int get _totalPages =>
      (_totalCount / _pageSize).ceil().clamp(1, 9999).toInt();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AdminContentRepository();
    if (widget.initialEditId?.isNotEmpty == true) {
      _searchController.text = widget.initialEditId!;
    }
    _loadRecords();
  }

  @override
  void didUpdateWidget(covariant AdminContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.table != widget.config.table) {
      _searchController.clear();
      _currentPage = 1;
      _loadRecords();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords({bool showLoader = true}) async {
    final int requestId = ++_loadRequestId;
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final String? initialId = widget.initialEditId;
      if (!_openedInitialEdit && initialId != null && initialId.isNotEmpty) {
        AdminContentRecord? match;
        for (final AdminContentRecord record in _records) {
          if (record.id == initialId) {
            match = record;
            break;
          }
        }
        if (match != null) {
          _openedInitialEdit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openForm(match);
          });
        }
      }
    }

    try {
      final result = await _repository.fetchPage(
        _config,
        page: _currentPage,
        pageSize: _pageSize,
        query: _searchController.text,
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _records
          ..clear()
          ..addAll(result.items);
        _totalCount = result.totalCount;
        _currentPage = _currentPage > _totalPages ? _totalPages : _currentPage;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _currentPage = 1);
      _loadRecords(showLoader: false);
    });
  }

  Future<void> _openForm([AdminContentRecord? record]) async {
    AdminContentRecord? formRecord = record;
    if (record != null) {
      try {
        formRecord = await _repository.fetchRecord(_config, record);
      } catch (error) {
        if (!mounted) return;
        _showSnack('Load record failed: $error');
        return;
      }
    }

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: const Color(0x80152B43),
      builder: (_) =>
          _AdminContentFormDialog(config: _config, record: formRecord),
    );
    if (result == null || !mounted) return;

    try {
      if (formRecord == null) {
        await _repository.create(_config, result);
      } else {
        await _repository.update(_config, formRecord, result);
      }
      if (!mounted) return;
      _showSnack(formRecord == null ? 'Created successfully.' : 'Updated.');
      await _loadRecords(showLoader: false);
    } catch (error) {
      if (!mounted) return;
      _showSnack('Save failed: $error');
    }
  }

  Future<void> _confirmDelete(AdminContentRecord record) async {
    final bool archives = _config.fields.any((field) => field.key == 'status');
    final String action = archives ? 'Archive' : 'Delete';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x80152B43),
      builder: (context) {
        return AlertDialog(
          title: Text('$action ${_config.primaryField.label}?'),
          content: Text(
            archives
                ? '"${_displayName(record)}" will be hidden from active results and retained for history.'
                : 'This will permanently delete "${_displayName(record)}".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository.delete(_config, record);
      if (!mounted) return;
      _showSnack(archives ? 'Archived.' : 'Deleted.');
      await _loadRecords(showLoader: false);
    } catch (error) {
      if (!mounted) return;
      _showSnack('$action failed: $error');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _displayName(AdminContentRecord record) {
    final primary = record.textForField(_config.primaryField);
    return primary.isNotEmpty ? primary : record.id;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeader(
          title: _config.title,
          subtitle: _config.subtitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _loadRecords(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add new'),
              ),
            ],
          ),
        ),
        _buildToolbar(),
        const SizedBox(height: 16),
        _buildBody(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: adminInputDecoration(
              hintText: 'Search ${_config.table} records',
              suffixIcon: const Icon(Icons.search_rounded, size: 20),
            ),
          );
          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                icon: _config.icon,
                label: 'Total',
                value: _totalCount.toString(),
              ),
              _MetricPill(
                icon: Icons.filter_alt_outlined,
                label: 'Loaded',
                value: _records.length.toString(),
              ),
            ],
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 12), metrics],
            );
          }

          return Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: search,
                ),
              ),
              const SizedBox(width: 20),
              metrics,
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return SizedBox(
        height: 420,
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          message:
              'Load ${_config.title.toLowerCase()} failed.\n$_errorMessage',
          action: FilledButton.icon(
            onPressed: _loadRecords,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      );
    }
    if (_records.isEmpty) {
      return SizedBox(
        height: 420,
        child: EmptyState(
          icon: _config.icon,
          message: _totalCount == 0 && _searchController.text.trim().isEmpty
              ? 'No records yet.'
              : 'No records match your search.',
          action: _totalCount == 0 && _searchController.text.trim().isEmpty
              ? FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add first record'),
                )
              : null,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            border: Border.all(color: AppColors.divider),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TableHeader(fields: _tableFields),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _records.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    return _TableRow(
                      config: _config,
                      fields: _tableFields,
                      record: record,
                      onEdit: () => _openForm(record),
                      onDelete: () => _confirmDelete(record),
                      archives: _config.fields.any(
                        (field) => field.key == 'status',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _PaginationBar(
          currentPage: _currentPage,
          totalPages: _totalPages,
          onPrevious: _currentPage <= 1
              ? null
              : () {
                  setState(() => _currentPage -= 1);
                  _loadRecords(showLoader: false);
                },
          onNext: _currentPage >= _totalPages
              ? null
              : () {
                  setState(() => _currentPage += 1);
                  _loadRecords(showLoader: false);
                },
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.fields});

  final List<AdminContentFieldConfig> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          const SizedBox(width: 72, child: _HeaderText('ID')),
          const SizedBox(width: 16),
          for (final field in fields)
            Expanded(flex: field.tableFlex, child: _HeaderText(field.label)),
          const SizedBox(width: 128, child: _HeaderText('Actions')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.config,
    required this.fields,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.archives,
  });

  final AdminContentResourceConfig config;
  final List<AdminContentFieldConfig> fields;
  final AdminContentRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool archives;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              record.id.length <= 8 ? record.id : record.id.substring(0, 8),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 16),
          for (final field in fields)
            Expanded(
              flex: field.tableFlex,
              child: _TableCell(
                field: field,
                value: record.textForField(field),
              ),
            ),
          SizedBox(
            width: 128,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
                IconButton(
                  tooltip: archives ? 'Archive' : 'Delete',
                  onPressed: onDelete,
                  color: const Color(0xFFEF4444),
                  icon: Icon(
                    archives
                        ? Icons.archive_outlined
                        : Icons.delete_outline_rounded,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.field, required this.value});

  final AdminContentFieldConfig field;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (field.type == AdminContentFieldType.status) {
      final isActive = value.toLowerCase() == 'active';
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (isActive ? AppColors.primary : AppColors.textSecondary)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value.isEmpty ? 'draft' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    return Text(
      value.isEmpty ? '-' : value,
      maxLines:
          field.type == AdminContentFieldType.multiline ||
              field.type == AdminContentFieldType.json
          ? 2
          : 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Page $currentPage of $totalPages',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: onPrevious, child: const Text('Previous')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onNext, child: const Text('Next')),
      ],
    );
  }
}

class _AdminContentFormDialog extends StatefulWidget {
  const _AdminContentFormDialog({required this.config, this.record});

  final AdminContentResourceConfig config;
  final AdminContentRecord? record;

  @override
  State<_AdminContentFormDialog> createState() =>
      _AdminContentFormDialogState();
}

class _AdminContentFormDialogState extends State<_AdminContentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    _controllers = <String, TextEditingController>{
      for (final field in widget.config.fields)
        field.key: TextEditingController(
          text: widget.record?.textForField(field) ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, dynamic>{
      for (final field in widget.config.fields)
        field.key: _controllers[field.key]!.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: _isEditing ? 'Edit ${widget.config.table}' : 'Add new',
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final field in widget.config.fields) ...[
                        AdminFieldLabel(
                          text: '${field.label}${field.required ? ' *' : ''}',
                        ),
                        _fieldFor(field),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            AdminDialogFooter(
              onCancel: () => Navigator.of(context).pop(),
              onSave: _submit,
              saveLabel: _isEditing ? 'Save changes' : 'Create',
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldFor(AdminContentFieldConfig field) {
    final controller = _controllers[field.key]!;
    if (field.type == AdminContentFieldType.status &&
        field.options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: field.options.contains(controller.text)
            ? controller.text
            : null,
        decoration: adminInputDecoration(
          hintText: field.hint ?? 'Select status',
        ),
        items: field.options
            .map(
              (option) =>
                  DropdownMenuItem<String>(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: (value) => controller.text = value ?? '',
        validator: _validatorFor(field),
      );
    }

    return AdminTextFormField(
      controller: controller,
      hint: field.hint ?? field.label,
      maxLines:
          field.type == AdminContentFieldType.multiline ||
              field.type == AdminContentFieldType.json
          ? 5
          : 1,
      keyboardType:
          field.type == AdminContentFieldType.number ||
              field.type == AdminContentFieldType.integer
          ? TextInputType.number
          : TextInputType.text,
      validator: _validatorFor(field),
      helperText: field.type == AdminContentFieldType.json
          ? 'Enter valid JSON, for example [] or {}.'
          : null,
    );
  }

  FormFieldValidator<String> _validatorFor(AdminContentFieldConfig field) {
    return (value) {
      final text = value?.trim() ?? '';
      if (field.required && text.isEmpty) {
        return '${field.label} is required';
      }
      if (text.isEmpty) return null;
      if (field.type == AdminContentFieldType.integer &&
          int.tryParse(text) == null) {
        return '${field.label} must be an integer';
      }
      if (field.type == AdminContentFieldType.number &&
          num.tryParse(text) == null) {
        return '${field.label} must be a number';
      }
      if (field.type == AdminContentFieldType.json) {
        try {
          jsonDecode(text);
        } catch (_) {
          return '${field.label} must be valid JSON';
        }
      }
      return null;
    };
  }
}

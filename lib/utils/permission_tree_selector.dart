import 'package:flutter/material.dart';

import '/utils/permission_catalog.dart';

class PermissionTreeSelector extends StatefulWidget {
  const PermissionTreeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<PermissionTreeSelector> createState() => _PermissionTreeSelectorState();
}

class _PermissionTreeSelectorState extends State<PermissionTreeSelector> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(String text) {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return text.toLowerCase().contains(normalized);
  }

  bool _matchesPermission(PermissionDefinition permission) {
    return _matches(
      '${permission.label} ${permission.description} ${permission.key}',
    );
  }

  List<String> _visibleUnknownPermissions() {
    final unknown = widget.selected
        .where((key) => !kPermissionByKey.containsKey(key))
        .toList()
      ..sort();
    if (_query.trim().isEmpty) return unknown;
    return unknown.where(_matches).toList();
  }

  bool _sectionVisible(PermissionSectionDefinition section) {
    return section.groups.any(_groupVisible);
  }

  bool _groupVisible(PermissionGroupDefinition group) {
    return group.permissions.any(_matchesPermission);
  }

  Set<String> _sectionKeys(PermissionSectionDefinition section) => section
      .groups
      .expand((group) => group.permissions.map((permission) => permission.key))
      .toSet();

  Set<String> _groupKeys(PermissionGroupDefinition group) =>
      group.permissions.map((permission) => permission.key).toSet();

  bool? _checkValue(Set<String> keys) {
    if (keys.isEmpty) return false;
    final selectedCount = keys.where(widget.selected.contains).length;
    if (selectedCount == 0) return false;
    if (selectedCount == keys.length) return true;
    return null;
  }

  void _toggleAll(Set<String> keys, bool enabled) {
    final next = Set<String>.from(widget.selected);
    if (enabled) {
      next.addAll(keys);
    } else {
      next.removeAll(keys);
    }
    widget.onChanged(next);
  }

  void _toggleGroupByCurrentState(Set<String> keys) {
    final hasSelected = keys.any(widget.selected.contains);
    _toggleAll(keys, !hasSelected);
  }

  void _toggleOne(String key, bool enabled) {
    final next = Set<String>.from(widget.selected);
    if (enabled) {
      next.add(key);
    } else {
      next.remove(key);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final unknownPermissions = _visibleUnknownPermissions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Назначение прав идет по уровням',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 6),
              Text(
                '1. Основной раздел в боковом меню\n2. Подраздел внутри этого раздела\n3. Кнопки, функции и блоки на странице',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Поиск по разделам, функциям и кнопкам',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        ...kPermissionSections.where(_sectionVisible).map((section) {
          final sectionKeys = _sectionKeys(section);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              childrenPadding:
                  const EdgeInsets.only(left: 10, right: 10, bottom: 10),
              initiallyExpanded: _query.isNotEmpty,
              title: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: _checkValue(sectionKeys),
                    onChanged: (_) => _toggleGroupByCurrentState(sectionKeys),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Основной раздел',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          section.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${sectionKeys.where(widget.selected.contains).length}/${sectionKeys.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              children: section.groups.where(_groupVisible).map((group) {
                final groupKeys = _groupKeys(group);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    childrenPadding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 12,
                    ),
                    initiallyExpanded: _query.isNotEmpty,
                    title: Row(
                      children: [
                        Checkbox(
                          tristate: true,
                          value: _checkValue(groupKeys),
                          onChanged: (_) =>
                              _toggleGroupByCurrentState(groupKeys),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Подраздел',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0369A1),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                group.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                group.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    children: group.permissions
                        .where(_matchesPermission)
                        .map((permission) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: CheckboxListTile(
                                value: widget.selected.contains(permission.key),
                                onChanged: (value) =>
                                    _toggleOne(permission.key, value == true),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE9FE),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Кнопка / функция',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6D28D9),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      permission.label,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${permission.description}\n${permission.key}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                );
              }).toList(),
            ),
          );
        }),
        if (unknownPermissions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: const Color(0xFFFFFBEB),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFFCD34D)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              title: const Text(
                'Прочие сохраненные права',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Права уже есть в роли, но не описаны в текущем каталоге.',
              ),
              children: unknownPermissions
                  .map(
                    (key) => CheckboxListTile(
                      value: widget.selected.contains(key),
                      onChanged: (value) => _toggleOne(key, value == true),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: Text(key),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

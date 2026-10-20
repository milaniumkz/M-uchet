import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '/user_design/user_design.dart';
import '/user_layout/user_page_layouts.dart';

class SchetaPageAdminPanel extends StatefulWidget {
  const SchetaPageAdminPanel({
    super.key,
    required this.companyId,
  });

  final String companyId;

  @override
  State<SchetaPageAdminPanel> createState() => _SchetaPageAdminPanelState();
}

class _SchetaPageAdminPanelState extends State<SchetaPageAdminPanel> {
  bool _saving = false;

  Future<void> _saveLayout(SchetaPageLayoutData layout) async {
    final companyId = widget.companyId.trim();
    if (companyId.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .set(
        {
          kUserPageLayoutsField: {
            kSchetaPageLayoutKey: layout.toMap(),
          },
          'userPageLayoutsUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Color?> _pickColor(
    BuildContext context, {
    required String title,
    required Color? initial,
  }) async {
    var current = initial ?? const Color(0xFFFFFFFF);
    final hexController = TextEditingController(
      text: initial == null ? '' : colorToHex(initial),
    );

    final result = await showDialog<Color?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void updateColor(Color color) {
              setModalState(() {
                current = color;
                hexController.text = colorToHex(color);
              });
            }

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: current,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: hexController,
                        decoration: const InputDecoration(
                          labelText: 'HEX',
                          hintText: '#FFFFFFFF',
                        ),
                        onChanged: (value) {
                          final parsed = colorFromHex(value, current);
                          if (parsed.toARGB32() != current.toARGB32()) {
                            setModalState(() => current = parsed);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('R: ${current.red}'),
                      Slider(
                        value: current.red.toDouble(),
                        min: 0,
                        max: 255,
                        onChanged: (value) =>
                            updateColor(current.withRed(value.round())),
                      ),
                      Text('G: ${current.green}'),
                      Slider(
                        value: current.green.toDouble(),
                        min: 0,
                        max: 255,
                        onChanged: (value) =>
                            updateColor(current.withGreen(value.round())),
                      ),
                      Text('B: ${current.blue}'),
                      Slider(
                        value: current.blue.toDouble(),
                        min: 0,
                        max: 255,
                        onChanged: (value) =>
                            updateColor(current.withBlue(value.round())),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Сброс'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, current),
                  child: const Text('Выбрать'),
                ),
              ],
            );
          },
        );
      },
    );

    hexController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final companyId = widget.companyId.trim();
    if (companyId.isEmpty) {
      return const Text('Компания не выбрана');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final layout = SchetaPageLayoutData.fromCompanyData(data);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Редактор страницы "Счета"',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Можно менять порядок, скрывать блоки и настраивать базовые цвета каждого блока.',
                      ),
                    ],
                  ),
                ),
                if (_saving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: layout.blocks.length,
              onReorder: (oldIndex, newIndex) async {
                final blocks = List<PageLayoutBlockData>.from(layout.blocks);
                if (newIndex > oldIndex) newIndex -= 1;
                final moved = blocks.removeAt(oldIndex);
                blocks.insert(newIndex, moved);
                await _saveLayout(SchetaPageLayoutData(blocks: blocks));
              },
              itemBuilder: (context, index) {
                final block = layout.blocks[index];
                return Card(
                  key: ValueKey(block.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Icon(Icons.drag_indicator),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                schetaBlockTitle(block.id),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Switch(
                              value: block.visible,
                              onChanged: (value) async {
                                final blocks = List<PageLayoutBlockData>.from(
                                    layout.blocks);
                                blocks[index] = block.copyWith(visible: value);
                                await _saveLayout(
                                  SchetaPageLayoutData(blocks: blocks),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _colorChip(
                              context,
                              label: 'Фон блока',
                              color: block.backgroundColor,
                              onTap: () async {
                                final color = await _pickColor(
                                  context,
                                  title:
                                      'Цвет фона: ${schetaBlockTitle(block.id)}',
                                  initial: block.backgroundColor,
                                );
                                final blocks = List<PageLayoutBlockData>.from(
                                    layout.blocks);
                                blocks[index] = color == null
                                    ? block.copyWith(clearBackground: true)
                                    : block.copyWith(backgroundColor: color);
                                await _saveLayout(
                                  SchetaPageLayoutData(blocks: blocks),
                                );
                              },
                            ),
                            _colorChip(
                              context,
                              label: 'Граница',
                              color: block.borderColor,
                              onTap: () async {
                                final color = await _pickColor(
                                  context,
                                  title:
                                      'Цвет границы: ${schetaBlockTitle(block.id)}',
                                  initial: block.borderColor,
                                );
                                final blocks = List<PageLayoutBlockData>.from(
                                    layout.blocks);
                                blocks[index] = color == null
                                    ? block.copyWith(clearBorder: true)
                                    : block.copyWith(borderColor: color);
                                await _saveLayout(
                                  SchetaPageLayoutData(blocks: blocks),
                                );
                              },
                            ),
                            _colorChip(
                              context,
                              label: 'Текст',
                              color: block.textColor,
                              onTap: () async {
                                final color = await _pickColor(
                                  context,
                                  title:
                                      'Цвет текста: ${schetaBlockTitle(block.id)}',
                                  initial: block.textColor,
                                );
                                final blocks = List<PageLayoutBlockData>.from(
                                    layout.blocks);
                                blocks[index] = color == null
                                    ? block.copyWith(clearText: true)
                                    : block.copyWith(textColor: color);
                                await _saveLayout(
                                  SchetaPageLayoutData(blocks: blocks),
                                );
                              },
                            ),
                            _colorChip(
                              context,
                              label: 'Акцент / кнопки',
                              color: block.accentColor,
                              onTap: () async {
                                final color = await _pickColor(
                                  context,
                                  title:
                                      'Акцент: ${schetaBlockTitle(block.id)}',
                                  initial: block.accentColor,
                                );
                                final blocks = List<PageLayoutBlockData>.from(
                                    layout.blocks);
                                blocks[index] = color == null
                                    ? block.copyWith(clearAccent: true)
                                    : block.copyWith(accentColor: color);
                                await _saveLayout(
                                  SchetaPageLayoutData(blocks: blocks),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _colorChip(
    BuildContext context, {
    required String label,
    required Color? color,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color ?? Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

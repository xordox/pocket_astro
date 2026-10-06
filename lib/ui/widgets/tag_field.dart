/// Tags on a saved chart.
///
/// Part of gap G-42. A working astrologer carries hundreds of charts and needs
/// to find "the client I saw last spring about the house move" in seconds. A
/// name and a free-text note do not support that; a handful of tags do, and
/// they cost one line in the record.
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Tags offered before the reader has invented their own.
///
/// Deliberately about *why a chart is open* rather than about astrology — the
/// astrology is already in the chart, and what a filing system needs is the
/// thing the chart cannot tell you.
const suggestedTags = [
  'client',
  'family',
  'rectify',
  'follow up',
  'marriage',
  'career',
  'health',
  'relocation',
  'study',
];

class TagField extends StatefulWidget {
  const TagField({super.key, required this.tags, required this.onChanged});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<TagField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final tag = raw.trim().toLowerCase();
    if (tag.isEmpty || widget.tags.contains(tag)) return;
    widget.onChanged([...widget.tags, tag]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final unused =
        suggestedTags.where((t) => !widget.tags.contains(t)).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: Type.caption),
        const SizedBox(height: Gap.xs),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.xs,
          children: [
            for (final tag in widget.tags)
              InputChip(
                label: Text(tag),
                onDeleted: () => widget.onChanged(
                    widget.tags.where((t) => t != tag).toList()),
              ),
            for (final tag in unused)
              ActionChip(
                label: Text(tag),
                avatar: const Icon(Icons.add, size: 15),
                onPressed: () => _add(tag),
              ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Add a tag',
            border: OutlineInputBorder(),
          ),
          onSubmitted: _add,
        ),
      ],
    );
  }
}

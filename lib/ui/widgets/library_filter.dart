/// Finding a chart again.
///
/// Part of gap G-42. A working astrologer carries hundreds of charts, and a
/// flat list stops being a library somewhere around two dozen. The search runs
/// over the notes as well as the name, because "the client I saw last spring
/// about the house move" is a phrase from a note.
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class LibraryFilter extends StatelessWidget {
  const LibraryFilter({
    super.key,
    required this.query,
    required this.activeTags,
    required this.allTags,
    required this.onQuery,
    required this.onToggleTag,
  });

  final String query;
  final Set<String> activeTags;
  final List<String> allTags;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onToggleTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: onQuery,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 19),
            hintText: 'Name, place, tag or note',
            border: const OutlineInputBorder(),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onQuery(''),
                  ),
          ),
        ),
        if (allTags.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final tag in allTags.take(12))
                FilterChip(
                  label: Text(tag),
                  selected: activeTags.contains(tag),
                  onSelected: (_) => onToggleTag(tag),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

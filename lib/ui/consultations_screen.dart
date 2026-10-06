/// The consultation log.
///
/// The rest of gap G-42. Tags and search let a practitioner *find* a chart;
/// this is what makes the second session useful.
///
/// Notes hang off a **date**, not off the person. "What did we talk about last
/// time" is a question about an occasion, and a single free-text field on the
/// chart — which is what the app had — answers it by accumulating an
/// undifferentiated wall of text that nobody reads twice.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/interchange.dart';
import '../data/local_store.dart';
import '../domain/models.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';
import 'widgets/tag_field.dart';

final _date = DateFormat('d MMMM yyyy');

class ConsultationsScreen extends StatefulWidget {
  const ConsultationsScreen({super.key, required this.input, this.store});

  final BirthInput input;

  /// Injected in tests so nothing touches the real documents directory.
  final LocalStore? store;

  @override
  State<ConsultationsScreen> createState() => _ConsultationsScreenState();
}

class _ConsultationsScreenState extends State<ConsultationsScreen> {
  late final LocalStore _store = widget.store ?? LocalStore();
  Map<String, List<Consultation>> _all = {};
  bool _loading = true;

  List<Consultation> get _mine {
    final list = [...?_all[widget.input.id]];
    // Most recent first: the last session is the one you need before the next.
    list.sort((a, b) => b.when.compareTo(a.when));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _store.loadConsultations();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  Future<void> _save(List<Consultation> mine) async {
    final next = {..._all, widget.input.id: mine};
    setState(() => _all = next);
    await _store.saveConsultations(next);
  }

  Future<void> _edit({Consultation? existing}) async {
    final result = await showModalBottomSheet<Consultation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SessionSheet(
        chartId: widget.input.id,
        existing: existing,
      ),
    );
    if (result == null) return;
    final mine = [..._mine.where((c) => c.id != result.id), result];
    await _save(mine);
  }

  Future<void> _delete(Consultation c) async {
    await _save(_mine.where((x) => x.id != c.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.input.name} — sessions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New session'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 96),
              children: [
                const QuietNote(
                  'Notes belong to an occasion, not to a person. A single '
                  'field on the chart becomes a wall of text nobody reads '
                  'twice; a dated entry is something you can open before the '
                  'next appointment.',
                  icon: Icons.history_edu_outlined,
                ),
                const SizedBox(height: Gap.lg),
                if (_mine.isEmpty)
                  const QuietNote('No sessions recorded yet.')
                else
                  for (final c in _mine)
                    _SessionCard(
                      consultation: c,
                      onEdit: () => _edit(existing: c),
                      onDelete: () => _delete(c),
                    ),
              ],
            ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.consultation,
    required this.onEdit,
    required this.onDelete,
  });

  final Consultation consultation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Card(
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_date.format(consultation.when.toLocal()),
                              style: Type.micro),
                          Text(
                            consultation.summary.isEmpty
                                ? 'Untitled session'
                                : consultation.summary,
                            style: Type.title,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: onDelete,
                      tooltip: 'Delete this session',
                    ),
                  ],
                ),
                if (consultation.topics.isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  Wrap(
                    spacing: Gap.xs,
                    children: [
                      for (final t in consultation.topics)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: neutralTint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(t, style: Type.micro),
                        ),
                    ],
                  ),
                ],
                if (consultation.notes.isNotEmpty) ...[
                  const SizedBox(height: Gap.sm),
                  Text(consultation.notes, style: Type.bodySoft),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionSheet extends StatefulWidget {
  const _SessionSheet({required this.chartId, this.existing});

  final String chartId;
  final Consultation? existing;

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  late final _summary =
      TextEditingController(text: widget.existing?.summary ?? '');
  late final _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime _when = widget.existing?.when ?? DateTime.now();
  late List<String> _topics = [...?widget.existing?.topics];

  @override
  void dispose() {
    _summary.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.lg,
        right: Gap.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'New session' : 'Edit session',
              style: Type.title,
            ),
            const SizedBox(height: Gap.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(_date.format(_when), style: Type.body),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _when,
                  firstDate: DateTime(1970),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _when = d);
              },
            ),
            TextField(
              controller: _summary,
              decoration: const InputDecoration(
                labelText: 'What was it about?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Gap.md),
            TagField(
              tags: _topics,
              onChanged: (t) => setState(() => _topics = t),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: _notes,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Gap.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: Gap.sm),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    Consultation(
                      id: widget.existing?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      chartId: widget.chartId,
                      when: _when,
                      summary: _summary.text.trim(),
                      notes: _notes.text.trim(),
                      topics: _topics,
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

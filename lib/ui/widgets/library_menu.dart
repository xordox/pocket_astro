/// Backup, export and import.
///
/// Gap G-41. Until this existed the app could only ever be someone's second
/// tool — nobody retypes eight hundred client records to try something.
///
/// Two deliberate choices in the flow:
///
/// * **Import merges, it does not replace.** A reader trying a file out should
///   not be able to lose what they already had, so imported charts are added
///   and a duplicate name is kept rather than overwritten. Undoing an unwanted
///   import is deleting a few rows; undoing a wiped library is not.
/// * **Rejected rows are reported.** A silent drop is the worst behaviour an
///   import can have: the reader believes they have everything and finds out
///   months later.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/interchange.dart';
import '../../data/local_store.dart';
import '../../state/library_bloc.dart';
import '../../state/settings_cubit.dart';
import '../../theme/tokens.dart';

enum _MenuAction { exportJson, exportCsv, importText }

class LibraryMenuButton extends StatelessWidget {
  const LibraryMenuButton({super.key, this.store});

  /// Injected in tests so nothing touches the real documents directory.
  final LocalStore? store;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Backup and transfer',
      icon: const Icon(Icons.import_export),
      onSelected: (action) => _run(context, action),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _MenuAction.exportJson,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.backup_outlined),
            title: Text('Back up everything'),
            subtitle: Text('JSON — restores exactly'),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.exportCsv,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.table_view_outlined),
            title: Text('Export as CSV'),
            subtitle: Text('Readable by anything'),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.importText,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.file_download_outlined),
            title: Text('Import charts'),
            subtitle: Text('Paste a backup or a CSV'),
          ),
        ),
      ],
    );
  }

  Future<void> _run(BuildContext context, _MenuAction action) async {
    final bloc = context.read<LibraryBloc>();
    final profiles = bloc.state.profiles;
    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case _MenuAction.exportJson:
        if (profiles.isEmpty) {
          _say(messenger, 'There are no charts to back up yet.');
          return;
        }
        final settings = context.read<SettingsCubit>().state.toJson();
        final text = exportJson(profiles, settings: settings);
        await _share(context, text, 'pocketastro-backup.json', profiles.length);

      case _MenuAction.exportCsv:
        if (profiles.isEmpty) {
          _say(messenger, 'There are no charts to export yet.');
          return;
        }
        await _share(
            context, exportCsv(profiles), 'pocketastro-charts.csv', profiles.length);

      case _MenuAction.importText:
        final text = await showDialog<String>(
          context: context,
          builder: (context) => const _ImportDialog(),
        );
        if (text == null || text.trim().isEmpty || !context.mounted) return;
        _applyImport(context, text);
    }
  }

  Future<void> _share(
      BuildContext context, String text, String filename, int count) async {
    final resolved = store ?? LocalStore();
    final file = await resolved.writeExport(filename, text);
    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '$count chart${count == 1 ? '' : 's'} from PocketAstro.',
      ),
    );
  }

  void _applyImport(BuildContext context, String text) {
    // Sniff rather than ask: a reader pasting a file should not also have to
    // classify it.
    final looksJson = text.trimLeft().startsWith('{');
    final outcome = looksJson ? importJson(text) : importCsv(text);

    final bloc = context.read<LibraryBloc>();
    for (final input in outcome.imported) {
      bloc.add(LibraryUpsert(input));
    }

    showDialog<void>(
      context: context,
      builder: (context) => _ImportReport(outcome: outcome),
    );
  }

  void _say(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import charts'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a PocketAstro backup, or a CSV from another program. '
              'The minimum a CSV needs is a name column and a date column — '
              'the atlas can resolve the place from its name if there are no '
              'coordinates.',
              style: Type.bodySoft,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Imported charts are added to your library. Nothing already '
              'there is replaced.',
              style: Type.caption,
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: _controller,
              maxLines: 10,
              minLines: 6,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'name,date,time,place\nAda,1815-12-10,,London',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Import'),
        ),
      ],
    );
  }
}

class _ImportReport extends StatelessWidget {
  const _ImportReport({required this.outcome});
  final ImportOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final n = outcome.imported.length;
    return AlertDialog(
      title: Text(n == 0 ? 'Nothing imported' : 'Imported $n'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n > 0)
              Text(
                '$n chart${n == 1 ? '' : 's'} added.',
                style: Type.body,
              ),
            if (outcome.skipped > 0) ...[
              const SizedBox(height: Gap.sm),
              Text(
                '${outcome.skipped} row${outcome.skipped == 1 ? '' : 's'} '
                'could not be read and were left out.',
                style: Type.body.copyWith(color: strainedColor),
              ),
            ],
            if (outcome.problems.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in outcome.problems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $p', style: Type.caption),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

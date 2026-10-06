import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/models.dart';
import '../engine/learn.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/library_bloc.dart';
import 'learn_tab.dart';

/// The course, reachable from the home screen without opening a chart first.
///
/// The same [LearnTab] the chart screen shows, given a chart when one exists
/// so the worked examples still resolve. Which chart: the first saved profile,
/// because the alternative — asking the reader to pick one before they may
/// read lesson one — puts a decision in front of a beginner who does not yet
/// have the vocabulary to make it. A reader with several charts and a
/// preference can still open the tab inside the chart they mean.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        final profiles = state.profiles;
        // A chart is an enrichment here, never a requirement: syllabusFor(null)
        // returns the same fifteen lessons with the examples left out.
        NatalChart? chart;
        try {
          chart = profiles.isEmpty ? null : chartFor(profiles.first);
        } catch (_) {
          chart = null;
        }
        return Scaffold(
          appBar: AppBar(title: Text(L.of(context).navLearn)),
          body: LearnTab(syllabus: syllabusFor(chart)),
        );
      },
    );
  }
}

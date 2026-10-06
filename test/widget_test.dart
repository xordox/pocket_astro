import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/app.dart';
import 'package:pocket_astro/data/geocoder.dart';
import 'package:pocket_astro/data/local_store.dart';
import 'package:pocket_astro/domain/models.dart';

class _MemStore extends LocalStore {
  List<BirthInput> saved = [];

  @override
  Future<List<BirthInput>> loadProfiles() async => saved;

  @override
  Future<void> saveProfiles(List<BirthInput> profiles) async {
    saved = profiles;
  }
}

void main() {
  testWidgets('PocketAstro loads library', (tester) async {
    bootstrapTimezones();
    await tester.pumpWidget(PocketAstroApp(store: _MemStore(), geocoder: const OfflineGeocoder()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('PocketAstro'), findsWidgets);
    expect(find.textContaining('Read a birth chart, offline'), findsOneWidget);
  });
}

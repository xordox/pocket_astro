/// Birth record to UTC.
///
/// Delegates to `zone_offset.dart`, which owns both readings — zone time and
/// local mean time. Kept as its own file because half the engine imports it
/// and the call site should stay three words long.
library;

import '../domain/models.dart';
import 'zone_offset.dart';

DateTime toUtc(BirthInput input) => toUtcWith(input, input.timeStandard);

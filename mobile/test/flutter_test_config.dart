import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';

/// Match the app bootstrap's explicit English date symbols in every test
/// isolate. Tests must not depend on another test having initialized Intl first.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting('en');
  await testMain();
}

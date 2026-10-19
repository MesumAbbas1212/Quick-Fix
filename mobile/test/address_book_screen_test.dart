import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/saved_address.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/client/address_book_screen.dart';
class MockProfiles extends Mock implements ProfileService {}
void main() {
  late MockProfiles profiles;
  const address = SavedAddress(id: 'a', label: 'گھر', address: 'اٹک', location: GeoPoint(33.77, 72.36));
  setUp(() { profiles = MockProfiles(); when(() => profiles.watchAddresses('u')).thenAnswer((_) => Stream.value([address])); when(() => profiles.deleteAddress('u', 'a')).thenAnswer((_) async {}); });
  Future<void> pump(WidgetTester tester) async { await tester.pumpWidget(MaterialApp(home: AddressBookScreen(userId: 'u', profileService: profiles))); await tester.pump(); }
  testWidgets('loading and empty branches provide an add action', (tester) async {
    final stream = StreamController<List<SavedAddress>>(); addTearDown(stream.close); when(() => profiles.watchAddresses('u')).thenAnswer((_) => stream.stream);
    await pump(tester); expect(find.byType(LoadingList), findsOneWidget); stream.add([]); await tester.pumpAndSettle();
    expect(find.text('No saved addresses yet'), findsOneWidget); expect(find.byKey(const Key('address-book-first')), findsOneWidget);
  });
  testWidgets('load error can be retried and RTL address content is preserved', (tester) async {
    when(() => profiles.watchAddresses('u')).thenAnswer((_) => Stream.error(StateError('offline'))); await pump(tester); await tester.pump();
    when(() => profiles.watchAddresses('u')).thenAnswer((_) => Stream.value([address])); await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('اٹک')).textDirection, TextDirection.rtl);
  });
  testWidgets('delete is confirmed before writing', (tester) async {
    await pump(tester); await tester.pumpAndSettle(); await tester.tap(find.byKey(const Key('address-delete-a'))); await tester.pumpAndSettle();
    verifyNever(() => profiles.deleteAddress('u', 'a')); await tester.tap(find.byKey(const Key('address-delete-confirm'))); await tester.pumpAndSettle();
    verify(() => profiles.deleteAddress('u', 'a')).called(1);
  });
  testWidgets('select mode returns an address, not a mutation of the calling form', (tester) async {
    SavedAddress? selected;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () async {
      selected = await Navigator.of(context).push<SavedAddress>(MaterialPageRoute(builder: (_) => AddressBookScreen(userId: 'u', selecting: true, profileService: profiles)));
    }, child: const Text('Choose'))))));
    await tester.tap(find.text('Choose')); await tester.pumpAndSettle(); await tester.tap(find.byKey(const Key('address-use-a'))); await tester.pumpAndSettle();
    expect(selected, same(address)); verifyNever(() => profiles.deleteAddress('u', 'a'));
  });
}

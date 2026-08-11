import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/widgets/review_list_tile.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/review_model.dart';

void main() {
  group('UserAvatar', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('shows network image when avatarUrl is provided', (tester) async {
      await tester.pumpWidget(wrap(const UserAvatar(
        fullName: 'Ahmed Ali',
        avatarUrl: 'https://example.com/a.jpg',
      )));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('AA'), findsNothing);
    });

    testWidgets('shows initials when no avatarUrl', (tester) async {
      await tester.pumpWidget(wrap(const UserAvatar(fullName: 'Ahmed Ali')));
      expect(find.text('AA'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('honors size parameter', (tester) async {
      await tester.pumpWidget(wrap(const UserAvatar(
        fullName: 'Ahmed Ali',
        size: 64,
      )));
      final container = tester.widget<Container>(find.descendant(
        of: find.byType(UserAvatar),
        matching: find.byType(Container),
      ).first);
      final constraints = (container.constraints as BoxConstraints);
      expect(constraints.maxWidth, 64);
      expect(constraints.maxHeight, 64);
    });

    testWidgets('shows online dot when online', (tester) async {
      await tester.pumpWidget(wrap(const UserAvatar(
        fullName: 'Ahmed Ali',
        online: true,
      )));
      expect(
        find.descendant(
          of: find.byType(UserAvatar),
          matching: find.byKey(const Key('avatar-online-dot')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no dot when offline', (tester) async {
      await tester.pumpWidget(wrap(const UserAvatar(fullName: 'Ahmed Ali')));
      expect(
        find.byKey(const Key('avatar-online-dot')),
        findsNothing,
      );
    });

    testWidgets('applies border color when provided', (tester) async {
      await tester.pumpWidget(wrap(const UserAvatar(
        fullName: 'Ahmed Ali',
        borderColor: Colors.red,
      )));
      final decorated = tester.widget<Container>(find.descendant(
        of: find.byType(UserAvatar),
        matching: find.byType(Container),
      ).first);
      expect((decorated.decoration as BoxDecoration).border,
          Border.all(color: Colors.red, width: 2));
    });
  });

  group('ReviewListTile', () {
    final review = Review(
      id: 'r1',
      jobId: 'job-1',
      reviewerId: 'user-1',
      workerId: 'worker-1',
      rating: 4,
      originalText: 'Great work',
      originalLang: 'en',
      createdAt: DateTime(2026, 8, 11),
    );

    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('shows filled and empty stars for rating', (tester) async {
      await tester.pumpWidget(wrap(ReviewListTile(review: review)));
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('shows original text', (tester) async {
      await tester.pumpWidget(wrap(ReviewListTile(review: review)));
      expect(find.text('Great work'), findsOneWidget);
    });

    testWidgets('hides translate button for Latin text', (tester) async {
      await tester.pumpWidget(wrap(ReviewListTile(review: review)));
      expect(find.text('Translate'), findsNothing);
    });

    testWidgets('shows translate button for non-Latin text without translation',
        (tester) async {
      final urduReview = Review(
        id: 'r2',
        jobId: 'job-1',
        reviewerId: 'user-1',
        workerId: 'worker-1',
        rating: 5,
        originalText: 'بہت اچھا کام',
        originalLang: 'ur',
        createdAt: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(wrap(ReviewListTile(review: urduReview)));
      expect(find.text('Translate'), findsOneWidget);
    });

    testWidgets('shows translated text inline when already translated',
        (tester) async {
      final translated = Review(
        id: 'r3',
        jobId: 'job-1',
        reviewerId: 'user-1',
        workerId: 'worker-1',
        rating: 5,
        originalText: 'بہت اچھا کام',
        originalLang: 'ur',
        translatedText: 'Very good work',
        createdAt: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(wrap(ReviewListTile(review: translated)));
      expect(find.text('Very good work'), findsOneWidget);
      expect(find.text('Translate'), findsNothing);
    });

    testWidgets('calls onTranslate and displays returned translation',
        (tester) async {
      final urduReview = Review(
        id: 'r4',
        jobId: 'job-1',
        reviewerId: 'user-1',
        workerId: 'worker-1',
        rating: 5,
        originalText: 'بہت اچھا کام',
        originalLang: 'ur',
        createdAt: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(wrap(ReviewListTile(
        review: urduReview,
        onTranslate: (text) async => 'Very good work',
      )));

      await tester.tap(find.text('Translate'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Very good work'), findsOneWidget);
      expect(find.text('Translate'), findsNothing);
    });
  });
}

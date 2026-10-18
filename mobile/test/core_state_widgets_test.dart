import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/section_header.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('SectionHeader', () {
    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(wrap(const SectionHeader(title: 'Work History')));
      expect(find.text('Work History'), findsOneWidget);
    });

    testWidgets('renders a trailing action', (tester) async {
      await tester.pumpWidget(wrap(const SectionHeader(
        title: 'Reviews',
        trailing: Text('See all'),
      )));
      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('draws a divider only when requested', (tester) async {
      await tester.pumpWidget(wrap(const SectionHeader(title: 'A')));
      expect(find.byType(Divider), findsNothing);

      await tester.pumpWidget(
        wrap(const SectionHeader(title: 'A', showDivider: true)),
      );
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('renders icon, title, message and action', (tester) async {
      await tester.pumpWidget(wrap(const EmptyState(
        icon: Icons.work_outline,
        title: 'No jobs yet',
        message: 'Post your first job to get started.',
        action: Text('Post a job'),
      )));
      expect(find.byIcon(Icons.work_outline), findsOneWidget);
      expect(find.text('No jobs yet'), findsOneWidget);
      expect(
        find.text('Post your first job to get started.'),
        findsOneWidget,
      );
      expect(find.text('Post a job'), findsOneWidget);
    });

    testWidgets('omits the action when not provided', (tester) async {
      await tester.pumpWidget(wrap(const EmptyState(
        icon: Icons.star,
        title: 'Nothing here',
        message: 'Check back later.',
      )));
      expect(find.text('Nothing here'), findsOneWidget);
    });
  });

  group('ErrorState', () {
    testWidgets('renders a human message and fires retry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(wrap(
        ErrorState(
          message: 'Could not load workers. Check your connection.',
          onRetry: () => retries++,
        ),
      ));

      expect(
        find.text('Could not load workers. Check your connection.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.byKey(const Key('error-retry-button')));
      expect(retries, 1);
    });

    testWidgets('renders without a retry button when no callback',
        (tester) async {
      await tester.pumpWidget(wrap(const ErrorState(
        message: 'Could not load data.',
      )));
      expect(find.byKey(const Key('error-retry-button')), findsNothing);
    });
  });

  group('LoadingList', () {
    testWidgets('renders the requested number of skeleton rows', (tester) async {
      await tester.pumpWidget(wrap(const LoadingList(rows: 3)));
      // Each row has a circular avatar placeholder.
      expect(find.byType(LoadingList), findsOneWidget);
    });

    testWidgets('defaults to four rows', (tester) async {
      await tester.pumpWidget(wrap(const LoadingList()));
      expect(find.byType(LoadingList), findsOneWidget);
    });

    testWidgets('never renders a spinner', (tester) async {
      await tester.pumpWidget(wrap(const LoadingList()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

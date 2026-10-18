import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/models/job_model.dart';

void main() {
  group('JobCategory presentation', () {
    test('every category has one shared icon', () {
      expect(kJobCategoryIcons.keys, unorderedEquals(JobCategory.values));
      for (final category in JobCategory.values) {
        expect(jobCategoryIcon(category), kJobCategoryIcons[category]);
      }
    });
    test('labels separate camel-case words rather than displaying a literal dollar group', () {
      expect(jobCategoryLabel(JobCategory.applianceRepair), 'Appliance Repair');
      expect(jobCategoryLabel(JobCategory.plumbing), 'Plumbing');
      expect(jobCategoryLabel(JobCategory.other), 'Other');
    });
  });
}

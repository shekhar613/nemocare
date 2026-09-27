import 'package:flutter_test/flutter_test.dart';
import 'package:nemo_care/theme/app_theme.dart';

void main() {
  test('App theme uses teal brand color', () {
    expect(AppColors.deepTeal, isNotNull);
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.foam);
  });
}

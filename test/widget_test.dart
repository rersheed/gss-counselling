import 'package:flutter_test/flutter_test.dart';
import 'package:gss_counselling/config.dart';
import 'package:gss_counselling/models.dart';
import 'package:gss_counselling/services/api.dart';

void main() {
  test('admission number becomes a login email (must match the Edge Function)', () {
    expect(AuthService.studentEmail(' GSSUS/2024/015 '), 'gssus-2024-015@${AppConfig.studentEmailDomain}');
    expect(AuthService.studentEmail('ss2-a//07'), 'ss2-a-07@${AppConfig.studentEmailDomain}');
  });

  test('unknown topic falls back to "Something else"', () {
    expect(topicFor('nope').key, 'other');
    expect(topicFor('bullying').label, 'Bullying');
  });
}

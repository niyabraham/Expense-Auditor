import 'package:flutter_test/flutter_test.dart';
import 'package:expense_auditor/policy_data.dart';

void main() {
  group('Enterprise Policy Tests', () {
    test('Policy text must contain critical fraud rules', () {
      const policy = AetherisPolicy.fullText;

      // Verify the policy hasn't been accidentally erased
      expect(policy.isNotEmpty, true);

      // Verify critical constraints exist in the text for the AI to read
      expect(policy.contains('\$50 USD'), true, reason: "Missing Tier-1 city limit");
      expect(policy.toLowerCase().contains('alcohol'), true,
          reason: "Missing alcohol restrictions");
    });
  });
}

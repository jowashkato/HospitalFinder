// Unit tests that don't require a live Supabase connection.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hospitalfinder/app_theme.dart';
import 'package:hospitalfinder/hospital.dart';

void main() {
  group('Hospital.fromMap', () {
    test('parses a normalized Supabase row with embedded child tables', () {
      final h = Hospital.fromMap({
        'id': '1',
        'name': 'Sunrise Maternity Center',
        'address': 'Entebbe Rd',
        'latitude': 0.05,
        'longitude': 32.46,
        'phone_number': '0700000000',
        'services': [
          {'name': 'Maternity'},
          {'name': 'Emergency'},
        ],
        'specialties': [
          {'name': 'Pediatrics'},
        ],
        'rating': 4.9,
        'review_count': 876,
        'is_open': true,
      });

      expect(h.name, 'Sunrise Maternity Center');
      expect(h.services, ['Maternity', 'Emergency']);
      expect(h.specialties, ['Pediatrics']);
      expect(h.category, 'Maternity');
      expect(h.rating, 4.9);
      expect(h.isOpen, true);
    });

    test('parses a legacy comma / bracket text column', () {
      final h = Hospital.fromMap({
        'name': 'Old Clinic',
        'diseases': '[Malaria, Typhoid]',
      });
      expect(h.name, 'Old Clinic');
      expect(h.diseases, ['Malaria', 'Typhoid']);
      expect(h.address, 'No address available');
    });

    test('matchesQuery searches across every field', () {
      final h = Hospital.fromMap({
        'name': 'Northside Hospital',
        'services': ['Cardiology'],
      });
      expect(h.matchesQuery('cardio'), isTrue);
      expect(h.matchesQuery('northside'), isTrue);
      expect(h.matchesQuery('dentistry'), isFalse);
      expect(h.matchesQuery(''), isTrue);
    });
  });

  testWidgets('app theme builds and exposes the brand colour', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: Text('ok')),
      ),
    );
    expect(find.text('ok'), findsOneWidget);
    expect(AppColors.primary, const Color(0xFF6D3BE4));
  });
}

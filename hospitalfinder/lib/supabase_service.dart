import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hospital.dart';

class SupabaseService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// Hospital columns plus the embedded child tables (services, specialties).
  static const String _hospitalSelect = '*, services(name), specialties(name)';

  // -------------------------
  // Hospital Management
  // -------------------------

  /// Fetch all hospitals, optionally filtered by a free-text search.
  ///
  /// Search runs client-side across name, address, services, specialties and
  /// diseases — the dataset is small and this keeps the query trivial now that
  /// services/specialties live in their own tables.
  Future<List<Hospital>> getHospitals({String? searchQuery}) async {
    try {
      final response =
          await supabase.from('hospitals').select(_hospitalSelect);
      final hospitals = (response as List)
          .map((e) => Hospital.fromMap(e as Map<String, dynamic>))
          .toList();

      if (searchQuery == null || searchQuery.trim().isEmpty) {
        return hospitals;
      }
      return hospitals.where((h) => h.matchesQuery(searchQuery)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching hospitals: $e');
      }
      throw Exception('Failed to load hospitals: $e');
    }
  }

  /// Distinct service names across all hospitals, each with the number of
  /// hospitals that offer it, sorted alphabetically.
  Future<List<({String name, int count})>> getServiceCounts() =>
      _tagCounts((h) => h.services);

  /// Distinct specialty / "doctor" names, each with a hospital count.
  Future<List<({String name, int count})>> getSpecialtyCounts() =>
      _tagCounts((h) => h.specialties);

  Future<List<({String name, int count})>> _tagCounts(
      List<String> Function(Hospital) pick) async {
    final hospitals = await getHospitals();
    final counts = <String, int>{};
    for (final h in hospitals) {
      for (final raw in pick(h)) {
        final name = raw.trim();
        if (name.isEmpty) continue;
        counts.update(name, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final list = counts.entries
        .map((e) => (name: e.key, count: e.value))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Hospitals that offer [service] or list [specialty] (case-insensitive).
  Future<List<Hospital>> getHospitalsByTag({
    String? service,
    String? specialty,
  }) async {
    final hospitals = await getHospitals();
    bool has(List<String> tags, String want) =>
        tags.any((t) => t.toLowerCase() == want.toLowerCase());
    return hospitals.where((h) {
      if (service != null) return has(h.services, service);
      if (specialty != null) return has(h.specialties, specialty);
      return true;
    }).toList();
  }

  /// Fetch a single hospital by ID.
  Future<Hospital> getHospitalById(String id) async {
    try {
      final response = await supabase
          .from('hospitals')
          .select(_hospitalSelect)
          .eq('id', id)
          .maybeSingle();
      if (response == null) {
        throw Exception('Hospital not found');
      }
      return Hospital.fromMap(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching hospital by ID: $e');
      }
      throw Exception('Failed to load hospital details: $e');
    }
  }

  /// Add a new hospital, writing services/specialties into their child tables.
  Future<Hospital> addHospital({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? userId,
    List<String>? services,
    List<String>? specialties,
    List<String>? diseases,
    String? phoneNumber,
  }) async {
    try {
      final inserted = await supabase.from('hospitals').insert({
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        'phone_number': phoneNumber ?? '',
        'diseases': (diseases ?? const <String>[]).join(','),
      }).select('id').single();

      final hospitalId = inserted['id'] as String;
      await replaceHospitalTags(
        hospitalId,
        services: services,
        specialties: specialties,
      );
      return await getHospitalById(hospitalId);
    } catch (e) {
      if (kDebugMode) {
        print('Error adding hospital: $e');
      }
      throw Exception('Failed to add hospital: $e');
    }
  }

  /// Replace the rows in `services` / `specialties` for a hospital.
  /// Pass `null` for a list to leave that table untouched.
  Future<void> replaceHospitalTags(
    String hospitalId, {
    List<String>? services,
    List<String>? specialties,
  }) async {
    Future<void> sync(String table, List<String>? values) async {
      if (values == null) return;
      await supabase.from(table).delete().eq('hospital_id', hospitalId);
      final clean = values
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (clean.isEmpty) return;
      await supabase.from(table).insert([
        for (final name in clean)
          <String, dynamic>{'hospital_id': hospitalId, 'name': name},
      ]);
    }

    await sync('services', services);
    await sync('specialties', specialties);
  }

  /// Update an existing hospital.
  Future<Hospital> updateHospital(String id, Map<String, dynamic> updates) async {
    try {
      final response = await supabase
          .from('hospitals')
          .update(updates)
          .eq('id', id)
          .select()
          .maybeSingle();
      if (response == null) {
        throw Exception('Hospital not found for update');
      }
      return Hospital.fromMap(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating hospital: $e');
      }
      throw Exception('Failed to update hospital: $e');
    }
  }

  /// Delete a hospital by ID.
  Future<void> deleteHospital(String id) async {
    try {
      await supabase.from('hospitals').delete().eq('id', id);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting hospital: $e');
      }
      throw Exception('Failed to delete hospital: $e');
    }
  }

  /// Hospitals ordered by distance from the given location.
  ///
  /// Returns everything within [radiusInKm]; if nothing is that close (the user
  /// is far from any hospital), it still returns the 10 nearest so the screen is
  /// never empty.
  Future<List<Hospital>> getNearbyHospitals({
    required double latitude,
    required double longitude,
    double radiusInKm = 25.0,
  }) async {
    try {
      final all = await getHospitals();

      final ranked = all
          .where((h) => h.latitude != 0 || h.longitude != 0)
          .map((h) => h.copyWith(
                distanceKm: _haversineKm(
                  latitude,
                  longitude,
                  h.latitude,
                  h.longitude,
                ),
              ))
          .toList()
        ..sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));

      final inRange = ranked
          .where((h) => (h.distanceKm ?? double.infinity) <= radiusInKm)
          .toList();

      return inRange.isNotEmpty ? inRange : ranked.take(10).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching nearby hospitals: $e');
      }
      throw Exception('Failed to load nearby hospitals: $e');
    }
  }

  /// Great-circle distance between two lat/lng points, in kilometres.
  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    double toRad(double deg) => deg * math.pi / 180.0;

    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // -------------------------
  // Notifications Management
  // -------------------------

  /// Add a new notification.
  ///
  /// [type] is `'alert'` (default) for user-facing alerts or `'tip'` for health
  /// tips — both live in the single `notifications` table.
  Future<void> addNotification({
    required String title,
    required String message,
    String type = 'alert',
    String? userId,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'title': title,
        'message': message,
        'type': type,
        if (userId != null) 'user_id': userId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error adding notification: $e');
      }
      throw Exception('Failed to add notification: $e');
    }
  }

  /// Fetch alert notifications (type = 'alert'), optionally filtered by user.
  /// Health tips (type = 'tip') are excluded here — see [getHealthTips].
  Future<List<Map<String, dynamic>>> getNotifications({String? userId}) async {
    try {
      var filter =
          supabase.from('notifications').select().eq('type', 'alert');

      if (userId != null && userId.isNotEmpty) {
        filter = filter.eq('user_id', userId);
      }

      final response =
          await filter.order('created_at', ascending: false);
      return response.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching notifications: $e');
      }
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  /// Delete a notification by ID.
  Future<void> deleteNotification(String id) async {
    try {
      await supabase.from('notifications').delete().eq('id', id);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting notification: $e');
      }
      throw Exception('Failed to delete notification: $e');
    }
  }

  // -------------------------
  // Profiles
  // -------------------------

  /// The signed-in user's profile row, or null if not signed in / no row yet.
  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      return await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching profile: $e');
      }
      return null;
    }
  }

  /// Create or update the signed-in user's profile row.
  Future<void> upsertMyProfile({
    String? fullName,
    bool? dailyNotificationsEnabled,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'updated_at': DateTime.now().toIso8601String(),
        if (fullName != null) 'full_name': fullName,
        if (dailyNotificationsEnabled != null)
          'daily_notifications_enabled': dailyNotificationsEnabled,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating profile: $e');
      }
      rethrow;
    }
  }

  /// All notification rows of a given [type] ('alert' or 'tip'), newest first.
  /// Used by the admin panel to list / delete existing content.
  Future<List<Map<String, dynamic>>> getContentByType(String type) async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('type', type)
          .order('created_at', ascending: false);
      return response.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching $type content: $e');
      }
      throw Exception('Failed to fetch content: $e');
    }
  }

  /// Fetch health tips — rows in `notifications` with type = 'tip'.
  Future<List<String>> getHealthTips() async {
    try {
      final response = await supabase
          .from('notifications')
          .select('message')
          .eq('type', 'tip')
          .eq('active', true)
          .order('created_at', ascending: false);

      return response.map((row) => row['message'] as String).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching health tips: $e');
      }
      throw Exception('Failed to fetch health tips: $e');
    }
  }
}

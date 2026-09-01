// lib/hospital.dart
import 'package:collection/collection.dart';

class Hospital {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String phoneNumber;

  /// From the `services` table (embedded) or the legacy text column.
  final List<String> services;

  /// From the `specialties` table (embedded) or the legacy `professions` column.
  final List<String> specialties;

  /// Free-form text column on `hospitals` (not normalized).
  final List<String> diseases;

  /// Distance from the user's current location in km.
  /// Transient: only populated by nearby-search results, not persisted.
  final double? distanceKm;

  /// Optional display fields. Rendered only when the backing column exists.
  final double? rating;
  final int? reviewCount;
  final String? imageUrl;
  final bool? isOpen;

  Hospital({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phoneNumber,
    required this.services,
    required this.specialties,
    required this.diseases,
    this.distanceKm,
    this.rating,
    this.reviewCount,
    this.imageUrl,
    this.isOpen,
  });

  /// First service, used as a short category label on cards.
  String? get category => services.isNotEmpty ? services.first : null;

  /// Everything searchable about this hospital, lower-cased.
  String get _haystack => [
        name,
        address,
        ...services,
        ...specialties,
        ...diseases,
      ].join(' ').toLowerCase();

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return _haystack.contains(q);
  }

  /// Build from a Supabase row.
  ///
  /// Handles both shapes:
  ///  - normalized: `services` / `specialties` come back as `[{name: 'X'}, ...]`
  ///    from a PostgREST embed;
  ///  - legacy: they are `text` columns like `[A, B, C]` or `A,B,C`.
  factory Hospital.fromMap(Map<String, dynamic> map) {
    return Hospital(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown Hospital',
      address: map['address']?.toString() ?? 'No address available',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      phoneNumber: map['phone_number']?.toString() ?? 'N/A',
      services: _parseTags(map['services']),
      specialties: _parseTags(map['specialties'] ?? map['professions']),
      diseases: _parseTags(map['diseases']),
      rating: (map['rating'] as num?)?.toDouble(),
      reviewCount: (map['review_count'] as num?)?.toInt(),
      imageUrl: map['image_url']?.toString(),
      isOpen: map['is_open'] is bool ? map['is_open'] as bool : null,
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
    );
  }

  static List<String> _parseTags(dynamic value) {
    if (value == null) return const [];

    // Embedded rows: [{name: 'X'}, {name: 'Y'}]
    if (value is List) {
      return value
          .map((e) {
            if (e is Map) return (e['name'] ?? '').toString().trim();
            return e.toString().trim();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Legacy text column: "[A, B, C]" or "A,B,C"
    if (value is String) {
      final stripped = value.replaceAll(RegExp(r'^\s*\[|\]\s*$'), '').trim();
      if (stripped.isEmpty) return const [];
      return stripped
          .split(',')
          .map((e) => e.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return const [];
  }

  /// Columns that live directly on the `hospitals` row (no child tables).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone_number': phoneNumber,
      'diseases': diseases.join(','),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  Hospital copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? phoneNumber,
    List<String>? services,
    List<String>? specialties,
    List<String>? diseases,
    double? distanceKm,
    double? rating,
    int? reviewCount,
    String? imageUrl,
    bool? isOpen,
  }) {
    return Hospital(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      services: services ?? this.services,
      specialties: specialties ?? this.specialties,
      diseases: diseases ?? this.diseases,
      distanceKm: distanceKm ?? this.distanceKm,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      imageUrl: imageUrl ?? this.imageUrl,
      isOpen: isOpen ?? this.isOpen,
    );
  }

  @override
  String toString() {
    return 'Hospital(id: $id, name: $name, address: $address, '
        'lat: $latitude, lng: $longitude, phone: $phoneNumber, '
        'services: $services, specialties: $specialties, diseases: $diseases)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Hospital &&
        other.id == id &&
        other.name == name &&
        other.address == address &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.phoneNumber == phoneNumber &&
        const ListEquality().equals(other.services, services) &&
        const ListEquality().equals(other.specialties, specialties) &&
        const ListEquality().equals(other.diseases, diseases);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        address.hashCode ^
        latitude.hashCode ^
        longitude.hashCode ^
        phoneNumber.hashCode ^
        const ListEquality().hash(services) ^
        const ListEquality().hash(specialties) ^
        const ListEquality().hash(diseases);
  }
}

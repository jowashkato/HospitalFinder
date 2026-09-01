import 'package:flutter/material.dart';
import 'package:location/location.dart';

import 'app_theme.dart';
import 'hospital.dart';
import 'hospital_card.dart';
import 'supabase_service.dart';

/// A scrollable list of hospitals with an app bar. Used for the "Hospitals"
/// category and for "hospitals that offer service X / specialty Y".
class HospitalListPage extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<List<Hospital>> Function() load;

  const HospitalListPage({
    super.key,
    required this.title,
    required this.load,
    this.subtitle,
  });

  @override
  State<HospitalListPage> createState() => _HospitalListPageState();
}

class _HospitalListPageState extends State<HospitalListPage> {
  late Future<List<Hospital>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> _refresh() async {
    final f = widget.load();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: FutureBuilder<List<Hospital>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              );
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text('No hospitals found.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              itemCount: items.length + (widget.subtitle == null ? 0 : 1),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (widget.subtitle != null && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.subtitle!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  );
                }
                final hospital =
                    items[i - (widget.subtitle == null ? 0 : 1)];
                return HospitalCard(hospital: hospital);
              },
            );
          },
        ),
      ),
    );
  }
}

enum TagKind { service, specialty }

/// A list of service / specialty names with a hospital count. Tapping one opens
/// a [HospitalListPage] filtered to hospitals that have that tag.
class TagListPage extends StatefulWidget {
  final String title;
  final TagKind kind;

  const TagListPage({super.key, required this.title, required this.kind});

  @override
  State<TagListPage> createState() => _TagListPageState();
}

class _TagListPageState extends State<TagListPage> {
  final SupabaseService _service = SupabaseService();
  late Future<List<({String name, int count})>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<({String name, int count})>> _load() =>
      widget.kind == TagKind.service
          ? _service.getServiceCounts()
          : _service.getSpecialtyCounts();

  void _openTag(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalListPage(
          title: name,
          subtitle: widget.kind == TagKind.service
              ? 'Hospitals offering $name'
              : 'Hospitals with $name',
          load: () => _service.getHospitalsByTag(
            service: widget.kind == TagKind.service ? name : null,
            specialty: widget.kind == TagKind.specialty ? name : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.kind == TagKind.service
        ? Icons.medical_services_rounded
        : Icons.person_rounded;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => setState(() => _future = _load()),
        child: FutureBuilder<List<({String name, int count})>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text('Error: ${snap.error}',
                      style: const TextStyle(color: Colors.red)),
                ),
              ]);
            }
            final tags = snap.data ?? const [];
            if (tags.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text('Nothing here yet.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              itemCount: tags.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = tags[i];
                return GestureDetector(
                  onTap: () => _openTag(t.name),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: AppColors.tipCardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          t.count == 1 ? '1 hospital' : '${t.count} hospitals',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search: a field + live results filtered over every hospital.
// ---------------------------------------------------------------------------

class SearchPage extends StatefulWidget {
  final String initialQuery;
  const SearchPage({super.key, this.initialQuery = ''});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SupabaseService _service = SupabaseService();
  final TextEditingController _controller = TextEditingController();
  late Future<List<Hospital>> _all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _all = _service.getHospitals();
    _controller.text = widget.initialQuery;
    _query = widget.initialQuery.trim();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: widget.initialQuery.isEmpty,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Hospital, service, specialty, disease…',
                    hintStyle: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13.5),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 18),
                ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<List<Hospital>>(
        future: _all,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          final all = snap.data ?? const [];
          if (_query.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Type to search hospitals by name, service,\nspecialty, disease or location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            );
          }
          final results =
              all.where((h) => h.matchesQuery(_query)).toList();
          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No matches for “$_query”.',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => HospitalCard(hospital: results[i]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nearby: request location, then show hospitals ordered by distance.
// ---------------------------------------------------------------------------

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  final SupabaseService _service = SupabaseService();
  Future<List<Hospital>>? _future;
  String? _message;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _locateAndLoad();
  }

  Future<void> _locateAndLoad() async {
    setState(() {
      _busy = true;
      _message = null;
      _future = null;
    });
    try {
      final location = Location();

      if (!await location.serviceEnabled()) {
        if (!await location.requestService()) {
          _fail('Location is turned off. Enable GPS / location and try again.');
          return;
        }
      }

      var permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        _fail('Location permission is required to find hospitals near you.');
        return;
      }

      final pos = await location.getLocation();
      final lat = pos.latitude;
      final lng = pos.longitude;
      if (lat == null || lng == null) {
        _fail('Could not read your location. Please try again.');
        return;
      }

      setState(() {
        _busy = false;
        _future = _service.getNearbyHospitals(latitude: lat, longitude: lng);
      });
    } catch (e) {
      _fail('Location error: $e');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Nearby hospitals'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_busy) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 14),
            Text('Getting your location…',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_message != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 14),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _locateAndLoad,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _locateAndLoad,
      child: FutureBuilder<List<Hospital>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            ]);
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return ListView(children: const [
              Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text('No hospitals found.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => HospitalCard(hospital: items[i]),
          );
        },
      ),
    );
  }
}

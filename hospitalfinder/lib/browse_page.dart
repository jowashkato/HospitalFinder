import 'package:flutter/material.dart';

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

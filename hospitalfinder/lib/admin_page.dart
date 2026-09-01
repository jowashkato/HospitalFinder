// lib/admin_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'hospital.dart';
import 'supabase_service.dart';

/// Admin-only content manager. Visibility is gated in ProfilePage; writes are
/// enforced by the `is_admin()` RLS policies on the Supabase tables.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: AppBar(
          title: const Text('Admin panel'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Hospitals'),
              Tab(text: 'Health tips'),
              Tab(text: 'Alerts'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HospitalsTab(),
            _ContentTab(type: 'tip'),
            _ContentTab(type: 'alert'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hospitals: list + add / edit / delete
// ---------------------------------------------------------------------------

class _HospitalsTab extends StatefulWidget {
  const _HospitalsTab();

  @override
  State<_HospitalsTab> createState() => _HospitalsTabState();
}

class _HospitalsTabState extends State<_HospitalsTab> {
  final SupabaseService _service = SupabaseService();
  late Future<List<Hospital>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getHospitals();
  }

  void _reload() => setState(() => _future = _service.getHospitals());

  Future<void> _openForm([Hospital? hospital]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HospitalFormPage(hospital: hospital)),
    );
    if (changed == true) _reload();
  }

  Future<void> _delete(Hospital h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete hospital?'),
        content: Text(
            '"${h.name}" and its services / specialties will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteHospital(h.id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add hospital'),
      ),
      body: FutureBuilder<List<Hospital>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(
                child: Text('No hospitals yet. Tap "Add hospital".',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final h = items[i];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.only(left: 16, right: 4),
                  title: Text(h.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  subtitle: Text(
                    h.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.primary),
                        onPressed: () => _openForm(h),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFDC2626)),
                        onPressed: () => _delete(h),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hospital add / edit form
// ---------------------------------------------------------------------------

class HospitalFormPage extends StatefulWidget {
  final Hospital? hospital;
  const HospitalFormPage({super.key, this.hospital});

  @override
  State<HospitalFormPage> createState() => _HospitalFormPageState();
}

class _HospitalFormPageState extends State<HospitalFormPage> {
  final SupabaseService _service = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _phone;
  late final TextEditingController _diseases;
  late final TextEditingController _services;
  late final TextEditingController _specialties;

  bool _saving = false;

  bool get _isEdit => widget.hospital != null;

  @override
  void initState() {
    super.initState();
    final h = widget.hospital;
    _name = TextEditingController(text: h?.name ?? '');
    _address = TextEditingController(
        text: (h?.address == null || h?.address == 'No address available')
            ? ''
            : h!.address);
    _lat = TextEditingController(
        text: (h != null && h.latitude != 0) ? '${h.latitude}' : '');
    _lng = TextEditingController(
        text: (h != null && h.longitude != 0) ? '${h.longitude}' : '');
    _phone = TextEditingController(
        text: (h?.phoneNumber == null || h?.phoneNumber == 'N/A')
            ? ''
            : h!.phoneNumber);
    _diseases = TextEditingController(text: h?.diseases.join(', ') ?? '');
    _services = TextEditingController(text: h?.services.join(', ') ?? '');
    _specialties =
        TextEditingController(text: h?.specialties.join(', ') ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _lat,
      _lng,
      _phone,
      _diseases,
      _services,
      _specialties,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _parseList(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    try {
      final services = _parseList(_services.text);
      final specialties = _parseList(_specialties.text);
      final diseases = _parseList(_diseases.text);
      final lat = double.parse(_lat.text.trim());
      final lng = double.parse(_lng.text.trim());

      if (_isEdit) {
        final id = widget.hospital!.id;
        await _service.updateHospital(id, {
          'name': _name.text.trim(),
          'address': _address.text.trim(),
          'latitude': lat,
          'longitude': lng,
          'phone_number': _phone.text.trim(),
          'diseases': diseases.join(','),
        });
        await _service.replaceHospitalTags(
          id,
          services: services,
          specialties: specialties,
        );
      } else {
        await _service.addHospital(
          name: _name.text.trim(),
          address: _address.text.trim(),
          latitude: lat,
          longitude: lng,
          userId: userId,
          phoneNumber: _phone.text.trim(),
          diseases: diseases,
          services: services,
          specialties: specialties,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit hospital' : 'Add hospital'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _text(_name, 'Name', required: true),
            _text(_address, 'Address'),
            Row(
              children: [
                Expanded(
                    child: _text(_lat, 'Latitude',
                        number: true, required: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: _text(_lng, 'Longitude',
                        number: true, required: true)),
              ],
            ),
            _text(_phone, 'Phone number'),
            _text(_services, 'Services (comma separated)',
                hint: 'Maternity, Emergency, Pharmacy'),
            _text(_specialties, 'Specialties (comma separated)',
                hint: 'Pediatrics, Cardiology'),
            _text(_diseases, 'Diseases treated (comma separated)',
                hint: 'Malaria, Typhoid'),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white))
                    : Text(_isEdit ? 'Save changes' : 'Create hospital'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(
                decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: (v) {
          final value = (v ?? '').trim();
          if (required && value.isEmpty) return 'Required';
          if (number && value.isNotEmpty && double.tryParse(value) == null) {
            return 'Enter a valid number';
          }
          return null;
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Health tips / alerts: add + delete
// ---------------------------------------------------------------------------

class _ContentTab extends StatefulWidget {
  final String type; // 'tip' or 'alert'
  const _ContentTab({required this.type});

  @override
  State<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<_ContentTab> {
  final SupabaseService _service = SupabaseService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _message = TextEditingController();

  late Future<List<Map<String, dynamic>>> _future;
  bool _saving = false;

  bool get _isTip => widget.type == 'tip';

  @override
  void initState() {
    super.initState();
    _future = _service.getContentByType(widget.type);
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _future = _service.getContentByType(widget.type));

  Future<void> _add() async {
    final msg = _message.text.trim();
    if (msg.isEmpty) return;
    setState(() => _saving = true);

    String title;
    if (_isTip) {
      title = 'Health Tip';
    } else {
      title = _title.text.trim().isEmpty ? 'Alert' : _title.text.trim();
    }

    try {
      await _service.addNotification(
        title: title,
        message: msg,
        type: widget.type,
      );
      if (!mounted) return;
      _title.clear();
      _message.clear();
      FocusScope.of(context).unfocus();
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _service.deleteNotification(id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isTip)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Alert title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              TextField(
                controller: _message,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: _isTip ? 'Health tip text' : 'Alert message',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _saving ? null : _add,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isTip ? 'Add health tip' : 'Publish alert'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isTip ? 'Existing tips' : 'Sent alerts',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary)),
              );
            }
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Nothing here yet.',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }
            return Column(
              children: [
                for (final r in rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListTile(
                      title: Text(r['title']?.toString() ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      subtitle: Text(r['message']?.toString() ?? '',
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFDC2626)),
                        onPressed: () => _delete(r['id'].toString()),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

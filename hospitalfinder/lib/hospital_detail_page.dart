import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'hospital.dart';

// FlutterMap imports
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latlng;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HospitalDetailPage extends StatefulWidget {
  final Hospital hospital;

  const HospitalDetailPage({super.key, required this.hospital});

  @override
  State<HospitalDetailPage> createState() => _HospitalDetailPageState();
}

class _HospitalDetailPageState extends State<HospitalDetailPage> {
  @override
  Widget build(BuildContext context) {
    final double lat = (widget.hospital.latitude != 0.0)
        ? widget.hospital.latitude
        : 0.3476; // fallback to Entebbe
    final double lng = (widget.hospital.longitude != 0.0)
        ? widget.hospital.longitude
        : 32.5825; // fallback to Kampala

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hospital.name.isNotEmpty
            ? widget.hospital.name
            : 'Hospital'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header photo (shown only when the hospital has an image_url)
            if (widget.hospital.imageUrl != null &&
                widget.hospital.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.hospital.imageUrl!,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // Map widget
            Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: fmap.FlutterMap(
                  options: fmap.MapOptions(
                    initialCenter: latlng.LatLng(lat, lng),
                    initialZoom: 14,
                  ),
                  children: [
                    fmap.TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.jowash.hospitalfinder',
                    ),
                    fmap.MarkerLayer(
                      markers: [
                        fmap.Marker(
                          point: latlng.LatLng(lat, lng),
                          child: const Icon(
                            Icons.local_hospital,
                            color: Colors.red,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Address
            _buildInfoCard(
              'Address',
              widget.hospital.address.isNotEmpty
                  ? widget.hospital.address
                  : 'No address available',
              Icons.location_on,
            ),

            // Phone number with Call + WhatsApp
            if (widget.hospital.phoneNumber.isNotEmpty &&
                widget.hospital.phoneNumber != 'N/A')
              Column(
                children: [
                  _buildInfoCard(
                    'Contact',
                    widget.hospital.phoneNumber,
                    Icons.phone,
                    onTap: () =>
                        _launchUrl('tel:${widget.hospital.phoneNumber}'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _launchUrl('tel:${widget.hospital.phoneNumber}'),
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          final formatted = _formatWhatsAppNumber(
                              widget.hospital.phoneNumber);
                          _launchUrl('https://wa.me/$formatted');
                        },
                        icon: const FaIcon(FontAwesomeIcons.whatsapp),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 16),

            _buildSectionTitle('Services Offered'),
            _buildChipWrap(widget.hospital.services, AppColors.tipCardBg),

            const SizedBox(height: 16),

            _buildSectionTitle('Diseases Treated'),
            _buildChipWrap(widget.hospital.diseases, Colors.blue[50]),

            const SizedBox(height: 16),

            _buildSectionTitle('Specialties'),
            _buildChipWrap(widget.hospital.specialties, Colors.purple[50]),

            const SizedBox(height: 24),

            // Directions button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchUrl(
                  'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                ),
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon,
      {VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(content),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildChipWrap(List<String> items, Color? color) {
    if (items.isEmpty) {
      return const Text('No data available');
    }
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: items
          .map((item) => Chip(
                label: Text(item),
                backgroundColor: color,
              ))
          .toList(),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Show SnackBar if launch fails
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Helper to format WhatsApp numbers correctly
  String _formatWhatsAppNumber(String number) {
    // Remove spaces, dashes, parentheses, and plus signs
    var cleaned = number.replaceAll(RegExp(r'[^\d]'), '');
    // If number starts with 0, replace with country code (Uganda = 256)
    if (cleaned.startsWith('0')) {
      cleaned = '256${cleaned.substring(1)}';
    }
    return cleaned;
  }
}

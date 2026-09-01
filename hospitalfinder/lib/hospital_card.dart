import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'hospital.dart';
import 'hospital_detail_page.dart';

/// Tappable summary card for a hospital. Opens [HospitalDetailPage] on tap.
class HospitalCard extends StatelessWidget {
  final Hospital hospital;
  const HospitalCard({super.key, required this.hospital});

  String get _subtitle {
    final parts = <String>[];
    if (hospital.category != null) parts.add(hospital.category!);
    if (hospital.distanceKm != null) {
      parts.add('${hospital.distanceKm!.toStringAsFixed(1)} km');
    } else if (hospital.address.isNotEmpty &&
        hospital.address != 'No address available') {
      parts.add(hospital.address);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HospitalDetailPage(hospital: hospital),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hospital.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (hospital.rating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 16, color: AppColors.star),
                        const SizedBox(width: 2),
                        Text(
                          hospital.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (hospital.reviewCount != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${hospital.reviewCount})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                      const Spacer(),
                      _buildStatusBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final placeholder = Container(
      height: 64,
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.tipCardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary),
    );

    if (hospital.imageUrl == null || hospital.imageUrl!.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        hospital.imageUrl!,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (hospital.isOpen == null) return const SizedBox.shrink();
    final open = hospital.isOpen!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: open ? AppColors.openBg : const Color(0xFFF1F1F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        open ? 'Open' : 'Closed',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: open ? AppColors.openText : AppColors.textSecondary,
        ),
      ),
    );
  }
}

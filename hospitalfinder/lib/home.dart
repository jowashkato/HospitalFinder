import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'browse_page.dart';
import 'hospital.dart';
import 'hospital_card.dart';
import 'supabase_service.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseService _supabaseService = SupabaseService();
  late Future<List<Hospital>> _hospitalsFuture;

  int _navIndex = 0;
  String? _firstName;

  final List<_Category> _categories = const [
    _Category('Hospitals', Icons.local_hospital_rounded, AppColors.catHospitals),
    _Category('Services', Icons.medical_services_rounded, AppColors.catServices),
    _Category('Doctors', Icons.person_rounded, AppColors.catDoctors),
    _Category('Health Tips', Icons.lightbulb_rounded, AppColors.catTips),
  ];

  @override
  void initState() {
    super.initState();
    _hospitalsFuture = _supabaseService.getHospitals();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final profile = await _supabaseService.getMyProfile();
    if (!mounted) return;
    final name = (profile?['full_name'] as String?)?.trim();
    setState(() {
      _firstName = (name != null && name.isNotEmpty)
          ? name.split(RegExp(r'\s+')).first
          : null;
    });
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _openSearch([String query = '']) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(initialQuery: query.trim()),
      ),
    );
  }

  void _openNearby() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NearbyPage()),
    );
  }

  Future<void> _refresh() async {
    final future = _supabaseService.getHospitals();
    setState(() => _hospitalsFuture = future);
    await future;
  }

  void _onCategoryTap(String label) {
    switch (label) {
      case 'Hospitals':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HospitalListPage(
              title: 'Hospitals',
              load: () => _supabaseService.getHospitals(),
            ),
          ),
        );
        break;
      case 'Services':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TagListPage(
              title: 'Services',
              kind: TagKind.service,
            ),
          ),
        );
        break;
      case 'Doctors':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TagListPage(
              title: 'Doctors & Specialties',
              kind: TagKind.specialty,
            ),
          ),
        );
        break;
      case 'Health Tips':
        _showHealthTips();
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Bottom sheets
  // ---------------------------------------------------------------------------

  Future<void> _showHealthTips() async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => FutureBuilder<List<String>>(
        future: _supabaseService.getHealthTips(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final tips = snapshot.data ?? const [];
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text('Health Tips',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (tips.isEmpty)
                const Text('No tips available right now.')
              else
                ...tips.map(
                  (t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showNotifications() async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _supabaseService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final items = snapshot.data ?? const [];
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text('Alerts',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Text('You have no alerts yet.')
              else
                ...items.map(
                  (n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.tipCardBg,
                      child: Icon(Icons.notifications_rounded,
                          color: AppColors.primary),
                    ),
                    title: Text(n['title']?.toString() ?? 'Notification',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(n['message']?.toString() ?? ''),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      ).then((_) {
        if (!mounted) return;
        setState(() => _navIndex = 0);
        _loadUserName();
      });
      return;
    }
    switch (index) {
      case 1:
        _openSearch();
        if (mounted) setState(() => _navIndex = 0);
        break;
      case 2:
        setState(() => _navIndex = 2);
        _showNotifications();
        break;
      default:
        setState(() => _navIndex = index);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  const _SectionTitle('Categories'),
                  const SizedBox(height: 16),
                  _buildCategoryRow(),
                  const SizedBox(height: 26),
                  _buildTipCard(),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _SectionTitle('Top Rated'),
                      GestureDetector(
                        onTap: _openSearch,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Text(
                            'See all',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildHospitalList(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x336D3BE4),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: Stack(
          children: [
            // Decorative translucent circles
            Positioned(
              top: -40,
              right: -30,
              child: _decorCircle(140, Colors.white.withOpacity(0.08)),
            ),
            Positioned(
              top: 40,
              right: 60,
              child: _decorCircle(70, Colors.white.withOpacity(0.06)),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _firstName == null
                                  ? '$_greeting 👋'
                                  : '$_greeting, $_firstName 👋',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Find Your Care',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _onNavTap(3),
                          child: Container(
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.35)),
                            ),
                            child: const Icon(Icons.person_outline_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildNearbyButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: _openSearch,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F231147),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: 16, right: 6),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Hospital, service, or disease…',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ElevatedButton(
                onPressed: _openSearch,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('Search'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openNearby,
        icon: const Icon(Icons.near_me_rounded,
            color: Colors.white, size: 19),
        label: const Text(
          'Find Nearby Hospitals',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.18),
          side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    return Row(
      children: [
        for (final c in _categories)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => _onCategoryTap(c.label),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        color: c.color,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: c.color.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(c.icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tipCardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.water_drop_rounded,
                color: AppColors.tipAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'TIP OF THE DAY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Stay Hydrated',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Drink at least 8 glasses of water daily to '
                  'maintain optimal body function.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalList() {
    return FutureBuilder<List<Hospital>>(
      future: _hospitalsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }
        final hospitals = snapshot.data ?? const [];
        if (hospitals.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No hospitals found.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: hospitals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              HospitalCard(hospital: hospitals[index]),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: AppColors.tipCardBg,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          selectedIndex: _navIndex,
          onDestinationSelected: _onNavTap,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'Search'),
            NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications_rounded),
                label: 'Alerts'),
            NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

class _Category {
  final String label;
  final IconData icon;
  final Color color;
  const _Category(this.label, this.icon, this.color);
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }
}

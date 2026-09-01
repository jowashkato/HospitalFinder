// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_page.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'supabase_service.dart';
import 'main.dart'; // scheduleDailyNotification / cancelDailyNotification

/// Profile tab. Shows the sign-in / register panel when logged out, and the
/// account + notification preferences when logged in.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<AuthState>(
        stream: auth.authStateChanges,
        builder: (context, _) {
          return auth.isSignedIn ? const _SignedInView() : const _AuthPanel();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Signed-in: account details + daily-notification preference
// ---------------------------------------------------------------------------

class _SignedInView extends StatefulWidget {
  const _SignedInView();

  @override
  State<_SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends State<_SignedInView> {
  final AuthService _auth = AuthService();
  final SupabaseService _service = SupabaseService();

  bool _loading = true;
  bool _busy = false;
  String? _fullName;
  bool _dailyEnabled = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _service.getMyProfile();
    if (!mounted) return;
    setState(() {
      _fullName = profile?['full_name'] as String?;
      _dailyEnabled =
          (profile?['daily_notifications_enabled'] as bool?) ?? true;
      _isAdmin = (profile?['is_admin'] as bool?) ?? false;
      _loading = false;
    });
    if (profile == null) {
      // The signup trigger may not have created a row yet — make one.
      await _service.upsertMyProfile(dailyNotificationsEnabled: true);
    }
  }

  Future<void> _toggleDaily(bool value) async {
    setState(() {
      _dailyEnabled = value;
      _busy = true;
    });
    try {
      await _service.upsertMyProfile(dailyNotificationsEnabled: value);
      if (value) {
        await scheduleDailyNotification();
      } else {
        await cancelDailyNotification();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value
              ? 'Daily health tips turned on'
              : 'Daily health tips turned off'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dailyEnabled = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update preference: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    // The parent StreamBuilder rebuilds into the sign-in panel.
  }

  String get _initials {
    final name = (_fullName ?? '').trim();
    final source = name.isNotEmpty ? name : (_auth.currentUser?.email ?? '?');
    final parts =
        source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) => s.isEmpty ? '' : s.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return (first(parts.first) + first(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    final email = _auth.currentUser?.email ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                height: 84,
                width: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                (_fullName?.trim().isNotEmpty ?? false)
                    ? _fullName!.trim()
                    : 'Your account',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(email,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: SwitchListTile.adaptive(
            value: _dailyEnabled,
            onChanged: _busy ? null : _toggleDaily,
            activeColor: AppColors.primary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: const Text('Daily health notifications',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            subtitle: const Text('A wellness tip every morning at 10 AM',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ),
        ),
        if (_isAdmin) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.admin_panel_settings_outlined,
                  color: AppColors.primary),
              title: const Text('Admin panel',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              subtitle: const Text('Add hospitals, health tips and alerts',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPage()),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFF0C4C4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Signed-out: sign in / register panel
// ---------------------------------------------------------------------------

class _AuthPanel extends StatefulWidget {
  const _AuthPanel();

  @override
  State<_AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<_AuthPanel> {
  final AuthService _auth = AuthService();
  final SupabaseService _service = SupabaseService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = true;
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty || (_isRegister && name.isEmpty)) {
      setState(() {
        _error = 'Please fill in all fields.';
        _info = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _error = 'Password must be at least 6 characters.';
        _info = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      if (_isRegister) {
        final res = await _auth.register(
            fullName: name, email: email, password: password);
        if (res.session != null) {
          // Email confirmation disabled -> user is signed in immediately.
          await _service.upsertMyProfile(
              fullName: name, dailyNotificationsEnabled: true);
          await scheduleDailyNotification();
          // Parent StreamBuilder swaps to the signed-in view.
        } else {
          setState(() {
            _loading = false;
            _isRegister = false;
            _info =
                'Account created. Check your email to confirm, then sign in.';
          });
        }
      } else {
        await _auth.signIn(email: email, password: password);
        final profile = await _service.getMyProfile();
        if (profile == null) {
          await _service.upsertMyProfile(dailyNotificationsEnabled: true);
        }
        final wantDaily =
            (profile?['daily_notifications_enabled'] as bool?) ?? true;
        if (wantDaily) {
          await scheduleDailyNotification();
        } else {
          await cancelDailyNotification();
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() =>
          _error = 'Enter your email first, then tap "Forgot password".');
      return;
    }
    try {
      await _auth.sendPasswordReset(email);
      setState(() {
        _error = null;
        _info = 'Password reset link sent to $email.';
      });
    } catch (_) {
      setState(() => _error = 'Could not send the reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _gradientHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14231147),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isRegister)
                    _field(
                      controller: _nameController,
                      label: 'Full name',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                    ),
                  _field(
                    controller: _emailController,
                    label: 'Email address',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  _field(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFDC2626), fontSize: 12.5)),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 4),
                    Text(_info!,
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isRegister ? 'Create account' : 'Sign in'),
                    ),
                  ),
                  if (!_isRegister)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text('Forgot password?',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRegister
                            ? 'Already have an account?'
                            : "Don't have an account?",
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _isRegister = !_isRegister;
                          _error = null;
                          _info = null;
                        }),
                        child: Text(_isRegister ? 'Sign in' : 'Register'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            _isRegister ? 'Create your account' : 'Welcome back',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isRegister
                ? 'Register to get daily health tips and alerts'
                : 'Sign in to manage your health notifications',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.85), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
          suffixIcon: suffix,
          filled: true,
          fillColor: AppColors.scaffold,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

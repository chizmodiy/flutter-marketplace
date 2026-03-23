import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_login_page.dart';
import 'admin_dashboard_page.dart';

class AdminDashboardGuard extends StatefulWidget {
  const AdminDashboardGuard({super.key});

  @override
  State<AdminDashboardGuard> createState() => _AdminDashboardGuardState();
}

class _AdminDashboardGuardState extends State<AdminDashboardGuard> {
  bool _isChecking = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isAdmin = false;
        });
      }
      return;
    }
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _isChecking = false;
        _isAdmin = profile != null && profile['role'] == 'admin';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminLoginPage()),
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const AdminDashboardPage();
  }
}

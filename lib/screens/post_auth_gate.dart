import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// After sign-in / splash: send incomplete profiles through onboarding.
class PostAuthGate extends StatefulWidget {
  const PostAuthGate({super.key});

  @override
  State<PostAuthGate> createState() => _PostAuthGateState();
}

class _PostAuthGateState extends State<PostAuthGate> {
  final _profiles = UserProfileService();

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    try {
      final needs = await _profiles.needsOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, animation, _) =>
              needs ? const OnboardingScreen() : const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.foam,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService.signInWithGoogle();
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo / branding
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Cannon Butchery',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tracker',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: kPrimary,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Personal butchery management',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
              const Spacer(flex: 3),
              // Google sign in button
              _loading
                  ? const CircularProgressIndicator(color: kPrimary)
                  : SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _signIn,
                        icon: Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.login, size: 20),
                        ),
                        label: const Text('Sign in with Google'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kCardRadius),
                          ),
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                          foregroundColor: Colors.black87,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),
              Text(
                'Sign in once — your data syncs across all your devices.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

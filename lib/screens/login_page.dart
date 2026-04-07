import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'employee_dashboard.dart';
import 'auditor_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      if (mounted && response.user != null) {
        if (_emailController.text.trim().toLowerCase() == 'admin@aetheris.com') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuditorDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EmployeeDashboard()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Authentication Failed: ${e.toString().split('] ').last}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Left Side - Clean Branding
          if (isDesktop)
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.95),
                      AppTheme.primary.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 96,
                      ),
                      SizedBox(height: 32),
                      Text(
                        "AETHERIS",
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6.0,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "ENTERPRISE AUDIT",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Right Side - Login Form
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48.0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isDesktop) ...[
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppTheme.primary,
                          size: 64,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "AETHERIS",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: AppTheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],

                      const Text(
                        "Welcome Back",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Sign in to your corporate account",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: "Corporate Email",
                          hintStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: "Password",
                          hintStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login Button
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: AppTheme.primaryForeground,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryForeground,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Sign In",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
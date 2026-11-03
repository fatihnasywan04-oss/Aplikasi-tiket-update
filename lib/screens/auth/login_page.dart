import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import '../admin/admin_dashboard_page.dart';
import '../user/user_shell.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _sakuraController;

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _sakuraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _sakuraController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      final result = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final user = result['user'];

      if (user == null || user is! Map<String, dynamic>) {
        throw Exception(
          'Data akun tidak ditemukan pada respons login.',
        );
      }

      final role = user['role']?.toString().trim().toLowerCase();

      late final Widget destination;

      if (role == 'admin') {
        destination = const AdminDashboardPage();
      } else if (role == 'user') {
        destination = const UserShell();
      } else {
        await ApiService.logout();

        if (!mounted) return;

        throw Exception('Peran akun tidak dikenali.');
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => destination,
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email wajib diisi';
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Masukkan alamat email yang valid';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ANIMASI KELopak SAKURA DI LATAR BELAKANG
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _sakuraController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SakuraPetalPainter(
                      progress: _sakuraController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // FORM LOGIN
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // LOGO HIKARI
                        Center(
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: AppColors.primaryPale,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        const Text(
                          'Hikari',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Masuk untuk menemukan dan memesan tiket event favoritmu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 32),

                        const Text(
                          'Email',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: _validateEmail,
                          decoration: const InputDecoration(
                            hintText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                                                const SizedBox(height: 18),

                        const Text(
                          'Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) {
                            if (!_loading) _login();
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password wajib diisi';
                            }

                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Masukkan password',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Tampilkan password'
                                  : 'Sembunyikan password',
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        FilledButton(
                          onPressed: _loading ? null : _login,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Belum punya akun? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterPage(),
                                        ),
                                      );
                                    },
                              child: const Text('Daftar'),
                            ),
                          ],
                        ),
                      ],
                    ),
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

// CUSTOM PAINTER UNTUK ANIMASI KELOPAK SAKURA
class SakuraPetalPainter extends CustomPainter {
  final double progress;

  SakuraPetalPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFFFB7C5),
      const Color(0xFFFFC1D0),
      const Color(0xFFFFD6E0),
      const Color(0xFFEFA6B8),
    ];

    for (int i = 0; i < 22; i++) {
      final phase = (i / 22.0);
      final movement = (progress + phase) % 1.0;

      final baseX = (i * 67.0 + 35) % size.width;

      final x = baseX +
          math.sin(
                (movement * 2 * math.pi) + i,
              ) *
              22;

      final y = movement * (size.height + 40) - 20;

      final rotation =
          movement * 2 * math.pi + i * 0.8;

      final petalSize = 5.0 + (i % 4) * 1.5;

      final opacity = 0.45 + (i % 3) * 0.15;

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(
          alpha: opacity,
        )
        ..style = PaintingStyle.fill;

      canvas.save();

      canvas.translate(x, y);
      canvas.rotate(rotation);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: petalSize * 1.5,
          height: petalSize,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SakuraPetalPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
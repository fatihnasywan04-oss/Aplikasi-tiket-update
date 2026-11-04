
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import '../admin/admin_dashboard_page.dart';
import '../admin_event/admin_event_dashboard_page.dart';
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

  // ============================================================
  // LOGIN
  // ============================================================

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

      final role = user['role']
          ?.toString()
          .trim()
          .toLowerCase();

      late final Widget destination;

      switch (role) {
        case 'admin':
          destination = const AdminDashboardPage();
          break;

        case 'admin_event':
          destination = const AdminEventDashboardPage();
          break;

        case 'user':
          destination = const UserShell();
          break;

        default:
          await ApiService.logout();

          if (!mounted) return;

          throw Exception(
            'Peran akun tidak dikenali: ${role ?? 'kosong'}.',
          );
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

  // ============================================================
  // VALIDASI EMAIL
  // ============================================================

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email wajib diisi';
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(email)) {
      return 'Masukkan alamat email yang valid';
    }

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // BACKGROUND JAPANESE DARK
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0B0A14),
                    Color(0xFF160D19),
                    Color(0xFF0B0A14),
                  ],
                ),
              ),
            ),
          ),

          // CAHAYA MERAH DI BELAKANG FORM
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 0.85,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.20),
                      AppColors.primary.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ANIMASI KELOPAK SAKURA
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
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xE621101B),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 35,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // LOGO HIKARI
                          Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: AppColors.gold.withValues(
                                    alpha: 0.65,
                                  ),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 22,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          const Text(
                            'HIKARI',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 29,
                              letterSpacing: 5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                            ),
                          ),

                          const SizedBox(height: 7),

                          const Text(
                            'JAPANESE EVENT EXPERIENCE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 10,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 18),

                          Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.gold.withValues(alpha: 0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          const Text(
                            'Selamat Datang',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Masuk untuk menemukan dan memesan tiket event favoritmu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 28),

                          const Text(
                            'Email',
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.email,
                            ],
                            validator: _validateEmail,
                            style: const TextStyle(
                              color: AppColors.text,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            'Password',
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.password,
                            ],
                            onFieldSubmitted: (_) {
                              if (!_loading) _login();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password wajib diisi';
                              }

                              return null;
                            },
                            style: const TextStyle(
                              color: AppColors.text,
                            ),
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
                                    _obscurePassword =
                                        !_obscurePassword;
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

                          const SizedBox(height: 28),

                          // TOMBOL MASUK
                          FilledButton(
                            onPressed: _loading ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(
                                double.infinity,
                                52,
                              ),
                              elevation: 4,
                              shadowColor: AppColors.primary.withValues(
                                alpha: 0.35,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
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
                                      'MASUK',
                                      style: TextStyle(
                                        fontSize: 15,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Flexible(
                                child: Text(
                                  'Belum punya akun? ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
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
                                child: const Text(
                                  'Daftar',
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CUSTOM PAINTER UNTUK ANIMASI KELOPAK SAKURA
// ============================================================

class SakuraPetalPainter extends CustomPainter {
  final double progress;

  SakuraPetalPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final colors = [
      const Color(0xFFF5C6D1),
      const Color(0xFFFFB7C5),
      const Color(0xFFFFD6E0),
      const Color(0xFFEFA6B8),
    ];

    for (int i = 0; i < 22; i++) {
      final phase = i / 22.0;
      final movement = (progress + phase) % 1.0;

      final baseX = (i * 67.0 + 35) % size.width;

      final x = baseX +
          math.sin((movement * 2 * math.pi) + i) * 22;

      final y = movement * (size.height + 40) - 20;

      final rotation = movement * 2 * math.pi + i * 0.8;

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
  bool shouldRepaint(
    covariant SakuraPetalPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress;
  }
}

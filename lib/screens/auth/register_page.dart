
import 'package:flutter/material.dart';

import '../../api_service.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) return 'Nama lengkap wajib diisi';
    if (name.length < 2) return 'Nama minimal 2 karakter';
    if (name.length > 100) return 'Nama maksimal 100 karakter';

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return 'Email wajib diisi';

    final emailRegex = RegExp(
      r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Format email tidak valid';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) return 'Password wajib diisi';
    if (password.length < 8) return 'Password minimal 8 karakter';
    if (password.length > 128) return 'Password maksimal 128 karakter';

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password wajib diisi';
    }

    if (value != _passwordController.text) {
      return 'Konfirmasi password tidak sama';
    }

    return null;
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Menggunakan 3 parameter positional.
      await ApiService.register(
        _nameController.text.trim(),
        _emailController.text.trim().toLowerCase(),
        _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pendaftaran berhasil! Silakan login menggunakan akun kamu.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFFE89AB5),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF191725),
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white38),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE89AB5),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100F19),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF171323),
                    Color(0xFF100F19),
                    Color(0xFF211528),
                  ],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: SakuraPetalPainter(
                    animationValue: _animationController.value,
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE89AB5)
                              .withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE89AB5)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.confirmation_num_rounded,
                          size: 38,
                          color: Color(0xFFE89AB5),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'HIKARI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Buat akun dan mulai pengalaman event-mu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF191725)
                              .withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Buat Akun',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              const Text(
                                'Lengkapi data berikut untuk mendaftar.',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),

                              const SizedBox(height: 24),

                              TextFormField(
                                controller: _nameController,
                                keyboardType: TextInputType.name,
                                textCapitalization:
                                    TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(color: Colors.white),
                                validator: _validateName,
                                decoration: _inputDecoration(
                                  label: 'Nama Lengkap',
                                  icon: Icons.person_outline,
                                ),
                              ),

                              const SizedBox(height: 18),

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                style: const TextStyle(color: Colors.white),
                                validator: _validateEmail,
                                decoration: _inputDecoration(
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                ),
                              ),

                              const SizedBox(height: 18),

                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(color: Colors.white),
                                validator: _validatePassword,
                                decoration: _inputDecoration(
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword =
                                            !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) _register();
                                },
                                style: const TextStyle(color: Colors.white),
                                validator: _validateConfirmPassword,
                                decoration: _inputDecoration(
                                  label: 'Konfirmasi Password',
                                  icon: Icons.lock_reset_outlined,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 28),

                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFE89AB5),
                                    disabledBackgroundColor:
                                        const Color(0xFFE89AB5)
                                            .withValues(alpha: 0.4),
                                    foregroundColor:
                                        const Color(0xFF241421),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 23,
                                          height: 23,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Color(0xFF241421),
                                          ),
                                        )
                                      : const Text(
                                          'DAFTAR SEKARANG',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 22),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Sudah punya akun? ',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _isLoading
                                        ? null
                                        : () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const LoginPage(),
                                              ),
                                            );
                                          },
                                    child: const Text(
                                      'Login',
                                      style: TextStyle(
                                        color: Color(0xFFE89AB5),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        '© Hikari Event Ticketing',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 11,
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

class SakuraPetalPainter extends CustomPainter {
  final double animationValue;

  SakuraPetalPainter({
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = const Color(0xFFE89AB5).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 22; i++) {
      final progress = (animationValue + i / 22) % 1.0;

      final x = (i * 67.0 + progress * 35) % size.width;
      final y = progress * size.height;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 6.28);

      final path = Path()
        ..moveTo(0, -5)
        ..quadraticBezierTo(7, -2, 0, 7)
        ..quadraticBezierTo(-7, -2, 0, -5)
        ..close();

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SakuraPetalPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

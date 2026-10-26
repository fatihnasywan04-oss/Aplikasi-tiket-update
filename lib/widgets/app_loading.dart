
import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  final String message;

  const AppLoading({
    super.key,
    this.message = 'Memuat data...',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFEAE8FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.confirmation_number_rounded,
                size: 34,
                color: Color(0xFF5B50E8),
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Color(0xFF5B50E8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF77778A)),
            ),
          ],
        ),
      ),
    );
  }
}

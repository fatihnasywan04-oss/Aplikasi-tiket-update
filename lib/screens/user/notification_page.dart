
import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: Color(0xFF9187FF),
              ),
              SizedBox(height: 16),
              Text(
                'Belum ada notifikasi',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF282738),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Informasi pesanan dan pembayaran akan ditampilkan di sini '
                'jika backend menyediakan data notifikasi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.5,
                  color: Color(0xFF77778A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

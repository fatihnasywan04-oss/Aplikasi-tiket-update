import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import 'admin_event_detail_page.dart';
import 'admin_event_form_page.dart';

class AdminEventEventsPage extends StatefulWidget {
  const AdminEventEventsPage({super.key});

  @override
  State<AdminEventEventsPage> createState() => _AdminEventEventsPageState();
}

class _AdminEventEventsPageState extends State<AdminEventEventsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadEvents();
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    final events = await ApiService.getEvents();
    final userId = await ApiService.getUserId();

    return events.where((event) {
      return event['created_by']?.toString() == userId?.toString();
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadEvents();
    });
    await _future;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Event Saya'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Buat Event'),
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminEventFormPage(),
            ),
          );

          if (result == true && mounted) {
            await _refresh();
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Gagal memuat event:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            final events = snapshot.data ?? [];

            if (events.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 150),
                  Center(
                    child: Text(
                      'Belum ada event yang dipublikasikan.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final status =
                    (event['approval_status'] ?? 'approved').toString();

                return Card(
                  color: AppTheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      event['name']?.toString() ?? 'Tanpa nama',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Status: $status',
                        style: TextStyle(color: _statusColor(status)),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminEventDetailPage(event: event),
                        ),
                      );

                      if (mounted) await _refresh();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
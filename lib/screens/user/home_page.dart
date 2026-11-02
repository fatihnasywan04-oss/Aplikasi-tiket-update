import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import '../../widgets/event_card.dart';
import '../../widgets/app_search_bar.dart';
import 'event_detail_page.dart';
import 'explore_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getEvents();

      if (!mounted) return;

      setState(() {
        _events = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _openExplore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExplorePage(
          initialQuery: _search.text.trim(),
        ),
      ),
    );
  }

  void _openEvent(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(event: event),
      ),
    );
  }

  Widget _buildEventList() {
    return SizedBox(
      height: 360,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _events.length,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 14);
        },
        itemBuilder: (context, index) {
          final event = _events[index];

          return SizedBox(
            width: 240,
            child: EventCard(
              event: event,
              onTap: () => _openEvent(event),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 12),
            const Text(
              'Event belum bisa dimuat.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 42,
                color: AppColors.primaryLight,
              ),
              SizedBox(height: 12),
              Text(
                'Belum ada event tersedia.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.confirmation_number_rounded,
                color: Colors.white,
                size: 30,
              ),
              SizedBox(width: 10),
              Text(
                'Hikari',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Temukan pengalaman seru berikutnya!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cari event, pesan tiket, dan siapkan pengalaman terbaikmu.',
            style: TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          AppSearchBar(
            controller: _search,
            hintText: 'Cari event favoritmu...',
            onChanged: (_) {},
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openExplore,
              icon: const Icon(
                Icons.search_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'Cari event',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: Colors.white70,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // HEADER
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),

            // JUDUL EVENT PILIHAN
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 14),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Event pilihan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),

            // LOADING, ERROR, KOSONG, ATAU DAFTAR EVENT
            if (_loading)
              _buildLoading()
            else if (_error != null)
              _buildError()
            else if (_events.isEmpty)
              _buildEmpty()
            else
              SliverToBoxAdapter(
                child: _buildEventList(),
              ),

            // SPACING BAWAH
            const SliverToBoxAdapter(
              child: SizedBox(height: 28),
            ),
          ],
        ),
      ),
    );
  }
}
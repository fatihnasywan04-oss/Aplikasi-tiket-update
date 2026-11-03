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
      height: 390,
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
            width: 270,
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
            color: AppColors.gold,
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
        28,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF21101B),
            Color(0xFF170F19),
            Color(0xFF0B0A14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BRAND HIKARI
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.55),
                  ),
                ),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HIKARI',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'JAPANESE EVENT EXPERIENCE',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 8,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 30),

          // HEADLINE
          const Text(
            'Temukan pengalaman\nseru berikutnya!',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 27,
              height: 1.25,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Cari event, pesan tiket, dan siapkan pengalaman terbaikmu bersama Hikari.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 23),

          // SEARCH
          AppSearchBar(
            controller: _search,
            hintText: 'Cari event favoritmu...',
            onChanged: (_) {},
          ),

          const SizedBox(height: 12),

          // SEARCH BUTTON
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openExplore,
              icon: const Icon(Icons.search_rounded),
              label: const Text(
                'Cari event',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 26, 20, 15),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.gold,
            size: 21,
          ),
          SizedBox(width: 9),
          Text(
            'Event pilihan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
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
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // HEADER HIKARI
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),

            // JUDUL EVENT
            SliverToBoxAdapter(
              child: _buildSectionTitle(),
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
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }
}
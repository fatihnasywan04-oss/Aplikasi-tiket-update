import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import '../../widgets/event_card.dart';
import 'event_detail_page.dart';

class ExplorePage extends StatefulWidget {
  final String initialQuery;

  const ExplorePage({
    super.key,
    this.initialQuery = '',
  });

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late final TextEditingController _search;

  bool _loading = true;
  List<Map<String, dynamic>> _events = [];
  String? _error;

  String _category = 'Semua';

  static const List<String> _defaultCategories = [
    'Edukasi',
    'Hiburan',
    'Travel',
    'Olahraga',
  ];

  @override
  void initState() {
    super.initState();

    _search = TextEditingController(
      text: widget.initialQuery,
    );

    _loadEvents();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.getEvents();

      if (!mounted) return;

      setState(() {
        _events = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _field(
    Map<String, dynamic> event,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = event[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _normalizeCategory(String value) {
    return value.trim().toLowerCase();
  }

  List<String> get _categories {
    final categories = <String>[
      'Semua',
      ..._defaultCategories,
    ];

    for (final event in _events) {
      final category = _field(
        event,
        ['category', 'kategori'],
      );

      if (category.isEmpty) continue;

      final alreadyExists = categories.any(
        (item) =>
            _normalizeCategory(item) ==
            _normalizeCategory(category),
      );

      if (!alreadyExists) {
        categories.add(category);
      }
    }

    return categories;
  }

  List<Map<String, dynamic>> _filteredEvents() {
    final query = _search.text.trim().toLowerCase();

    return _events.where((event) {
      final title = _field(
        event,
        ['title', 'name', 'nama_event', 'event_title'],
      ).toLowerCase();

      final location = _field(
        event,
        ['location', 'venue', 'lokasi'],
      ).toLowerCase();

      final eventCategory = _field(
        event,
        ['category', 'kategori'],
      );

      final matchesQuery = query.isEmpty ||
          title.contains(query) ||
          location.contains(query);

      final matchesCategory = _category == 'Semua' ||
          _normalizeCategory(eventCategory) ==
              _normalizeCategory(_category);

      return matchesQuery && matchesCategory;
    }).toList();
  }

  Widget _buildCategories() {
    final categories = _categories;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = categories[index];

          final selected = _normalizeCategory(_category) ==
              _normalizeCategory(item);

          return ChoiceChip(
            label: Text(item),
            selected: selected,
            showCheckmark: true,
            checkmarkColor: AppColors.gold,
            selectedColor: AppColors.primaryPale,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected
                  ? AppColors.primary
                  : AppColors.border,
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            labelStyle: TextStyle(
              color: selected
                  ? AppColors.text
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            onSelected: (_) {
              setState(() {
                _category = item;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppColors.primaryLight,
            ),
            SizedBox(height: 16),
            Text(
              'Event tidak ditemukan.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Coba kata kunci atau kategori lain.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat daftar event.',
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
            FilledButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventGrid(
    List<Map<String, dynamic>> filtered,
  ) {
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24,
        ),
        itemCount: filtered.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,

          // Memberikan ruang vertikal lebih besar
          // agar seluruh informasi kartu terlihat.
          childAspectRatio: 0.46,
        ),
        itemBuilder: (context, index) {
          final event = filtered[index];

          return EventCard(
            event: event,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailPage(
                    event: event,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEvents();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Jelajahi Event',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              24,
            ),
            child: TextField(
              controller: _search,
              onChanged: (_) {
                setState(() {});
              },
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
              ),
              cursorColor: AppColors.primary,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama atau lokasi event',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.gold,
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // FILTER KATEGORI
          _buildCategories(),

          const SizedBox(height: 12),

          // DAFTAR EVENT
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                    ),
                  )
                : _error != null
                    ? _buildErrorState()
                    : _buildEventGrid(filtered),
          ),
        ],
      ),
    );
  }
}

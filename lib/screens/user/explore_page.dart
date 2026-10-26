
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

  final List<String> _categories = const [
    'Semua',
    'Edukasi',
    'Hiburan',
    'Travel',
    'Olahraga',
  ];

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _loadEvents();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // getEvents() mengembalikan List<Map<String, dynamic>>.
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
        setState(() => _loading = false);
      }
    }
  }

  String _field(Map<String, dynamic> event, List<String> keys) {
    for (final key in keys) {
      final value = event[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase().trim();

    final filtered = _events.where((event) {
      final title = _field(
        event,
        ['title', 'name', 'nama_event', 'event_title'],
      ).toLowerCase();

      final location = _field(
        event,
        ['location', 'venue', 'lokasi'],
      ).toLowerCase();

      final category = _field(
        event,
        ['category', 'kategori'],
      ).toLowerCase();

      final matchesQuery = query.isEmpty ||
          title.contains(query) ||
          location.contains(query);

      final matchesCategory = _category == 'Semua' ||
          category == _category.toLowerCase();

      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Jelajahi Event',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama atau lokasi event',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 45,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _categories[index];

                return ChoiceChip(
                  label: Text(item),
                  selected: _category == item,
                  selectedColor: AppColors.primaryPale,
                  labelStyle: TextStyle(
                    color: _category == item
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) {
                    setState(() => _category = item);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : _error != null
                    ? Center(
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
                              const Text('Gagal memuat daftar event.'),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
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
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 54,
                                    color: AppColors.primaryLight,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Event tidak ditemukan.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Coba kata kunci atau kategori lain.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadEvents,
                            color: AppColors.primary,
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                4,
                                20,
                                20,
                              ),
                              itemCount: filtered.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.61,
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
                          ),
          ),
        ],
      ),
    );
  }
}

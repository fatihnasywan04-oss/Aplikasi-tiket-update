import 'package:flutter/material.dart';

import '../api_service.dart';
import 'login_page.dart';
import 'event_detail_page.dart';
import 'order_history_page.dart';

const Color brandColor = Color(0xFF5B50E8);
const Color backgroundColor = Color(0xFFF7F7FC);

enum EventFilter { all, upcoming, available, soldOut }

enum EventSort { nearest, cheapest, mostExpensive }

class EventListPage extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  const EventListPage({super.key, this.initialQuery, this.initialCategory});

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> events = [];
  bool isLoading = true;
  String? errorMessage;

  EventFilter selectedFilter = EventFilter.all;
  EventSort selectedSort = EventSort.nearest;
  String? selectedCategory;
  double? minimumPrice;
  double? maximumPrice;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? '';
    selectedCategory = widget.initialCategory;
    loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String cleanError(Object error) {
    return error.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
  }

  Future<void> loadEvents() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.getEvents();

      if (!mounted) return;

      setState(() {
        events = result
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = cleanError(e);
      });
    }
  }

  num parsePrice(dynamic value) {
    if (value is num) return value;
    if (value == null) return 0;

    final text = value.toString().trim();
    if (text.isEmpty) return 0;

    final direct = num.tryParse(text);
    if (direct != null) return direct;

    final cleaned = text
        .replaceAll(RegExp(r'Rp', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .trim();

    if (cleaned.isEmpty) return 0;

    if (cleaned.contains('.') && cleaned.contains(',')) {
      return num.tryParse(
            cleaned.replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0;
    }

    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.length == 2 && parts.last.length <= 2) {
        return num.tryParse('${parts[0]}.${parts[1]}') ?? 0;
      }
      return num.tryParse(cleaned.replaceAll(',', '')) ?? 0;
    }

    if (cleaned.contains('.')) {
      return num.tryParse(cleaned.replaceAll('.', '')) ?? 0;
    }

    return num.tryParse(cleaned) ?? 0;
  }

  num eventPrice(Map<String, dynamic> event) {
    return parsePrice(event['price'] ?? 0);
  }

  String formatRupiah(dynamic value) {
    final digits = parsePrice(value).round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }

    return 'Rp $buffer';
  }

  String eventTitle(Map<String, dynamic> event) {
    return (event['title'] ?? 'Event Tanpa Nama').toString();
  }

  String eventDescription(Map<String, dynamic> event) {
    return (event['description'] ?? 'Belum ada deskripsi event.')
        .toString();
  }

  String eventLocation(Map<String, dynamic> event) {
    return (event['location'] ?? 'Lokasi belum tersedia').toString();
  }

  DateTime? parseEventDate(Map<String, dynamic> event) {
    final raw = event['event_date'];
    if (raw == null || raw.toString().trim().isEmpty) return null;

    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  String eventDate(Map<String, dynamic> event) {
    final date = parseEventDate(event);
    if (date == null) return 'Tanggal belum tersedia';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day $month ${date.year} • $hour:$minute';
  }

  int availableTickets(Map<String, dynamic> event) {
    final raw = event['available_tickets'] ?? 0;

    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  bool isUpcoming(Map<String, dynamic> event) {
    final date = parseEventDate(event);
    return date != null && date.isAfter(DateTime.now());
  }

  bool isEventAvailable(Map<String, dynamic> event) {
    final date = parseEventDate(event);
    final dateValid = date == null || date.isAfter(DateTime.now());

    return availableTickets(event) > 0 && dateValid;
  }

  List<Map<String, dynamic>> get filteredEvents {
    final query = _searchController.text.trim().toLowerCase();

    final result = events.where((event) {
      final matchesSearch = query.isEmpty ||
          eventTitle(event).toLowerCase().contains(query) ||
          eventDescription(event).toLowerCase().contains(query) ||
          eventLocation(event).toLowerCase().contains(query);

      final stock = availableTickets(event);
      final date = parseEventDate(event);

      final matchesFilter = switch (selectedFilter) {
        EventFilter.all => true,
        EventFilter.upcoming => date != null && date.isAfter(DateTime.now()),
        EventFilter.available => isEventAvailable(event),
        EventFilter.soldOut => stock <= 0,
      };
      final categoryText = [event['category'], event['category_name'], event['type'], event['event_type'], event['kategori'], event['title'], event['description']]
          .where((v) => v != null).join(' ').toLowerCase();
      final matchesCategory = selectedCategory == null || selectedCategory!.isEmpty ||
          categoryText.contains(selectedCategory!.toLowerCase());
      final price = eventPrice(event).toDouble();
      final matchesMin = minimumPrice == null || price >= minimumPrice!;
      final matchesMax = maximumPrice == null || price <= maximumPrice!;

      return matchesSearch && matchesFilter && matchesCategory && matchesMin && matchesMax;
    }).toList();

    result.sort((a, b) {
      switch (selectedSort) {
        case EventSort.nearest:
          final dateA = parseEventDate(a);
          final dateB = parseEventDate(b);
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateA.compareTo(dateB);

        case EventSort.cheapest:
          return eventPrice(a).compareTo(eventPrice(b));

        case EventSort.mostExpensive:
          return eventPrice(b).compareTo(eventPrice(a));
      }
    });

    return result;
  }

  int get availableEventCount =>
      events.where(isEventAvailable).length;

  int get upcomingEventCount =>
      events.where(isUpcoming).length;

  void openEventDetail(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(event: event),
      ),
    );
  }

  Future<void> openOrderHistory() async {
    Navigator.pop(context);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderHistoryPage(),
      ),
    );

    if (mounted) {
      await loadEvents();
    }
  }

  Future<void> logout() async {
    Navigator.pop(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Apakah kamu yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.logout();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cleanError(e))),
      );
    }
  }

  Widget buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [brandColor, Color(0xFF958BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.confirmation_number,
                      size: 34,
                      color: brandColor,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Event Ticketers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pesan tiket event dengan mudah',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Daftar Event'),
              selected: true,
              selectedColor: brandColor,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Riwayat Pesanan'),
              onTap: openOrderHistory,
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Keluar',
                style: TextStyle(color: Colors.red),
              ),
              onTap: logout,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: buildDrawer(),
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Event Ticketers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang event',
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : loadEvents,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadEvents,
        child: buildBody(),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading && events.isEmpty) {
      
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 250),
          Center(child: CircularProgressIndicator()),
        ],
      );

    }

    if (errorMessage != null && events.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text(
            'Gagal memuat event',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: loadEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ),
        ],
      );
    }

    final visibleEvents = filteredEvents;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        buildWelcomeBanner(),
        const SizedBox(height: 18),
        buildStatistics(),
        const SizedBox(height: 24),
        const Text(
          'Jelajahi Event',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        buildSearchField(),
        const SizedBox(height: 10),
        buildAdvancedFilters(),
        const SizedBox(height: 16),
        buildFilterChips(),
        const SizedBox(height: 16),
        buildSortDropdown(),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Daftar Event',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${visibleEvents.length} event',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (errorMessage != null)
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
              title: const Text('Gagal memperbarui event'),
              subtitle: Text(errorMessage!),
              trailing: IconButton(
                onPressed: loadEvents,
                icon: const Icon(Icons.refresh),
              ),
            ),
          )
        else if (visibleEvents.isEmpty)
          buildEmptyResults()
        else
          ...visibleEvents.map(buildEventCard),
      ],
    );
  }

  Widget buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brandColor, Color(0xFF958BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          const Text(
            'Temukan Event Favoritmu!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cari pengalaman menarik dan pesan tiketmu '
            'dengan mudah dalam satu aplikasi.',
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() => selectedFilter = EventFilter.upcoming);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Jelajahi event mendatang'),
          ),
        ],
      ),
    );
  }

  Widget buildStatistics() {
    return Row(
      children: [
        Expanded(
          child: buildStatCard(
            Icons.event_note,
            'Total Event',
            '${events.length}',
            brandColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildStatCard(
            Icons.upcoming_outlined,
            'Mendatang',
            '$upcomingEventCount',
            Colors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildStatCard(
            Icons.confirmation_number_outlined,
            'Tersedia',
            '$availableEventCount',
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget buildStatCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEBF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari nama event, lokasi...',
        prefixIcon: const Icon(Icons.search, color: brandColor),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E3F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandColor, width: 1.5),
        ),
      ),
    );
  }

  Widget buildAdvancedFilters() {
    const categories = ['Semua kategori', 'Musik', 'Seminar', 'Olahraga', 'Wisata', 'Amal'];
    return Row(children: [
      Expanded(child: DropdownButtonFormField<String>(
        initialValue: selectedCategory == null
            ? categories.first
            : (categories.contains(selectedCategory)
                ? selectedCategory
                : categories.first),
        decoration: const InputDecoration(labelText: 'Kategori', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder()),
        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (value) => setState(() => selectedCategory = value == null || value == categories.first ? null : value),
      )),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        tooltip: 'Filter harga',
        icon: const Icon(Icons.tune_rounded),
        onPressed: () async {
          final minController = TextEditingController(text: minimumPrice?.round().toString() ?? '');
          final maxController = TextEditingController(text: maximumPrice?.round().toString() ?? '');
          final apply = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
            title: const Text('Filter rentang harga'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: minController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga minimum (Rp)')),
              const SizedBox(height: 12),
              TextField(controller: maxController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga maksimum (Rp)')),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Terapkan'))],
          ));
          if (apply == true && mounted) {
            setState(() {
              minimumPrice = double.tryParse(minController.text.trim());
              maximumPrice = double.tryParse(maxController.text.trim());
              if (minimumPrice != null && maximumPrice != null && minimumPrice! > maximumPrice!) {
                final temp = minimumPrice; minimumPrice = maximumPrice; maximumPrice = temp;
              }
            });
          }
          minController.dispose(); maxController.dispose();
        },
      ),
      if (selectedCategory != null || minimumPrice != null || maximumPrice != null)
        IconButton(tooltip: 'Hapus filter', onPressed: () => setState(() { selectedCategory = null; minimumPrice = null; maximumPrice = null; }), icon: const Icon(Icons.filter_alt_off_rounded)),
    ]);
  }

  Widget buildFilterChips() {
    const filters = <EventFilter, String>{
      EventFilter.all: 'Semua',
      EventFilter.upcoming: 'Mendatang',
      EventFilter.available: 'Tiket tersedia',
      EventFilter.soldOut: 'Tiket habis',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final selected = selectedFilter == entry.key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              showCheckmark: false,
              selectedColor: brandColor,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() => selectedFilter = entry.key);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildSortDropdown() {
    return Row(
      children: [
        const Icon(Icons.sort, color: Colors.black54, size: 20),
        const SizedBox(width: 8),
        const Text('Urutkan:', style: TextStyle(color: Colors.black54)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<EventSort>(
              value: selectedSort,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: EventSort.nearest,
                  child: Text('Tanggal terdekat'),
                ),
                DropdownMenuItem(
                  value: EventSort.cheapest,
                  child: Text('Harga terendah'),
                ),
                DropdownMenuItem(
                  value: EventSort.mostExpensive,
                  child: Text('Harga tertinggi'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedSort = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget buildEventCard(Map<String, dynamic> event) {
    final price = eventPrice(event);
    final stock = availableTickets(event);
    final date = parseEventDate(event);
    final soldOut = stock <= 0;
    final pastEvent = date != null && !date.isAfter(DateTime.now());
    final imageUrl = event['image_url']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFECEBF5)),
      ),
      child: InkWell(
        onTap: () => openEventDetail(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                width: double.infinity,
                height: 165,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => buildImagePlaceholder(),
              )
            else
              buildImagePlaceholder(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          eventTitle(event),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pastEvent
                            ? 'Selesai'
                            : soldOut
                                ? 'Habis'
                                : 'Tersedia',
                        style: TextStyle(
                          color: pastEvent || soldOut
                              ? Colors.red
                              : Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  buildEventInfo(
                    Icons.calendar_month_outlined,
                    date == null ? 'Tanggal belum tersedia' : eventDate(event),
                  ),
                  const SizedBox(height: 6),
                  buildEventInfo(
                    Icons.location_on_outlined,
                    eventLocation(event),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    eventDescription(event),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Harga tiket',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              price <= 0 ? 'Gratis' : formatRupiah(price),
                              style: const TextStyle(
                                color: brandColor,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pastEvent
                                  ? 'Event telah selesai'
                                  : soldOut
                                      ? 'Tidak ada tiket tersisa'
                                      : '$stock tiket tersedia',
                              style: TextStyle(
                                color: soldOut || pastEvent
                                    ? Colors.red
                                    : Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => openEventDetail(event),
                        style: FilledButton.styleFrom(
                          backgroundColor: brandColor,
                        ),
                        child: const Text('Lihat Detail'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 150,
      color: const Color(0xFFECEAFF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.confirmation_number_outlined,
        size: 54,
        color: brandColor,
      ),
    );
  }

  Widget buildEventInfo(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: brandColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget buildEmptyResults() {
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECEBF5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 54, color: Colors.black38),
          const SizedBox(height: 12),
          Text(
            hasSearch
                ? 'Event tidak ditemukan'
                : 'Tidak ada event pada filter ini',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Coba kata kunci atau lokasi lain.'
                : 'Coba pilih filter Semua untuk melihat event lainnya.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                selectedFilter = EventFilter.all;
                selectedSort = EventSort.nearest;
              });
            },
            child: const Text('Reset pencarian dan filter'),
          ),
        ],
      ),
    );
  }
}
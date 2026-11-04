import 'package:flutter/material.dart';
import '../../api_service.dart';

class AdminAdminEventApplicationsPage extends StatefulWidget {
  const AdminAdminEventApplicationsPage({super.key});

  @override
  State<AdminAdminEventApplicationsPage> createState() =>
      _AdminAdminEventApplicationsPageState();
}

class _AdminAdminEventApplicationsPageState
    extends State<AdminAdminEventApplicationsPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;

  String _selectedStatus = 'pending';

  List<Map<String, dynamic>> _applications = [];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  // ============================================================
  // LOAD APPLICATIONS
  // ============================================================

  Future<void> _loadApplications() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final data = await ApiService.getAdminEventApplications();

      if (!mounted) return;

      setState(() {
        _applications = data;
      });
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // CREATE ADMIN EVENT ACCOUNT
  // ============================================================

  Future<void> _showCreateAdminEventDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    bool obscurePassword = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Buat Akun Admin Event'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Isi data berikut untuk membuat akun Admin Event baru. '
                        'Akun akan langsung aktif setelah berhasil dibuat.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nama Admin Event',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';

                          if (name.isEmpty) {
                            return 'Nama wajib diisi.';
                          }

                          if (name.length < 2) {
                            return 'Nama minimal 2 karakter.';
                          }

                          if (name.length > 100) {
                            return 'Nama maksimal 100 karakter.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Email wajib diisi.';
                          }

                          final emailRegex = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          );

                          if (!emailRegex.hasMatch(email)) {
                            return 'Format email tidak valid.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';

                          if (password.isEmpty) {
                            return 'Password wajib diisi.';
                          }

                          if (password.length < 8) {
                            return 'Password minimal 8 karakter.';
                          }

                          if (password.length > 128) {
                            return 'Password maksimal 128 karakter.';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          await _createAdminEventAccount(
                            name: nameController.text,
                            email: emailController.text,
                            password: passwordController.text,
                            dialogContext: dialogContext,
                          );
                        },
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(
                    _isSubmitting ? 'Membuat...' : 'Buat Akun',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _createAdminEventAccount({
    required String name,
    required String email,
    required String password,
    required BuildContext dialogContext,
  }) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await ApiService.createAdminEventAccount(
        name: name,
        email: email,
        password: password,
      );

      // Pastikan halaman utama masih aktif.
      if (!mounted) return;

      // Pastikan dialog masih aktif sebelum menutupnya.
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      _showMessage(
        'Akun Admin Event berhasil dibuat dan langsung aktif.',
      );

      setState(() {
        _selectedStatus = 'approved';
      });

      await _loadApplications();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }



  // ============================================================
  // REVIEW APPLICATION
  // ============================================================

  Future<void> _reviewApplication({
    required int userId,
    required String status,
    String? rejectionReason,
  }) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await ApiService.reviewAdminEventApplication(
        userId: userId,
        status: status,
        rejectionReason: rejectionReason,
      );

      if (!mounted) return;

      _showMessage(
        status == 'approved'
            ? 'Pengajuan Admin Event berhasil disetujui.'
            : 'Pengajuan Admin Event berhasil ditolak.',
      );

      await _loadApplications();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ============================================================
  // APPROVAL CONFIRMATION
  // ============================================================

  Future<void> _confirmApproval(
    Map<String, dynamic> application,
  ) async {
    final userId = int.tryParse(
      application['id']?.toString() ?? '',
    );

    if (userId == null || userId <= 0) {
      _showMessage(
        'ID pengguna tidak valid.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Setujui Pengajuan?'),
          content: Text(
            'Apakah kamu yakin ingin menyetujui pengajuan dari '
            '${application['name'] ?? 'pengguna ini'}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Setujui'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _reviewApplication(
        userId: userId,
        status: 'approved',
      );
    }
  }

  // ============================================================
  // REJECTION DIALOG
  // ============================================================

  Future<void> _rejectApplication(
    Map<String, dynamic> application,
  ) async {
    final userId = int.tryParse(
      application['id']?.toString() ?? '',
    );

    if (userId == null || userId <= 0) {
      _showMessage(
        'ID pengguna tidak valid.',
        isError: true,
      );
      return;
    }

    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tolak Pengajuan'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Alasan penolakan',
              hintText: 'Tuliskan alasan penolakan...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Alasan penolakan wajib diisi.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Tolak Pengajuan'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason != null && reason.trim().isNotEmpty && mounted) {
      await _reviewApplication(
        userId: userId,
        status: 'rejected',
        rejectionReason: reason.trim(),
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>> get _filteredApplications {
    return _applications.where((application) {
      return application['admin_event_status'] == _selectedStatus;
    }).toList();
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Belum mengajukan';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // STATUS FILTER WIDGET
  // ============================================================

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterButton('pending', 'Menunggu'),
            const SizedBox(width: 8),
            _filterButton('approved', 'Disetujui'),
            const SizedBox(width: 8),
            _filterButton('rejected', 'Ditolak'),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String value, String label) {
    final selected = _selectedStatus == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedStatus = value;
        });
      },
    );
  }

  // ============================================================
  // APPLICATION CARD
  // ============================================================

  Widget _buildApplicationCard(
    Map<String, dynamic> application,
  ) {
    final name = application['name']?.toString() ?? '-';
    final email = application['email']?.toString() ?? '-';

    final status =
        application['admin_event_status']?.toString() ?? 'none';

    final rejectionReason =
        application['admin_event_rejection_reason']?.toString();

    final reviewedAt =
        application['admin_event_reviewed_at']?.toString();

    final userId = application['id']?.toString() ?? '-';

    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 7,
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(),

            Text(
              'ID Pengguna: $userId',
              style: const TextStyle(fontSize: 13),
            ),

            if (reviewedAt != null && reviewedAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ditinjau: $reviewedAt',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            if (status == 'rejected' &&
                rejectionReason != null &&
                rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Alasan penolakan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(rejectionReason),
            ],

            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _rejectApplication(application),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Tolak',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _confirmApproval(application),
                      icon: const Icon(Icons.check),
                      label: const Text('Setujui'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BACK NAVIGATION
  // ============================================================

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/admin');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final applications = _filteredApplications;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,

        // Tombol kembali
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),

        title: const Text('Persetujuan Admin Event'),

        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadApplications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: Column(
        children: [
          // Tombol buat akun Admin Event
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : _showCreateAdminEventDialog,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Buat Akun Admin Event'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // Filter status
          _buildStatusFilter(),

          // Daftar pengajuan
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : applications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada pengajuan '
                              '${_statusLabel(_selectedStatus).toLowerCase()}.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadApplications,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: applications.length,
                          itemBuilder: (context, index) {
                            return _buildApplicationCard(
                              applications[index],
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
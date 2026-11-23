import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import 'admin_drawer_page.dart';

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

  List<Map<String, dynamic>> _adminEventAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  String _getAccountName(Map<String, dynamic> account) {
    return (account['user_name'] ?? account['name'] ?? '-').toString();
  }

  String _getAccountEmail(Map<String, dynamic> account) {
    return (account['user_email'] ?? account['email'] ?? '-').toString();
  }

  Future<void> _loadAccounts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ApiService.getAdminEventApplications();

      if (!mounted) return;

      final activeAccounts = data.where((item) {
        final status = (item['status'] ?? item['admin_event_status'] ?? '')
            .toString()
            .toLowerCase();
        return status == 'approved';
      }).toList();

      setState(() {
        _adminEventAccounts = activeAccounts;
      });
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
                          if (name.isEmpty) return 'Nama wajib diisi.';
                          if (name.length < 2) return 'Nama minimal 2 karakter.';
                          if (name.length > 100) return 'Nama maksimal 100 karakter.';
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
                          if (email.isEmpty) return 'Email wajib diisi.';
                          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
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
                          if (password.isEmpty) return 'Password wajib diisi.';
                          if (password.length < 8) return 'Password minimal 8 karakter.';
                          if (password.length > 128) return 'Password maksimal 128 karakter.';
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
                          if (!formKey.currentState!.validate()) return;

                          await _createAdminEventAccount(
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
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
                  label: Text(_isSubmitting ? 'Membuat...' : 'Buat Akun'),
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApiService.createAdminEventAccount(
        name: name,
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      _showMessage('Akun Admin Event berhasil dibuat dan langsung aktif.');
      await _loadAccounts();
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final name = _getAccountName(account);
    final email = _getAccountEmail(account);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.person_outline, color: Colors.blue),
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Aktif',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawerPage(
        currentRoute: '/admin/admin-event-applications',
      ),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        title: const Text(
          'Akun Admin Event',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadAccounts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSubmitting ? null : _showCreateAdminEventDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Buat Akun Admin Event'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _adminEventAccounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada akun Admin Event.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAccounts,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 90),
                    itemCount: _adminEventAccounts.length,
                    itemBuilder: (context, index) {
                      return _buildAccountCard(_adminEventAccounts[index]);
                    },
                  ),
                ),
    );
  }
}
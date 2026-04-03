import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:file_picker/file_picker.dart';
import '../policy_data.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  late final SupabaseStreamBuilder _claimsStream;
  RealtimeChannel? _notificationChannel;
  bool _isUploading = false;
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser!.id;

    _claimsStream = Supabase.instance.client
        .from('claims')
        .stream(primaryKey: ['id'])
        .eq('employee_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    _notificationChannel = Supabase.instance.client
        .channel('public:claims')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'claims',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;

            if (newRecord['employee_id'] == userId &&
                newRecord['status'] != oldRecord['status']) {
              final status = newRecord['status'].toString().toUpperCase();
              final merchant = newRecord['merchant_name'];
              final color = status == 'APPROVED'
                  ? AppTheme.success
                  : AppTheme.destructive;

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          status == 'APPROVED'
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "UPDATE: Your $merchant claim was $status!",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: color,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
                    duration: const Duration(seconds: 6),
                  ),
                );
              }
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      Supabase.instance.client.removeChannel(_notificationChannel!);
    }
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null) setState(() => _pickedFile = result.files.first);
  }

  Future<String?> _uploadToSupabase() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) return null;
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}';
      await Supabase.instance.client.storage
          .from('receipts')
          .uploadBinary(fileName, _pickedFile!.bytes!);
      return Supabase.instance.client.storage
          .from('receipts')
          .getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitClaim(
    String merchant,
    double amount,
    String date,
    String location,
    String justification,
  ) async {
    setState(() => _isUploading = true);
    try {
      final imageUrl = await _uploadToSupabase();
      final userId = Supabase.instance.client.auth.currentUser!.id;

      String base64Image = "";
      if (_pickedFile != null && _pickedFile!.bytes != null) {
        base64Image = base64Encode(_pickedFile!.bytes!);
      }

      final response = await Supabase.instance.client.functions.invoke(
        'audit_receipt',
        body: {
          'merchant': merchant,
          'amount': amount,
          'date': date,
          'location': location,
          'base64Image': base64Image,
          'policyText': AetherisPolicy.fullText,
        },
      );

      final aiResult = jsonDecode(response.data['choices'][0]['message']['content']);

      final status = aiResult['status']?.toString().toLowerCase() ?? 'flagged';
      final reason =
          aiResult['reason'] ?? 'AI Analysis required manual review.';
      final snippet = aiResult['policy_snippet'] ?? 'N/A';

      await Supabase.instance.client.from('claims').insert({
        'employee_id': userId,
        'merchant_name': merchant,
        'amount': amount,
        'expense_date': date,
        'location': location,
        'justification': justification,
        'currency': 'USD',
        'status': status,
        'audit_reason': reason,
        'policy_snippet': snippet,
        'image_url': imageUrl,
      });

      setState(() {
        _pickedFile = null;
        _isUploading = false;
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Submission Error: $e");
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: AppTheme.destructive,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  void _showAddExpenseForm() {
    final merchantController = TextEditingController();
    final amountController = TextEditingController();
    final dateController = TextEditingController();
    final locationController = TextEditingController();
    final justificationController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Submit New Expense',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: merchantController,
                decoration: const InputDecoration(labelText: 'Merchant'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date of Expense (YYYY-MM-DD)',
                  suffixIcon: Icon(
                    Icons.calendar_today,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    String formattedDate =
                        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                    setModalState(() {
                      dateController.text = formattedDate;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'City / Location (e.g., London, Kochi)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: justificationController,
                decoration: const InputDecoration(labelText: 'Justification'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _pickReceipt();
                    setModalState(() {});
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _pickedFile == null
                        ? 'Select Receipt Image'
                        : 'Selected: ${_pickedFile!.name}',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading
                      ? null
                      : () {
                          final amt =
                              double.tryParse(amountController.text) ?? 0.0;
                          _submitClaim(
                            merchantController.text,
                            amt,
                            dateController.text,
                            locationController.text,
                            justificationController.text,
                          );
                        },
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryForeground,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Submit to AI Auditor"),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Expenses Request"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.mutedForeground),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _claimsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off,
                    size: 48,
                    color: AppTheme.mutedForeground,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Connection lost. Reconnecting...",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.foreground,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No expenses submitted yet.",
                style: TextStyle(color: AppTheme.mutedForeground),
              ),
            );
          }

          final claims = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: claims.length,
            itemBuilder: (context, i) {
              final claim = claims[i];
              final status = claim['status'] ?? 'pending';
              Color statusColor = status == 'approved'
                  ? AppTheme.success
                  : (status == 'rejected'
                        ? AppTheme.destructive
                        : AppTheme.warning);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  collapsedIconColor: AppTheme.mutedForeground,
                  iconColor: AppTheme.primary,
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(Icons.receipt_outlined, color: statusColor),
                  ),
                  title: Text(
                    claim['merchant_name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.foreground,
                    ),
                  ),
                  subtitle: Text(
                    "${claim['currency']} ${claim['amount'].toStringAsFixed(2)}",
                    style: const TextStyle(color: AppTheme.mutedForeground),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.psychology_outlined,
                            size: 20,
                            color: AppTheme.mutedForeground,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "AI Note: ${claim['audit_reason'] ?? 'Pending review'}",
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: AppTheme.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseForm,
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.primaryForeground,
        icon: const Icon(Icons.add),
        label: const Text("New Claim"),
      ),
    );
  }
}

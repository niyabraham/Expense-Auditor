
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:file_picker/file_picker.dart';

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
        .order('created_at', ascending: false);

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

  /// Uploads the receipt and returns a record with both the fileName (for
  /// rollback) and the public imageUrl. Returns null on failure.
  Future<({String fileName, String imageUrl})?> _uploadToSupabase() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) return null;
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}';
      await Supabase.instance.client.storage
          .from('receipts')
          .uploadBinary(fileName, _pickedFile!.bytes!);
      final imageUrl = Supabase.instance.client.storage
          .from('receipts')
          .getPublicUrl(fileName);
      return (fileName: fileName, imageUrl: imageUrl);
    } catch (e) {
      return null;
    }
  }

  Future<void> _startAIAuditFlow() async {
    await _pickReceipt();
    if (_pickedFile == null) return;

    setState(() => _isUploading = true);
    // Track fileName explicitly so rollback is always reliable.
    String? uploadedFileName;
    String? imageUrl;

    try {
      final upload = await _uploadToSupabase();
      if (upload == null) throw Exception("Upload to Supabase Storage failed");
      uploadedFileName = upload.fileName;
      imageUrl = upload.imageUrl;

      final response = await Supabase.instance.client.functions.invoke(
        'audit_receipt',
        body: {
          'imageUrl': imageUrl,
          'location': 'Auto-detecting...',
        },
      );

      final aiResult = response.data;
      final merchant = aiResult['merchant'] ?? '';
      final amount =
          double.tryParse(aiResult['amount']?.toString() ?? '0') ?? 0.0;
      final date = aiResult['date'] ?? '';
      final status =
          aiResult['status']?.toString().toLowerCase() ?? 'flagged';
      final reason =
          aiResult['reason'] ?? 'AI Analysis required manual review.';
      final snippet = aiResult['policy_snippet'] ?? 'N/A';

      setState(() => _isUploading = false);
      _showAddExpenseForm(
          merchant, amount, date, status, reason, snippet, imageUrl,
          uploadedFileName: uploadedFileName);
    } catch (e) {
      // ROLLBACK: Delete orphaned image from storage on any failure.
      if (uploadedFileName != null) {
        debugPrint(
            "Rolling back: Deleting orphaned image '$uploadedFileName' from storage...");
        await Supabase.instance.client.storage
            .from('receipts')
            .remove([uploadedFileName]);
      }
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Audit Error: $e"),
              backgroundColor: AppTheme.destructive),
        );
      }
    }
  }

  Future<void> _finalizeDatabaseInsert(
    String merchant, double amount, String date, String location, String justification, 
    String aiStatus, String aiReason, String aiSnippet, String imageUrl
  ) async {
    setState(() => _isUploading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('claims').insert({
        'employee_id': userId,
        'merchant_name': merchant,
        'amount': amount,
        'expense_date': date,
        'location': location,
        'justification': justification,
        'currency': 'USD',
        'status': aiStatus,
        'audit_reason': aiReason,
        'policy_snippet': aiSnippet,
        'image_url': imageUrl,
      });

      setState(() {
        _pickedFile = null;
        _isUploading = false;
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("DB Error: $e"), backgroundColor: AppTheme.destructive),
        );
      }
    }
  }

  void _showAddExpenseForm(
    String initMerchant, double initAmount, String initDate,
    String aiStatus, String aiReason, String aiSnippet, String imageUrl, {
    required String uploadedFileName,
  }) async {
    final merchantController = TextEditingController(text: initMerchant);
    final amountController = TextEditingController(text: initAmount > 0 ? initAmount.toStringAsFixed(2) : '');
    final dateController = TextEditingController(text: initDate != 'N/A' ? initDate : '');
    final locationController = TextEditingController();
    final justificationController = TextEditingController();

    final result = await showModalBottomSheet(
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "AI Pre-Audit Result: ${aiStatus.toUpperCase()}\n$aiReason",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: aiStatus == 'rejected' ? AppTheme.destructive : AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading
                      ? null
                      : () {
                          final amt = double.tryParse(amountController.text) ?? 0.0;
                          // Client-side date-mismatch guard:
                          // initDate is what the AI read from the physical receipt.
                          // Block submission if the user altered it.
                          if (initDate != 'N/A' &&
                              dateController.text.isNotEmpty &&
                              dateController.text != initDate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "⚠️ Date Mismatch: The date you entered differs from the receipt. Use the AI-extracted date.",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          _finalizeDatabaseInsert(
                             merchantController.text, amt, dateController.text, 
                             locationController.text, justificationController.text, 
                             aiStatus, aiReason, aiSnippet, imageUrl
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
                      : const Text("Confirm & Submit"),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );

    if (result == null && mounted) {
       // Ghost Receipt Rollback: use the explicit filename, not a fragile URL split.
       debugPrint("User dismissed form. Rolling back orphaned image '$uploadedFileName' from storage...");
       await Supabase.instance.client.storage.from('receipts').remove([uploadedFileName]);
    }
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
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _claimsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 48,
                    color: AppTheme.mutedForeground,
                  ),
                  SizedBox(height: 16),
                  Text(
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
                    backgroundColor: statusColor.withValues(alpha: 0.1),
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
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
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
      floatingActionButton: _isUploading ? const FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: AppTheme.border,
        label: Text("Analyzing..."),
        icon: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ) : FloatingActionButton.extended(
        onPressed: _startAIAuditFlow,
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.primaryForeground,
        icon: const Icon(Icons.add),
        label: const Text("New Claim"),
      ),
    );
  }
}

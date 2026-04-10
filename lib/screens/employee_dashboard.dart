import 'dart:typed_data';
import 'dart:convert';
// ignore: unused_import
import 'dart:ui' as ui; // retained for potential non-web pdf render path
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/app_theme.dart';
import 'login_page.dart';
import '../models/expense_claim.dart';

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
  bool _pickedFileIsPdf = false;
  String? _pickedFileContentType;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser!.id;

    _claimsStream = Supabase.instance.client
        .from('expense_claims')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    _notificationChannel = Supabase.instance.client
        .channel('public:claims')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'expense_claims',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['user_id'] == userId) {
              final status = newRecord['status'].toString().toUpperCase();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Claim for ${newRecord['merchant_name']} is now $status"),
                    backgroundColor: status == 'APPROVED' ? AppTheme.success : AppTheme.destructive,
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
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (result != null) {
      final file = result.files.first;
      final ext = (file.extension ?? '').toLowerCase();
      final nameLower = file.name.toLowerCase();
      final bytes = file.bytes;

      // Some platforms may report missing/incorrect extension/MIME; use magic bytes
      // so scanned "image receipts" saved as PDFs are still detected reliably.
      final bool isPdfByMagic =
          bytes != null &&
          bytes.length >= 4 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == '%PDF';

      final bool isPdf = ext == 'pdf' || nameLower.endsWith('.pdf') || isPdfByMagic;

      final imageContentType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'application/octet-stream',
      };

      final contentType = isPdf ? 'application/pdf' : imageContentType;
      setState(() {
        _pickedFile = file;
        _pickedFileContentType = contentType;
        _pickedFileIsPdf = isPdf;
      });
    }
  }

  /// Renders the first page of a PDF to a PNG using browser's PDF.js (web only).
  /// Passes the PDF as base64 to our JS helper in index.html, gets PNG base64 back.
  Future<Uint8List> _renderPdfFirstPageToPng(Uint8List pdfBytes) async {
    if (kIsWeb) {
      final base64Pdf = base64Encode(pdfBytes);
      debugPrint('Calling PDF.js renderPdfPageToBase64Png, pdf size: ${pdfBytes.length} bytes');
      try {
        final jsPromise = js_util.callMethod(
          js.context,
          'renderPdfPageToBase64Png',
          [base64Pdf],
        );
        final base64Jpeg = await js_util.promiseToFuture<String>(jsPromise);
        debugPrint('PDF.js render success, jpeg base64 length: ${base64Jpeg.length}');
        return base64Decode(base64Jpeg);
      } catch (jsErr) {
        debugPrint('PDF.js render failed: $jsErr');
        throw Exception('PDF render failed: $jsErr');
      }
    }
    throw Exception(
      "PDF rendering not available on this platform. Please upload a JPG or PNG image.",
    );
  }

  Future<({String fileName, String imageUrl})?> _uploadBytesToSupabase({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    try {
      await Supabase.instance.client.storage
          .from('receipts')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      final imageUrl = Supabase.instance.client.storage
          .from('receipts')
          .getPublicUrl(fileName);
      return (fileName: fileName, imageUrl: imageUrl);
    } catch (e) {
      return null;
    }
  }

  Future<({String fileName, String imageUrl})?> _uploadPickedReceiptForAudit() async {
    final picked = _pickedFile;
    final pickedBytes = picked?.bytes;
    if (picked == null || pickedBytes == null) return null;

    final ts = DateTime.now().millisecondsSinceEpoch;

    if (_pickedFileIsPdf) {
      // Both web AND mobile: render page 1 to PNG, upload as image.
      // On web this uses PDF.js via JS interop (handles all font encodings).
      // On mobile this would use pdf_render (native).
      final pngBytes = await _renderPdfFirstPageToPng(pickedBytes);
      final normalizedName = picked.name.toLowerCase().endsWith('.pdf')
          ? picked.name.substring(0, picked.name.length - 4)
          : picked.name;
      final outName = '${ts}_${normalizedName}_page1.jpg';
      return _uploadBytesToSupabase(
        bytes: pngBytes,
        fileName: outName,
        contentType: 'image/jpeg',
      );
    }

    final outName = '${ts}_${picked.name}';
    return _uploadBytesToSupabase(
      bytes: pickedBytes,
      fileName: outName,
      contentType: _pickedFileContentType ?? 'application/octet-stream',
    );
  }

  Future<void> _finalizeDatabaseInsert(
    String merchant, double amount, String date, String location, String justification, 
    String aiStatus, String aiReason, String aiSnippet, String imageUrl
  ) async {
    setState(() => _isUploading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('expense_claims').insert({
        'user_id': userId,
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

      if (!mounted) return;
      setState(() {
        _pickedFile = null;
        _pickedFileIsPdf = false;
        _pickedFileContentType = null;
        _isUploading = false;
      });
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("DB Error: $e"), backgroundColor: AppTheme.destructive),
      );
    }
  }

  void _showAddExpenseForm(
    String initMerchant, 
    double initAmount, 
    String initDate,
    String aiStatus, 
    String aiReason, 
    String aiSnippet, 
    String imageUrl,
  ) async {
    final merchantController = TextEditingController(text: initMerchant);
    final amountController = TextEditingController(text: initAmount > 0 ? initAmount.toStringAsFixed(2) : '');
    final dateController = TextEditingController(text: initDate != 'N/A' ? initDate : '');
    final locationController = TextEditingController();
    final justificationController = TextEditingController();

    String effectiveStatus = aiStatus;
    String effectiveReason = aiReason;
    String effectiveSnippet = aiSnippet;
    String effectiveImageUrl = imageUrl;
    String? uploadedFileName;

    bool aiStarted = false;
    bool aiCompleted = false;

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!aiStarted) {
            aiStarted = true;
            Future.microtask(() async {
              try {
                final upload = await _uploadPickedReceiptForAudit();
                if (upload == null) throw Exception("Upload failed");
                uploadedFileName = upload.fileName;
                effectiveImageUrl = upload.imageUrl;

                final currentUser = Supabase.instance.client.auth.currentUser;
                if (currentUser == null) {
                  throw Exception("You must be logged in to run AI audit.");
                }

                final refreshResult =
                    await Supabase.instance.client.auth.refreshSession();
                final accessToken = refreshResult.session?.accessToken ??
                    Supabase.instance.client.auth.currentSession?.accessToken;
                if (accessToken == null || accessToken.isEmpty) {
                  throw Exception("Session expired. Please login again.");
                }

                final response = await Supabase.instance.client.functions.invoke(
                  'audit_receipt',
                  body: {
                    'imageUrl': effectiveImageUrl,
                    'location': locationController.text.isEmpty ? 'Detecting...' : locationController.text,
                    'date': dateController.text,
                  },
                );

                final data = response.data;
                setModalState(() {
                  merchantController.text = data['merchant'] ?? '';
                  amountController.text = data['amount']?.toString() ?? '';
                  dateController.text = data['date'] ?? '';
                  effectiveStatus = data['status'] ?? 'flagged';
                  effectiveReason = data['reason'] ?? 'Manual check required';
                  effectiveSnippet = data['policy_snippet'] ?? 'N/A';
                  aiCompleted = true;
                });
              } catch (e, stack) {
                // Always surface the real error so it's visible in the UI
                debugPrint('AI audit error: $e');
                debugPrint('Stack: $stack');
                if (mounted) {
                  String reason;
                  if (e is FunctionException) {
                    final detailsText = e.details.toString().trim();
                    final reasonPhraseText = e.reasonPhrase.toString().trim();
                    final message = detailsText.isNotEmpty
                        ? detailsText
                        : (reasonPhraseText.isNotEmpty ? reasonPhraseText : 'Unauthorized or server error');
                    reason = "AI call failed (${e.status}): $message";
                  } else {
                    // Show the raw error — never hide it as "please enter manually"
                    reason = e.toString().replaceFirst("Exception: ", "");
                  }
                  setModalState(() {
                    effectiveStatus = 'flagged';
                    effectiveReason = reason;
                    aiCompleted = true;
                  });
                }
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Submit New Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
                const SizedBox(height: 16),
                TextField(controller: merchantController, decoration: const InputDecoration(labelText: 'Merchant')),
                const SizedBox(height: 12),
                TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController, 
                  readOnly: true, 
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)', suffixIcon: Icon(Icons.calendar_today)),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setModalState(() => dateController.text = picked.toString().split(' ')[0]);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 12),
                TextField(controller: justificationController, decoration: const InputDecoration(labelText: 'Justification')),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.primary.withAlpha((0.1 * 255).round()), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    aiCompleted ? "AI Result: ${effectiveStatus.toUpperCase()}\n$effectiveReason" : "AI is analyzing receipt...",
                    style: TextStyle(fontStyle: FontStyle.italic, color: effectiveStatus == 'rejected' ? AppTheme.destructive : AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !aiCompleted
                        ? null
                        : () {
                            final amt = double.tryParse(amountController.text) ?? 0.0;
                            _finalizeDatabaseInsert(
                              merchantController.text,
                              amt,
                              dateController.text,
                              locationController.text,
                              justificationController.text,
                              effectiveStatus,
                              effectiveReason,
                              effectiveSnippet,
                              effectiveImageUrl,
                            );
                          },
                    child: aiCompleted
                        ? const Text("Confirm & Submit")
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text("AI Analyzing Receipt..."),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );

    if (result == null && mounted) {
      if (uploadedFileName != null && !_isUploading) {
        await Supabase.instance.client.storage.from('receipts').remove([uploadedFileName!]);
      }
      setState(() {
        _pickedFile = null;
        _pickedFileIsPdf = false;
        _pickedFileContentType = null;
        _isUploading = false;
      });
    }
  }

  void _startAIAuditFlow() async {
    await _pickReceipt();
    if (_pickedFile == null) return;
    _showAddExpenseForm('', 0.0, 'N/A', 'pending', 'AI analysis in progress...', 'N/A', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Expenses Request"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _claimsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No expenses yet.", style: TextStyle(color: AppTheme.mutedForeground)));

          final claims = snapshot.data!.map((json) => ExpenseClaim.fromJson(json)).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: claims.length,
            itemBuilder: (context, i) {
              final claim = claims[i];
              final status = claim.status.toLowerCase();
              Color sColor = status == 'approved' ? AppTheme.success : (status == 'rejected' ? AppTheme.destructive : AppTheme.warning);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(backgroundColor: sColor.withAlpha((0.1 * 255).round()), child: Icon(Icons.receipt_outlined, color: sColor)),
                  title: Text(claim.merchantName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${claim.currency} ${claim.amount.toStringAsFixed(2)}"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: sColor.withAlpha((0.1 * 255).round()), borderRadius: BorderRadius.circular(12), border: Border.all(color: sColor.withAlpha((0.2 * 255).round()))),
                    child: Text(status.toUpperCase(), style: TextStyle(color: sColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.psychology_outlined, size: 20, color: AppTheme.mutedForeground),
                          const SizedBox(width: 8),
                          Expanded(child: Text("AI Note: ${claim.auditReason}", style: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.mutedForeground))),
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
        onPressed: _startAIAuditFlow,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text("New Claim"),
      ),
    );
  }
}
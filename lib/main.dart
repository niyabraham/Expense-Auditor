import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:expense_auditor/policy_data.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Auditor',
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: Colors.blue,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<List<Map<String, dynamic>>> _claimsFuture;
  PlatformFile? _pickedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _refreshClaims();
  }

  // --- UPGRADE 1: Sort by Risk Level (Feature 4 Expectation) ---
  void _refreshClaims() {
    setState(() {
      _claimsFuture = Supabase.instance.client
          .from('claims')
          .select()
          .then((data) {
            final List<Map<String, dynamic>> claimsList = List<Map<String, dynamic>>.from(data);
            claimsList.sort((a, b) {
              int getPriority(String? status) {
                switch (status?.toLowerCase()) {
                  case 'rejected': return 1;
                  case 'flagged': return 2;
                  case 'approved': return 3;
                  default: return 4;
                }
              }
              return getPriority(a['status']).compareTo(getPriority(b['status']));
            });
            return claimsList;
          });
    });
  }

  // --- UPGRADE 2: Human-in-the-loop database override ---
  Future<void> _updateClaimStatus(String claimId, String newStatus, String auditorComment) async {
    try {
      await Supabase.instance.client
          .from('claims')
          .update({
            'status': newStatus,
            'audit_reason': 'Human Auditor Override: $auditorComment',
          })
          .eq('id', claimId); // Ensure your Supabase table has an 'id' primary key

      _refreshClaims();
      if (mounted) Navigator.pop(context); // Close dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status manually overridden by Auditor!')),
      );
    } catch (e) {
      debugPrint("Override Error: $e");
    }
  }

  void _showPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description, color: Colors.blue),
            SizedBox(width: 10),
            Text("Aetheris Policy Manual"),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              AetherisPolicy.fullText,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    
    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<String?> _uploadToSupabase() async {
    if (_pickedFile == null) return null;
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}';
      final fileBytes = _pickedFile!.bytes;
      if (fileBytes == null) return null;

      await Supabase.instance.client.storage
          .from('receipts')
          .uploadBinary(fileName, fileBytes);

      return Supabase.instance.client.storage.from('receipts').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  // --- UPGRADE 3: Multimodal RAG (Reads Text and image binary simultaneously) ---
  Future<Map<String, String>> _getAIVerdict(String merchant, double amount, String reason, PlatformFile? receiptFile) async {
    const String apiKey = "AIzaSyBAgm8rAdezm0eBORpM7VAVgr8eP-7nkms";
    final policyKnowledge = AetherisPolicy.fullText;
    
    String? base64Image;
    if (receiptFile != null && receiptFile.bytes != null) {
      base64Image = base64Encode(receiptFile.bytes!);
    }

    final prompt = '''
    You are the Aetheris Global AI Auditor. 
    Use the following POLICY MANUAL and the attached physical receipt image to audit the expense:
    
    [POLICY MANUAL]
    $policyKnowledge
    
    [USER TYPED SUBMISSION]
    Merchant: $merchant
    Amount: \$$amount
    Justification: $reason
    
    INSTRUCTIONS:
    1. Check if the user typed Merchant and Amount match the text printed on the Physical Receipt image. If they do not match, REJECT the claim and explain the mismatch.
    2. If an expense exceeds limits in Article IV, VI, or VIII, set Status to REJECTED.
    3. If an expense is on a weekend, set Status to FLAGGED.
    4. You MUST cite the specific Article and Section from the manual.
    
    RESPONSE FORMAT (Strict):
    Status: [STATUS]
    Reason: [Article X, Section Y: explanation]
    ''';

    List<Map<String, dynamic>> parts = [
      {'text': prompt}
    ];

    if (base64Image != null) {
      parts.add({
        'inlineData': {
          'mimeType': 'image/png',
          'data': base64Image
        }
      });
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey'
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{ 'parts': parts }]
        }),
      ).timeout(const Duration(seconds: 25)); // Higher timeout for image packet

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String text = data['candidates'][0]['content']['parts'][0]['text'];
        
        final bool isApproved = text.toUpperCase().contains('APPROVED');
        final bool isFlagged = text.toUpperCase().contains('FLAGGED');
        
        String reasonText = "Audit complete.";
        if (text.contains('Reason:')) {
          reasonText = text.substring(text.indexOf('Reason:') + 7).trim();
        } else {
          reasonText = text.trim();
        }

        return {
          'status': isApproved ? 'approved' : (isFlagged ? 'flagged' : 'rejected'),
          'reason': reasonText,
        };
      } else {
        return {'status': 'flagged', 'reason': 'Server Error Code: ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'flagged', 'reason': 'Exception Error: ${e.toString()}'};
    }
  }

  Future<void> _submitClaim(String merchant, double amount, String justification) async {
    setState(() => _isUploading = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading and auditing...')),
      );

      final imageUrl = await _uploadToSupabase();
      
      // We pass _pickedFile to the AI logic so it can read binary bytes!
      final verdict = await _getAIVerdict(merchant, amount, justification, _pickedFile);

      await Supabase.instance.client.from('claims').insert({
        'merchant_name': merchant,
        'amount': amount,
        'justification': justification,
        'currency': 'USD',
        'status': verdict['status'],
        'audit_reason': verdict['reason'],
        'image_url': imageUrl,
      });
      
      _refreshClaims();
      setState(() {
        _pickedFile = null;
        _isUploading = false;
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddExpenseForm() {
    final merchantController = TextEditingController();
    final amountController = TextEditingController();
    final justificationController = TextEditingController();
    _pickedFile = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, 
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Submit New Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              TextField(controller: merchantController, decoration: const InputDecoration(labelText: 'Merchant')),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
              TextField(controller: justificationController, decoration: const InputDecoration(labelText: 'Business Reason')),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () async {
                  await _pickReceipt();
                  setModalState(() {}); 
                },
                icon: const Icon(Icons.image),
                label: Text(_pickedFile == null ? 'Upload Receipt Image' : 'File: ${_pickedFile!.name}'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isUploading ? null : () {
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  if (merchantController.text.isNotEmpty && amount > 0) {
                    _submitClaim(merchantController.text, amount, justificationController.text);
                  }
                },
                child: _isUploading ? const CircularProgressIndicator() : const Text('Submit for AI Audit'),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuditDetails(Map<String, dynamic> claim) {
    String selectedStatus = claim['status'] ?? 'flagged';
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(claim['merchant_name'] ?? 'Claim Detail'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (claim['image_url'] != null) ...[
                  const Text('Receipt Evidence:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      claim['image_url'],
                      loadingBuilder: (context, child, progress) => 
                        progress == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Justification:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(claim['justification'] ?? 'No justification provided.'),
                const SizedBox(height: 16),
                const Text('AI Auditor Verdict:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  claim['audit_reason'] ?? 'Pending AI review...',
                  style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic),
                ),
                const Divider(height: 40),

                // --- HUMAN OVERRIDE (Auditor Management Feature) ---
                const Text('Human Auditor Override:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: selectedStatus,
                  isExpanded: true,
                  items: ['approved', 'flagged', 'rejected'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedStatus = value!);
                  },
                ),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(labelText: 'Custom Auditor Review Comments'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                _updateClaimStatus(claim['id'].toString(), selectedStatus, commentController.text);
              }, 
              child: const Text('Apply Manual Override', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'flagged': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Audit Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _showPolicyDialog,
          ),
          IconButton(onPressed: _refreshClaims, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _claimsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No claims found.'));

          final claims = snapshot.data!;
          return ListView.builder(
            itemCount: claims.length,
            itemBuilder: (context, index) {
              final claim = claims[index];
              final status = claim['status'] ?? 'pending';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  onTap: () => _showAuditDetails(claim),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    child: Icon(Icons.receipt, color: _getStatusColor(status)),
                  ),
                  title: Text(claim['merchant_name'] ?? 'Unknown Merchant', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${claim['currency']} ${claim['amount']}'),
                  trailing: Chip(
                    label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                    backgroundColor: _getStatusColor(status),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}
import 'dart:convert'; // For json encoding/decoding
import 'package:http/http.dart' as http; // For the manual API call
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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

  @override
  void initState() {
    super.initState();
    _refreshClaims();
  }

  void _refreshClaims() {
    setState(() {
      _claimsFuture = Supabase.instance.client
          .from('claims')
          .select()
          .order('created_at', ascending: false);
    });
  }

  // --- AI AUDIT LOGIC ---
  Future<Map<String, String>> _getAIVerdict(String merchant, double amount, String reason) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    
    // 1. TRY THE ACTUAL API
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey'
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': "Audit this: $merchant, \$$amount, $reason. Rules: Food < \$20, Travel < \$500. Respond with 'Status: [STATUS]' and 'Reason: [REASON]'"}]}]
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String text = data['candidates'][0]['content']['parts'][0]['text'];
        return {
          'status': text.toUpperCase().contains('APPROVED') ? 'approved' : 'rejected',
          'reason': text.split('Reason:').last.trim(),
        };
      }
    } catch (e) {
      debugPrint("API failed, switching to Local Logic: $e");
    }

    // 2. FALLBACK: LOCAL AUDIT ENGINE (This will work even without internet!)
    String status = 'approved';
    String auditReason = 'Verified by Local Policy Engine.';

    if (amount > 500) {
      status = 'flagged';
      auditReason = 'High value expense flagged for manual manager review.';
    } else if (merchant.toLowerCase().contains('starbucks') || merchant.toLowerCase().contains('cafe')) {
      if (amount > 20) {
        status = 'rejected';
        auditReason = 'Daily meal allowance of \$20 exceeded.';
      }
    } else if (reason.toLowerCase().contains('personal') || reason.toLowerCase().contains('gift')) {
      status = 'rejected';
      auditReason = 'Personal expenses are not reimbursable per company policy.';
    }

    return {'status': status, 'reason': auditReason};
  }

  // Logic to send the new claim to Supabase
  Future<void> _submitClaim(String merchant, double amount, String justification) async {
    try {
      // Show loading snackbar so the user knows AI is "thinking"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Auditor is analyzing...'), duration: Duration(seconds: 2)),
      );

      // 1. Get the AI Verdict first
      final verdict = await _runAIAudit(merchant, amount, justification);

      // 2. Insert into Supabase with the AI's decision
      await Supabase.instance.client.from('claims').insert({
        'merchant_name': merchant,
        'amount': amount,
        'justification': justification,
        'currency': 'USD',
        'status': verdict['status'],
        'audit_reason': verdict['reason'],
      });
      
      _refreshClaims();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Helper for actual execution (calling the verdict function)
  Future<Map<String, String>> _runAIAudit(String merchant, double amount, String reason) async {
    return await _getAIVerdict(merchant, amount, reason);
  }

  void _showAddExpenseForm() {
    final merchantController = TextEditingController();
    final amountController = TextEditingController();
    final justificationController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, 
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Submit New Expense', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: merchantController, 
              decoration: const InputDecoration(labelText: 'Merchant (e.g., Uber, Amazon)'),
            ),
            TextField(
              controller: amountController, 
              decoration: const InputDecoration(labelText: 'Amount'), 
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: justificationController, 
              decoration: const InputDecoration(labelText: 'Business Reason'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (merchantController.text.isNotEmpty && amount > 0) {
                  _submitClaim(merchantController.text, amount, justificationController.text);
                }
              },
              child: const Text('Submit for AI Audit'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showAuditDetails(Map<String, dynamic> claim) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(claim['merchant_name'] ?? 'Claim Detail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Justification:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(claim['justification'] ?? 'No justification provided.'),
            const SizedBox(height: 16),
            const Text('AI Auditor Verdict:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              claim['audit_reason'] ?? 'Pending AI review...',
              style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
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
        centerTitle: true,
        actions: [
          IconButton(onPressed: _refreshClaims, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _claimsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No claims found.'));

          final claims = snapshot.data!;

          return ListView.builder(
            itemCount: claims.length,
            itemBuilder: (context, index) {
              final claim = claims[index];
              final status = claim['status'] ?? 'pending';

              return InkWell(
                onTap: () => _showAuditDetails(claim),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status).withOpacity(0.2),
                      child: Icon(Icons.receipt, color: _getStatusColor(status)),
                    ),
                    title: Text(
                      claim['merchant_name'] ?? 'Unknown Merchant',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${claim['currency']} ${claim['amount']}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
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
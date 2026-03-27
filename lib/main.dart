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
      title: 'Aetheris Expense Auditor',
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: Colors.blue,
        // FIXED: Changed CardTheme to CardThemeData
        cardTheme: const CardThemeData(elevation: 2),
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
  int _currentIndex = 0; // 0 = Employee Portal, 1 = Auditor Dashboard
  bool _isUploading = false;
  PlatformFile? _pickedFile;

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

  // --- DATABASE RESET ---
  Future<void> _resetAllClaims() async {
    try {
      await Supabase.instance.client.from('claims').delete().not('id', 'is', null);
      _refreshClaims();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database Reset Successful'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Reset Error: $e");
    }
  }

  // --- UI COMPONENT: STATUS COLORS ---
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green.shade700;
      case 'rejected': return Colors.red.shade700;
      case 'flagged': return Colors.orange.shade800;
      default: return Colors.blueGrey;
    }
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result != null) setState(() => _pickedFile = result.files.first);
  }

  Future<String?> _uploadToSupabase() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) return null;
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}';
      await Supabase.instance.client.storage.from('receipts').uploadBinary(fileName, _pickedFile!.bytes!);
      return Supabase.instance.client.storage.from('receipts').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitClaim(String merchant, double amount, String justification) async {
    setState(() => _isUploading = true);
    try {
      final imageUrl = await _uploadToSupabase();
      // Note: You would call your AI verdict function here like in your previous version
      
      await Supabase.instance.client.from('claims').insert({
        'merchant_name': merchant,
        'amount': amount,
        'justification': justification,
        'currency': 'USD',
        'status': 'flagged', // Defaulting for demo, replace with AI verdict
        'image_url': imageUrl,
      });
      
      _refreshClaims();
      setState(() { _pickedFile = null; _isUploading = false; });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
    }
  }

  // --- 1. VIEW: EMPLOYEE PORTAL ---
  Widget _buildEmployeePortal(List<Map<String, dynamic>> claims) {
    return Column(
      children: [
        _buildStatsBar(claims),
        Expanded(
          child: ListView.builder(
            itemCount: claims.length,
            itemBuilder: (context, i) => _buildClaimTile(claims[i]),
          ),
        ),
      ],
    );
  }

  // --- 2. VIEW: AUDITOR HOME PAGE ---
  Widget _buildAuditorHome(List<Map<String, dynamic>> claims) {
    List<Map<String, dynamic>> sorted = List.from(claims);
    sorted.sort((a, b) {
      int p(s) => s == 'rejected' ? 0 : (s == 'flagged' ? 1 : 2);
      return p(a['status']).compareTo(p(b['status']));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Pending Audit Queue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, i) => _buildClaimTile(sorted[i]),
          ),
        ),
      ],
    );
  }

  // --- 3. VIEW: AUDIT DETAIL VIEW (Full Screen Comparison) ---
  void _openAuditDetail(Map<String, dynamic> claim) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
      appBar: AppBar(title: const Text("Audit Evidence Detail")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (claim['image_url'] != null)
              Container(
                height: 350,
                width: double.infinity,
                color: Colors.black,
                child: Image.network(claim['image_url'], fit: BoxFit.contain),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailHeading("Extracted Data"),
                  Text("Merchant: ${claim['merchant_name']}\nAmount: ${claim['currency']} ${claim['amount']}"),
                  const Divider(height: 32),
                  _detailHeading("AI Policy Citation"),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(claim['audit_reason'] ?? "AI Analyzing Policy Article IV...", style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
                  const Divider(height: 32),
                  _detailHeading("Submission Justification"),
                  Text(claim['justification'] ?? "N/A"),
                  const SizedBox(height: 40),
                  if (_currentIndex == 1) _buildAuditorControls(claim),
                ],
              ),
            )
          ],
        ),
      ),
    )));
  }

  // --- UI HELPERS ---
  Widget _detailHeading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
  );

  Widget _buildClaimTile(Map<String, dynamic> claim) {
    final status = claim['status'] ?? 'pending';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: () => _openAuditDetail(claim),
        leading: Icon(Icons.receipt_long, color: _getStatusColor(status)),
        title: Text(claim['merchant_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${claim['currency']} ${claim['amount']}"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _getStatusColor(status), borderRadius: BorderRadius.circular(4)),
          child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildStatsBar(List<Map<String, dynamic>> claims) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statCircle("Total", claims.length.toString(), Colors.blue),
          _statCircle("Flagged", claims.where((c) => c['status'] == 'flagged').length.toString(), Colors.orange),
          _statCircle("Approved", claims.where((c) => c['status'] == 'approved').length.toString(), Colors.green),
        ],
      ),
    );
  }

  Widget _statCircle(String label, String val, Color col) => Column(
    children: [
      Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: col)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ],
  );

  Widget _buildAuditorControls(Map<String, dynamic> claim) {
    return Row(
      children: [
        Expanded(child: ElevatedButton(onPressed: () {}, child: const Text("Approve"))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton(onPressed: () {}, child: const Text("Reject / Flag"))),
      ],
    );
  }

  void _showAddExpenseForm() {
    final merchantController = TextEditingController();
    final amountController = TextEditingController();
    final justificationController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Submit New Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: merchantController, decoration: const InputDecoration(labelText: 'Merchant')),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
              TextField(controller: justificationController, decoration: const InputDecoration(labelText: 'Justification')),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () async { await _pickReceipt(); setModalState(() {}); },
                icon: const Icon(Icons.image),
                label: Text(_pickedFile == null ? 'Select Receipt' : 'Selected: ${_pickedFile!.name}'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isUploading ? null : () {
                  final amt = double.tryParse(amountController.text) ?? 0.0;
                  _submitClaim(merchantController.text, amt, justificationController.text);
                },
                child: _isUploading ? const CircularProgressIndicator() : const Text("Submit to AI"),
              ),
              const SizedBox(height: 20),
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
        title: Text(_currentIndex == 0 ? "Employee Portal" : "Auditor Dashboard"),
        actions: [
          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: _resetAllClaims),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshClaims),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _claimsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return _currentIndex == 0 ? _buildEmployeePortal(snapshot.data!) : _buildAuditorHome(snapshot.data!);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "My Claims"),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: "Audit Queue"),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
        onPressed: _showAddExpenseForm, label: const Text("New Expense"), icon: const Icon(Icons.add)
      ) : null,
    );
  }
}
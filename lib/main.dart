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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A2342),
          secondary: const Color(0xFF1768E3),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF0A2342),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// --- 1. LOGIN SCREEN ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter email and password")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = res.user;
      if (user != null) {
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .single();

        final String role = profileData['role'];

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => role == 'admin' 
                  ? const AuditorDashboard() 
                  : const EmployeeDashboard(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Error: $e"), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet, size: 64, color: Color(0xFF0A2342)),
              const SizedBox(height: 16),
              const Text("Aetheris Auditor", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("Corporate Single Sign-On", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Corporate Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1768E3), foregroundColor: Colors.white),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Secure Login"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 2. EMPLOYEE DASHBOARD ---
class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  late Future<List<Map<String, dynamic>>> _myClaimsFuture;
  bool _isUploading = false;
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _refreshClaims();
  }

  void _refreshClaims() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    setState(() {
      _myClaimsFuture = Supabase.instance.client
          .from('claims')
          .select()
          .eq('employee_id', userId)
          .order('created_at', ascending: false);
    });
  }

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

  // --- LOCATION-AWARE HTTP AI CALL ---
  Future<void> _submitClaim(String merchant, double amount, String location, String justification) async {
    setState(() => _isUploading = true);
    try {
      // 1. Upload to Supabase
      final imageUrl = await _uploadToSupabase();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // 2. Fetch API Key
      final apiKey = dotenv.env['GROQ_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) throw Exception('API Key missing in .env file');

      final prompt = '''
      You are an emotionless, strict Corporate Finance Auditor for Aetheris. You do not make exceptions. You enforce mathematical limits ruthlessly.
      
      COMPANY POLICY:
      ${AetherisPolicy.fullText}
      
      CLAIM DETAILS:
      Merchant: $merchant
      Amount: $amount USD
      Location: $location
      Justification: $justification
      
      EVALUATION RULES:
      1. Determine the exact maximum numerical limit for the specified Location based on the policy.
      2. Compare the Claim Amount ($amount) to that limit.
      3. If the Claim Amount is strictly greater than the limit, the claim is a violation. Justifications do not override limits.
      
      Respond ONLY with a valid JSON object. You MUST output the "reason" BEFORE the "status" to show your math:
      {
        "reason": "Explicitly state the policy limit for the location and mathematically compare it to the claim amount.",
        "status": "approved, flagged, or rejected"
      }
      ''';

      // 3. Encode Image to Base64
      String base64Image = "";
      if (_pickedFile != null && _pickedFile!.bytes != null) {
        base64Image = base64Encode(_pickedFile!.bytes!);
      }

      // 4. Send HTTP REST Request to Groq 
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      
      final aiResponse = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "meta-llama/llama-4-scout-17b-16e-instruct",
          "messages": [
            {
              "role": "user",
              "content": [
                {"type": "text", "text": prompt},
                if (base64Image.isNotEmpty)
                  {
                    "type": "image_url",
                    "image_url": {
                      "url": "data:image/jpeg;base64,$base64Image"
                    }
                  }
              ]
            }
          ],
          "response_format": {"type": "json_object"},
          "temperature": 0.1
        }),
      );

      if (aiResponse.statusCode != 200) {
        throw Exception("API Error ${aiResponse.statusCode}: ${aiResponse.body}");
      }

      // 5. Parse the JSON Response
      final responseData = jsonDecode(aiResponse.body);
      final responseText = responseData['choices'][0]['message']['content'];
      final aiResult = jsonDecode(responseText);
      
      final status = aiResult['status']?.toString().toLowerCase() ?? 'flagged';
      final reason = aiResult['reason'] ?? 'AI Analysis required manual review.';

      // 6. Save to Database with Location
      await Supabase.instance.client.from('claims').insert({
        'employee_id': userId,
        'merchant_name': merchant,
        'amount': amount,
        'location': location,
        'justification': justification,
        'currency': 'USD',
        'status': status,
        'audit_reason': reason,
        'image_url': imageUrl,
      });
      
      _refreshClaims();
      setState(() { _pickedFile = null; _isUploading = false; });
      if (mounted) Navigator.pop(context);
      
    } catch (e) {
      debugPrint("Submission Error: $e");
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red, duration: const Duration(seconds: 6))
        );
      }
    }
  }

  void _showAddExpenseForm() {
    final merchantController = TextEditingController();
    final amountController = TextEditingController();
    final locationController = TextEditingController(); // NEW Location Controller
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
              TextField(controller: locationController, decoration: const InputDecoration(labelText: 'City / Location (e.g., London, Kochi)')), // NEW Location Field
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
                  _submitClaim(merchantController.text, amt, locationController.text, justificationController.text);
                },
                child: _isUploading ? const CircularProgressIndicator() : const Text("Submit to AI Auditor"),
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
        title: const Text("My Expenses"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            },
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _myClaimsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No expenses submitted yet."));
          
          final claims = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: claims.length,
            itemBuilder: (context, i) {
              final claim = claims[i];
              final status = claim['status'] ?? 'pending';
              Color statusColor = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.2), child: Icon(Icons.receipt, color: statusColor)),
                  title: Text(claim['merchant_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${claim['currency']} ${claim['amount']}"),
                  trailing: Chip(
                    label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                    backgroundColor: statusColor,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text("AI / Auditor Note: ${claim['audit_reason'] ?? 'Pending review'}", style: const TextStyle(fontStyle: FontStyle.italic))),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseForm,
        icon: const Icon(Icons.add_a_photo),
        label: const Text("Scan Receipt"),
      ),
    );
  }
}

// --- 3. AUDITOR DASHBOARD ---
class AuditorDashboard extends StatefulWidget {
  const AuditorDashboard({super.key});

  @override
  State<AuditorDashboard> createState() => _AuditorDashboardState();
}

class _AuditorDashboardState extends State<AuditorDashboard> {
  late Future<List<Map<String, dynamic>>> _allClaimsFuture;

  @override
  void initState() {
    super.initState();
    _refreshClaims();
  }

  void _refreshClaims() {
    setState(() {
      _allClaimsFuture = Supabase.instance.client
          .from('claims')
          .select()
          .order('created_at', ascending: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compliance Audit Desk"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshClaims),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            },
          )
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 250,
            color: Colors.white,
            child: ListView(
              children: const [
                ListTile(leading: Icon(Icons.warning, color: Colors.orange), title: Text("Action Required")),
                ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text("Auto-Approved")),
                ListTile(leading: Icon(Icons.analytics), title: Text("Spend Analytics")),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _allClaimsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                List<Map<String, dynamic>> sorted = List.from(snapshot.data!);
                sorted.sort((a, b) {
                  int p(s) => s == 'rejected' ? 0 : (s == 'flagged' ? 1 : 2);
                  return p(a['status']).compareTo(p(b['status']));
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final claim = sorted[index];
                    final status = claim['status'] ?? 'pending';
                    Color sColor = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);

                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.receipt_long, color: sColor),
                        title: Text("${claim['merchant_name']} - ${claim['currency']} ${claim['amount']}"),
                        subtitle: Text("Status: ${status.toUpperCase()}"),
                        trailing: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => AuditDetailView(claim: claim))
                          ).then((_) => _refreshClaims()),
                          child: const Text("Review Evidence"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// --- 4. SIDE-BY-SIDE AUDIT DETAIL VIEW ---
class AuditDetailView extends StatelessWidget {
  final Map<String, dynamic> claim;
  
  const AuditDetailView({super.key, required this.claim});

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    await Supabase.instance.client
        .from('claims')
        .update({'status': newStatus})
        .eq('id', claim['id']);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Audit Evidence Detail")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: _buildReceiptViewer()),
                const VerticalDivider(width: 1),
                Expanded(flex: 1, child: _buildExtractedDataAndPolicy(context)),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 400, child: _buildReceiptViewer()),
                  _buildExtractedDataAndPolicy(context),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildReceiptViewer() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: claim['image_url'] != null
            ? InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(claim['image_url'], fit: BoxFit.contain),
              )
            : const Icon(Icons.receipt_long, size: 100, color: Colors.white24),
      ),
    );
  }

  Widget _buildExtractedDataAndPolicy(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Extracted Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _infoRow("Merchant", claim['merchant_name']),
          _infoRow("Amount", "${claim['currency']} ${claim['amount']}"),
          _infoRow("Location", claim['location'] ?? 'Not Specified'), // NEW Location Row
          _infoRow("Justification", claim['justification'] ?? 'N/A'),
          
          const Divider(height: 40),
          
          const Text("AI Policy Context & Verification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("STATUS: ${claim['status'].toString().toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(claim['audit_reason'] ?? "Awaiting AI Analysis of Article IV...", style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          const Text("Auditor Actions", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const TextField(
            decoration: InputDecoration(
              hintText: "Add custom note to employee...",
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () => _updateStatus(context, 'approved'), 
                child: const Text("Approve Exception")
              )),
              const SizedBox(width: 16),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () => _updateStatus(context, 'rejected'), 
                child: const Text("Reject Claim")
              )),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
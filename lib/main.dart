import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:expense_auditor/policy_data.dart';
import 'package:fl_chart/fl_chart.dart';

import 'theme/app_theme.dart';
import 'components/sidebar.dart';
import 'components/header.dart';
import 'components/stats_card.dart';

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
      theme: AppTheme.darkTheme,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter email and password")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await Supabase.instance.client.auth
          .signInWithPassword(
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
          SnackBar(
            content: Text("Login Error: $e"),
            backgroundColor: AppTheme.destructive,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shield,
                  size: 64,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Aetheris Auditor",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                ),
              ),
              const Text(
                "Secure Corporate Single Sign-On",
                style: TextStyle(color: AppTheme.mutedForeground),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Corporate Email",
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppTheme.foreground),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                style: const TextStyle(color: AppTheme.foreground),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryForeground,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Secure Login",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
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

      final apiKey = dotenv.env['GROQ_API_KEY'];
      if (apiKey == null || apiKey.isEmpty)
        throw Exception('API Key missing in .env file');

      final prompt =
          '''
      You are a highly skeptical, Zero-Trust Corporate Finance Investigator for Aetheris. Employees frequently lie, submit fake details, or upload blank/black images to steal money. 
      
      COMPANY POLICY:
      ${AetherisPolicy.fullText}
      
      CLAIM DETAILS (SUBMITTED BY SUSPECT EMPLOYEE):
      Merchant: $merchant
      Amount: $amount USD
      Claimed Date: $date
      Location: $location
      
      CRITICAL DIRECTIVE: DO NOT TRUST THE TEXT DETAILS ABOVE. YOU MUST VERIFY EVERYTHING USING ONLY YOUR EYES ON THE UPLOADED IMAGE. 
      
      You MUST output a valid JSON object with EXACTLY these keys in this EXACT order:
      {
        "visual_check": "Describe the pixels of the image. Can you clearly read a merchant name and a price? If the image is solid black, blank, or a random photo, you MUST write exactly 'NO_RECEIPT_FOUND'.",
        "date_check": "Extract the date from the image. If visual_check is 'NO_RECEIPT_FOUND', write 'FAIL'.",
        "math_check": "Is $amount strictly greater than the policy limit for $location? Write 'YES' or 'NO'.",
        "policy_snippet": "Extract the verbatim sentence from the policy justifying the decision. Output 'N/A' if the image is blank.",
        "reason": "Write a 1-sentence summary of why this passed or failed.",
        "status": "approved, flagged, or rejected"
      }
      
      ABSOLUTE OVERRIDES:
      - If visual_check contains 'NO_RECEIPT_FOUND', the status MUST be "rejected". Do not trust the employee's input.
      - If math_check is 'YES', the status MUST be "rejected".
      ''';

      String base64Image = "";
      if (_pickedFile != null && _pickedFile!.bytes != null) {
        base64Image = base64Encode(_pickedFile!.bytes!);
      }

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
                    "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
                  },
              ],
            },
          ],
          "response_format": {"type": "json_object"},
          "temperature": 0.1,
        }),
      );

      if (aiResponse.statusCode != 200) {
        throw Exception(
          "API Error ${aiResponse.statusCode}: ${aiResponse.body}",
        );
      }

      final responseData = jsonDecode(aiResponse.body);
      final responseText = responseData['choices'][0]['message']['content'];
      final aiResult = jsonDecode(responseText);

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

// --- 3. AUDITOR DASHBOARD ---
class AuditorDashboard extends StatefulWidget {
  const AuditorDashboard({super.key});

  @override
  State<AuditorDashboard> createState() => _AuditorDashboardState();
}

class _AuditorDashboardState extends State<AuditorDashboard> {
  late final SupabaseStreamBuilder _allClaimsStream;
  int _selectedIndex =
      0; // 0: Dashboard, 1: Alerts, 2: Expenses, 3: Analytics...

  @override
  void initState() {
    super.initState();
    _allClaimsStream = Supabase.instance.client
        .from('claims')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  void _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Next.js style Sidebar
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (idx) => setState(() => _selectedIndex = idx),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Next.js style Header
                DashboardHeader(
                  onLogout: _handleLogout,
                  title: "Overview Dashboard",
                ),

                // Content Body
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _allClaimsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      final claims = snapshot.data!;
                      return _buildDashboardContent(claims);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(List<Map<String, dynamic>> claims) {
    // Dynamic Stats Calculation
    int approvedCount = 0;
    int flaggedCount = 0;
    int rejectedCount = 0;
    double totalApprovedSpend = 0;

    for (var claim in claims) {
      final status = claim['status'];
      final amount = (claim['amount'] as num).toDouble();
      if (status == 'approved') {
        approvedCount++;
        totalApprovedSpend += amount;
      } else if (status == 'flagged')
        flaggedCount++;
      else if (status == 'rejected')
        rejectedCount++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Stats Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              int columns = constraints.maxWidth > 1000
                  ? 4
                  : (constraints.maxWidth > 600 ? 2 : 1);
              double aspectRatio = constraints.maxWidth > 1200 ? 2.5 : (constraints.maxWidth > 1000 ? 2.0 : (constraints.maxWidth > 600 ? 2.5 : 2.0));
              return GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: aspectRatio,
                children: [
                  StatsCard(
                    title: "Total Approved Spend",
                    value: "\$${totalApprovedSpend.toStringAsFixed(0)}",
                    icon: Icons.attach_money,
                    change: 8.2,
                    changeLabel: "this month",
                  ),
                  StatsCard(
                    title: "Claims Approved",
                    value: "$approvedCount",
                    icon: Icons.receipt_long,
                    change: 12,
                    changeLabel: "this month",
                    iconColor: AppTheme.success,
                  ),
                  StatsCard(
                    title: "Flagged by AI",
                    value: "$flaggedCount",
                    icon: Icons.warning_amber_rounded,
                    change: -15,
                    changeLabel: "vs last month",
                    positiveTrend: false,
                    iconColor: AppTheme.warning,
                  ),
                  StatsCard(
                    title: "Rejected Claims",
                    value: "$rejectedCount",
                    icon: Icons.trending_down,
                    change: -25,
                    changeLabel: "from last week",
                    positiveTrend: false,
                    iconColor: AppTheme.destructive,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Charts Row
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 900;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 2 : 0,
                    child: _buildExpenseChartCard(),
                  ),
                  if (isWide) const SizedBox(width: 24),
                  if (!isWide) const SizedBox(height: 24),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: _buildCategoryBreakdownCard(
                      approvedCount,
                      flaggedCount,
                      rejectedCount,
                      claims.isEmpty,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Recent Expenses Table Area
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Recent Expenses & Audit Queue",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.foreground,
                        ),
                      ),
                      Icon(Icons.more_horiz, color: AppTheme.mutedForeground),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildQueueList(claims),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Spend Analytics",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 20000,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const titles = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                          ];
                          return Text(
                            titles[value.toInt() % titles.length],
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text("");
                          return Text(
                            "${(value / 1000).toInt()}k",
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        const FlLine(color: AppTheme.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: 12000,
                          color: AppTheme.primary,
                          width: 22,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: 15000,
                          color: AppTheme.primary,
                          width: 22,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: 18000,
                          color: AppTheme.primary,
                          width: 22,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 3,
                      barRods: [
                        BarChartRodData(
                          toY: 14000,
                          color: AppTheme.primary,
                          width: 22,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 4,
                      barRods: [
                        BarChartRodData(
                          toY: 19000,
                          color: AppTheme.primary,
                          width: 22,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 5,
                      barRods: [
                        BarChartRodData(
                          toY: 16000,
                          color: AppTheme.primary,
                          width: 22,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(
    int approved,
    int flagged,
    int rejected,
    bool isEmpty,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Audit Breakdown",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: isEmpty
                  ? const Center(child: Text("No data yet"))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: [
                          PieChartSectionData(
                            color: AppTheme.success,
                            value: approved.toDouble(),
                            title: 'Approved\n($approved)',
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PieChartSectionData(
                            color: AppTheme.warning,
                            value: flagged.toDouble(),
                            title: 'Flagged\n($flagged)',
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PieChartSectionData(
                            color: AppTheme.destructive,
                            value: rejected.toDouble(),
                            title: 'Rejected\n($rejected)',
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueList(List<Map<String, dynamic>> claims) {
    List<Map<String, dynamic>> sorted = List.from(claims);
    sorted.sort((a, b) {
      int p(s) => s == 'rejected' ? 0 : (s == 'flagged' ? 1 : 2);
      return p(a['status']).compareTo(p(b['status']));
    });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final claim = sorted[index];
        final status = claim['status'] ?? 'pending';
        Color sColor = status == 'approved'
            ? AppTheme.success
            : (status == 'rejected' ? AppTheme.destructive : AppTheme.warning);

        return Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: sColor.withOpacity(0.1),
              child: Icon(Icons.receipt_outlined, color: sColor, size: 20),
            ),
            title: Text(
              "${claim['merchant_name']}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.foreground,
              ),
            ),
            subtitle: Text(
              "ID: ${claim['id'].toString().substring(0, 8)} • Date: ${claim['expense_date'] ?? 'N/A'}",
              style: const TextStyle(
                color: AppTheme.mutedForeground,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${claim['currency']} ${claim['amount'].toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.foreground,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: sColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AuditDetailView(claim: claim),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text("Review"),
                ),
              ],
            ),
          ),
        );
      },
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
    final status = claim['status'].toString();
    final sColor = status == 'approved'
        ? AppTheme.success
        : (status == 'rejected' ? AppTheme.destructive : AppTheme.warning);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Auditor Review Case"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: _buildReceiptViewer()),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 1,
                  child: _buildExtractedDataAndPolicy(context, sColor),
                ),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 400, child: _buildReceiptViewer()),
                  _buildExtractedDataAndPolicy(context, sColor),
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
      color: Colors.black,
      child: Center(
        child: claim['image_url'] != null
            ? InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(claim['image_url'], fit: BoxFit.contain),
              )
            : const Icon(Icons.receipt_long, size: 100, color: AppTheme.border),
      ),
    );
  }

  Widget _buildExtractedDataAndPolicy(BuildContext context, Color statusColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Extracted OCR Data",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _infoRow("Merchant", claim['merchant_name']),
                  const Divider(),
                  _infoRow(
                    "Amount",
                    "${claim['currency']} ${claim['amount'].toStringAsFixed(2)}",
                  ),
                  const Divider(),
                  _infoRow(
                    "Date Claimed",
                    claim['expense_date'] ?? 'Not Specified',
                  ),
                  const Divider(),
                  _infoRow("Location", claim['location'] ?? 'Not Specified'),
                  const Divider(),
                  _infoRow("Justification", claim['justification'] ?? 'N/A'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            "AI Policy Verification",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      statusColor == AppTheme.success
                          ? Icons.check_circle
                          : (statusColor == AppTheme.destructive
                                ? Icons.cancel
                                : Icons.warning),
                      color: statusColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "STATUS: ${claim['status'].toString().toUpperCase()}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  claim['audit_reason'] ?? "Awaiting AI Analysis...",
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.foreground,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  "VERBATIM POLICY SNIPPET:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppTheme.mutedForeground,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"${claim['policy_snippet'] ?? 'N/A'}"',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          const Text(
            "Auditor Actions",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              hintText: "Add custom note to employee (optional)...",
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => _updateStatus(context, 'approved'),
                  child: const Text("Approve Exception"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.destructive,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _updateStatus(context, 'rejected'),
                  child: const Text("Reject Claim"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.mutedForeground,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

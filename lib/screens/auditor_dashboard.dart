import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../components/sidebar.dart';
import '../components/header.dart';
import '../components/stats_card.dart';
import '../policy_data.dart';
import '../models/claim_status.dart';
import 'login_page.dart';

class AuditorDashboard extends StatefulWidget {
  const AuditorDashboard({super.key});

  @override
  State<AuditorDashboard> createState() => _AuditorDashboardState();
}

class _AuditorDashboardState extends State<AuditorDashboard> {
  late final SupabaseStreamBuilder _allClaimsStream;
  late final RealtimeChannel _notificationChannel;
  Map<String, dynamic>? _dashboardStats;
  int _selectedIndex =
      0; // 0: Dashboard, 1: Alerts, 2: Expenses, 3: Analytics...

  @override
  void initState() {
    super.initState();
    _refreshChartDataViaRPC();

    _allClaimsStream = Supabase.instance.client
        .from('claims')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50); // Kept for the audit queue only

    _notificationChannel = Supabase.instance.client
        .channel('public:claims_auditor')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'claims',
          callback: (payload) {
             _refreshChartDataViaRPC();
          },
        )
        .subscribe();
  }

  Future<void> _refreshChartDataViaRPC() async {
    try {
      final res = await Supabase.instance.client.rpc('get_dashboard_analytics');
      if (mounted) setState(() => _dashboardStats = res as Map<String, dynamic>);
    } catch(e) {
      debugPrint("RPC Error: $e");
    }
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_notificationChannel);
    super.dispose();
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
                  title: [
                    "Overview Dashboard",
                    "Audit Alerts",
                    "All Expenses",
                    "Spend Analytics",
                    "Employee Directory",
                    "Corporate Policies",
                  ][_selectedIndex],
                ),

                // Content Body
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _allClaimsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      final claims = snapshot.data!;
                      return _buildActiveScreen(claims);
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

  Widget _buildActiveScreen(List<Map<String, dynamic>> claims) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent(claims);
      case 1:
      case 2:
        final displayClaims = _selectedIndex == 1 
            ? claims.where((c) => c['status'] == 'flagged' || c['status'] == 'rejected').toList() 
            : claims;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedIndex == 1 ? "Action Required: Attention Queue" : "All Logged Expenses",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.foreground),
                  ),
                  const SizedBox(height: 16),
                  if (displayClaims.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text("No expenses found.", style: TextStyle(color: AppTheme.mutedForeground))),
                    )
                  else
                    _buildQueueList(displayClaims),
                ],
              ),
            ),
          ),
        );
      case 3:
        if (_dashboardStats == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final approvedCount = _dashboardStats!['approved_count'] ?? 0;
        final flaggedCount = _dashboardStats!['flagged_count'] ?? 0;
        final rejectedCount = _dashboardStats!['rejected_count'] ?? 0;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 900;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 2 : 0,
                    child: _buildDynamicExpenseChart(claims),
                  ),
                  if (isWide) const SizedBox(width: 24),
                  if (!isWide) const SizedBox(height: 24),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: _buildCategoryBreakdownCard(
                      approvedCount, flaggedCount, rejectedCount, claims.isEmpty,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      case 5:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Corporate Expense Policy (Aetheris)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
                  const SizedBox(height: 24),
                  Text(AetherisPolicy.fullText, style: const TextStyle(color: AppTheme.mutedForeground, height: 1.6)),
                ],
              ),
            ),
          ),
        );
      case 4:
      default:
        return const Center(
          child: Text(
            "Screen under construction.",
            style: TextStyle(color: AppTheme.mutedForeground, fontSize: 16),
          ),
        );
    }
  }

  Widget _buildDashboardContent(List<Map<String, dynamic>> claims) {
    if (_dashboardStats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Dynamic Stats Calculation from RPC
    final approvedCount = _dashboardStats!['approved_count'] ?? 0;
    final flaggedCount = _dashboardStats!['flagged_count'] ?? 0;
    final rejectedCount = _dashboardStats!['rejected_count'] ?? 0;
    final totalApprovedSpend = (_dashboardStats!['total_approved_spend'] as num?)?.toDouble() ?? 0.0;

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
                    child: _buildDynamicExpenseChart(claims),
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

  // --- UI HELPER: DYNAMIC BAR CHART ---
  Widget _buildDynamicExpenseChart(List<Map<String, dynamic>> claims) {
    Map<String, dynamic> rawMonthly = _dashboardStats?['monthly_spend'] ?? {};
    
    // 1. Initialize an empty map for all 12 months
    Map<int, double> monthlySpend = {
      1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 
      7: 0, 8: 0, 9: 0, 10: 0, 11: 0, 12: 0
    };

    double maxVal = 0.0;
    rawMonthly.forEach((k, v) {
       int month = int.tryParse(k) ?? 1;
       double val = (v as num).toDouble();
       monthlySpend[month] = val;
       if (val > maxVal) maxVal = val;
    });

    double maxY = maxVal > 0 ? (maxVal * 1.2) : 20000;

    List<BarChartGroupData> barGroups = [];
    for (int i = 1; i <= 12; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: monthlySpend[i]!,
              color: AppTheme.primary,
              width: 22,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: AppTheme.border.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

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
                  maxY: maxY, // Dynamic Maximum Bounds
                  barTouchData: BarTouchData(enabled: false),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(color: AppTheme.border, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text("");
                          return Text(
                            "\$${(value / 1000).toInt()}k",
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          if (value.toInt() < 1 || value.toInt() > 12) return const Text("");
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[value.toInt() - 1],
                              style: const TextStyle(color: AppTheme.mutedForeground, fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: barGroups,
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../components/sidebar.dart';
import '../components/header.dart';
import '../components/stats_card.dart';
import '../data/policy_data.dart';
import '../models/expense_claim.dart';
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
  int _selectedIndex = 0; 

  @override
  void initState() {
    super.initState();
    _refreshChartDataViaRPC();

    _allClaimsStream = Supabase.instance.client
        .from('expense_claims')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50);

    _notificationChannel = Supabase.instance.client
        .channel('public:claims_auditor')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expense_claims',
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
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (idx) => setState(() => _selectedIndex = idx),
          ),
          Expanded(
            child: Column(
              children: [
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
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _allClaimsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final List<ExpenseClaim> claims = snapshot.data!
                          .map((json) => ExpenseClaim.fromJson(json))
                          .toList();
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

  Widget _buildActiveScreen(List<ExpenseClaim> claims) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent(claims);
      case 1:
      case 2:
        final displayClaims = _selectedIndex == 1 
            ? claims.where((c) => c.status == 'flagged' || c.status == 'rejected').toList() 
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
        if (_dashboardStats == null) return const Center(child: CircularProgressIndicator());
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 900;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: isWide ? 2 : 0, child: _buildDynamicExpenseChart(claims)),
                  if (isWide) const SizedBox(width: 24) else const SizedBox(height: 24),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: _buildCategoryBreakdownCard(
                      _dashboardStats!['approved_count'] ?? 0, 
                      _dashboardStats!['flagged_count'] ?? 0, 
                      _dashboardStats!['rejected_count'] ?? 0, 
                      claims.isEmpty,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      case 4:
        // Group claims by employee ID
        final Map<String, List<ExpenseClaim>> employeeMap = {};
        for (var claim in claims) {
          employeeMap.putIfAbsent(claim.userId, () => []).add(claim);
        }
        final employeeIds = employeeMap.keys.toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Active Corporate Employees",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.foreground),
                  ),
                  const SizedBox(height: 24),
                  if (employeeIds.isEmpty)
                    const Center(child: Text("No employees found."))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: employeeIds.length,
                      itemBuilder: (context, index) {
                        final id = employeeIds[index];
                        final empClaims = employeeMap[id]!;
                        
                        // Mapping IDs to Names for the demo
                        String name = "Marcus Johnson";
                        if (id == 'e60a3f01-4473-4560-b6e8-fea7342bf6b5') name = "David Miller";
                        if (id == '313a1373-f6f7-44ac-bf51-2ddf537f7974') name = "Sarah Chen";

                        return Container(
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.person, color: AppTheme.primary),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.foreground)),
                            subtitle: Text("ID: ${id.substring(0, 8)}... • ${empClaims.length} Claims submitted"),
                            trailing: const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      case 5:
        return const SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Corporate Expense Policy (Aetheris)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
                  SizedBox(height: 24),
                  Text(AetherisPolicy.fullText, style: TextStyle(color: AppTheme.mutedForeground, height: 1.6)),
                ],
              ),
            ),
          ),
        );
      default:
        return const Center(child: Text("Screen not found."));
    }
  }

  Widget _buildDashboardContent(List<ExpenseClaim> claims) {
    if (_dashboardStats == null) return const Center(child: CircularProgressIndicator());

    final approvedCount = _dashboardStats!['approved_count'] ?? 0;
    final flaggedCount = _dashboardStats!['flagged_count'] ?? 0;
    final rejectedCount = _dashboardStats!['rejected_count'] ?? 0;
    final totalApprovedSpend = (_dashboardStats!['total_approved_spend'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              int columns = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.5,
                children: [
                  StatsCard(title: "Total Approved Spend", value: "\$${totalApprovedSpend.toStringAsFixed(0)}", icon: Icons.attach_money, change: 8.2),
                  StatsCard(title: "Claims Approved", value: "$approvedCount", icon: Icons.receipt_long, iconColor: AppTheme.success),
                  StatsCard(title: "Flagged by AI", value: "$flaggedCount", icon: Icons.warning_amber_rounded, iconColor: AppTheme.warning),
                  StatsCard(title: "Rejected Claims", value: "$rejectedCount", icon: Icons.trending_down, iconColor: AppTheme.destructive),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildDynamicExpenseChart(claims),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Recent Audit Queue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
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

  Widget _buildDynamicExpenseChart(List<ExpenseClaim> claims) {
    Map<String, dynamic> rawMonthly = _dashboardStats?['monthly_spend'] ?? {};
    Map<int, double> monthlySpend = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};
    double maxVal = 0.0;
    rawMonthly.forEach((k, v) {
       int month = int.tryParse(k) ?? 1;
       double val = (v as num).toDouble();
       monthlySpend[month] = val;
       if (val > maxVal) maxVal = val;
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Spend Analytics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal > 0 ? maxVal * 1.2 : 20000,
                  barGroups: List.generate(12, (i) => BarChartGroupData(x: i + 1, barRods: [BarChartRodData(toY: monthlySpend[i+1]!, color: AppTheme.primary, width: 22)]))
                )
              )
            ),
          ],
        ),
      )
    );
  }

  Widget _buildCategoryBreakdownCard(int approved, int flagged, int rejected, bool isEmpty) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Audit Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: isEmpty ? const Center(child: Text("No data yet")) : PieChart(
                PieChartData(sections: [
                  PieChartSectionData(
                    color: AppTheme.success,
                    value: approved.toDouble(),
                    title: 'Approved\n($approved)',
                    showTitle: true,
                    titleStyle: const TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    radius: 58,
                  ),
                  PieChartSectionData(
                    color: AppTheme.warning,
                    value: flagged.toDouble(),
                    title: 'Flagged\n($flagged)',
                    showTitle: true,
                    titleStyle: const TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    radius: 58,
                  ),
                  PieChartSectionData(
                    color: AppTheme.destructive,
                    value: rejected.toDouble(),
                    title: 'Rejected\n($rejected)',
                    showTitle: true,
                    titleStyle: const TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    radius: 58,
                  ),
                ])
              )
            ),
          ],
        )
      )
    );
  }

  Widget _buildQueueList(List<ExpenseClaim> claims) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: claims.length,
      itemBuilder: (context, index) {
        final claim = claims[index];
        final status = claim.status.toLowerCase();
        final Color statusColor = switch (status) {
          'approved' => AppTheme.success,
          'flagged' => AppTheme.warning,
          'rejected' => AppTheme.destructive,
          _ => AppTheme.mutedForeground,
        };
        return ListTile(
          title: Text(claim.merchantName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.foreground)),
          subtitle: Text("Date: ${claim.date}", style: const TextStyle(color: AppTheme.mutedForeground)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  claim.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuditDetailView(claim: claim))),
                child: const Text("Review"),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AuditDetailView extends StatelessWidget {
  final ExpenseClaim claim;
  const AuditDetailView({super.key, required this.claim});

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    await Supabase.instance.client
        .from('expense_claims')
        .update({'status': newStatus})
        .eq('id', claim.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Auditor Review")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (claim.imageUrl != null) 
              Center(child: Container(constraints: const BoxConstraints(maxHeight: 400), child: Image.network(claim.imageUrl!))),
            const SizedBox(height: 24),
            Text("Merchant: ${claim.merchantName}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
            const Divider(),
            Text("Amount: \$${claim.amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, color: AppTheme.foreground)),
            const SizedBox(height: 12),
            Text("AI Audit Note: ${claim.auditReason}", style: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.mutedForeground)),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () => _updateStatus(context, 'approved'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success), child: const Text("Approve"))),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(onPressed: () => _updateStatus(context, 'rejected'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.destructive), child: const Text("Reject"))),
              ],
            )
          ],
        ),
      ),
    );
  }
}
import { Sidebar } from "@/components/sidebar";
import { Header } from "@/components/header";
import { StatsCard } from "@/components/stats-card";
import { ExpenseChart } from "@/components/expense-chart";
import { CategoryBreakdown } from "@/components/category-breakdown";
import { RecentExpenses } from "@/components/recent-expenses";
import { AuditAlerts } from "@/components/audit-alerts";
import { QuickActions } from "@/components/quick-actions";
import { TeamActivity } from "@/components/team-activity";
import { 
  DollarSign, 
  TrendingDown, 
  Receipt, 
  AlertTriangle 
} from "lucide-react";

export default function DashboardPage() {
  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header />
        <main className="flex-1 overflow-y-auto bg-background p-6">
          {/* Stats Grid */}
          <div className="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <StatsCard
              title="Total Expenses"
              value={117000}
              change={12.5}
              trend="up"
              icon={<DollarSign className="h-5 w-5" />}
            />
            <StatsCard
              title="Budget Remaining"
              value={43000}
              change={-8.2}
              trend="down"
              icon={<TrendingDown className="h-5 w-5" />}
            />
            <StatsCard
              title="Pending Approval"
              value="24"
              change={3.1}
              trend="up"
              icon={<Receipt className="h-5 w-5" />}
            />
            <StatsCard
              title="Flagged Items"
              value="3"
              change={-25}
              trend="down"
              changeLabel="from last week"
              icon={<AlertTriangle className="h-5 w-5" />}
            />
          </div>

          {/* Charts Row */}
          <div className="mb-6 grid gap-6 lg:grid-cols-3">
            <div className="lg:col-span-2">
              <ExpenseChart />
            </div>
            <div>
              <CategoryBreakdown />
            </div>
          </div>

          {/* Quick Actions & Activity Row */}
          <div className="mb-6 grid gap-6 lg:grid-cols-3">
            <QuickActions />
            <AuditAlerts />
            <TeamActivity />
          </div>

          {/* Recent Expenses Table */}
          <RecentExpenses />
        </main>
      </div>
    </div>
  );
}

"use client";

import { formatCurrency, cn } from "@/lib/utils";
import { 
  MoreHorizontal, 
  CheckCircle2, 
  Clock, 
  AlertCircle,
  FileText,
  ChevronRight
} from "lucide-react";

interface Expense {
  id: string;
  description: string;
  vendor: string;
  category: string;
  amount: number;
  date: string;
  status: "approved" | "pending" | "flagged";
  submittedBy: string;
  receipt: boolean;
}

const expenses: Expense[] = [
  {
    id: "EXP-001",
    description: "Cloud Infrastructure - March",
    vendor: "AWS",
    category: "Software & SaaS",
    amount: 12450,
    date: "2024-03-28",
    status: "approved",
    submittedBy: "John Doe",
    receipt: true,
  },
  {
    id: "EXP-002",
    description: "Team Dinner - Client Meeting",
    vendor: "The Capital Grille",
    category: "Travel & Transport",
    amount: 847,
    date: "2024-03-27",
    status: "pending",
    submittedBy: "Sarah Chen",
    receipt: true,
  },
  {
    id: "EXP-003",
    description: "Conference Sponsorship",
    vendor: "TechCrunch Disrupt",
    category: "Marketing",
    amount: 15000,
    date: "2024-03-26",
    status: "flagged",
    submittedBy: "Mike Wilson",
    receipt: false,
  },
  {
    id: "EXP-004",
    description: "Office Furniture - Desks",
    vendor: "Herman Miller",
    category: "Office Supplies",
    amount: 8920,
    date: "2024-03-25",
    status: "approved",
    submittedBy: "Lisa Park",
    receipt: true,
  },
  {
    id: "EXP-005",
    description: "Flight - NYC to SF",
    vendor: "United Airlines",
    category: "Travel & Transport",
    amount: 1245,
    date: "2024-03-24",
    status: "approved",
    submittedBy: "John Doe",
    receipt: true,
  },
];

const statusConfig = {
  approved: {
    label: "Approved",
    icon: CheckCircle2,
    className: "text-success bg-success/10",
  },
  pending: {
    label: "Pending",
    icon: Clock,
    className: "text-warning bg-warning/10",
  },
  flagged: {
    label: "Flagged",
    icon: AlertCircle,
    className: "text-destructive bg-destructive/10",
  },
};

export function RecentExpenses() {
  return (
    <div className="rounded-xl border border-border bg-card">
      <div className="flex items-center justify-between border-b border-border p-5">
        <div>
          <h3 className="text-lg font-semibold">Recent Expenses</h3>
          <p className="text-sm text-muted-foreground">Latest expense submissions</p>
        </div>
        <button className="flex items-center gap-1 text-sm font-medium text-primary hover:underline">
          View All
          <ChevronRight className="h-4 w-4" />
        </button>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b border-border">
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Description
              </th>
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Category
              </th>
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Submitted By
              </th>
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Amount
              </th>
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Status
              </th>
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Receipt
              </th>
              <th className="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {expenses.map((expense) => {
              const status = statusConfig[expense.status];
              return (
                <tr
                  key={expense.id}
                  className="group transition-colors hover:bg-secondary/50"
                >
                  <td className="px-5 py-4">
                    <div>
                      <p className="text-sm font-medium text-foreground">
                        {expense.description}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {expense.vendor} · {expense.date}
                      </p>
                    </div>
                  </td>
                  <td className="px-5 py-4">
                    <span className="inline-flex items-center rounded-md bg-secondary px-2 py-1 text-xs font-medium text-secondary-foreground">
                      {expense.category}
                    </span>
                  </td>
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-2">
                      <div className="flex h-6 w-6 items-center justify-center rounded-full bg-primary/20 text-xs font-medium text-primary">
                        {expense.submittedBy
                          .split(" ")
                          .map((n) => n[0])
                          .join("")}
                      </div>
                      <span className="text-sm text-muted-foreground">
                        {expense.submittedBy}
                      </span>
                    </div>
                  </td>
                  <td className="px-5 py-4">
                    <span className="text-sm font-semibold">
                      {formatCurrency(expense.amount)}
                    </span>
                  </td>
                  <td className="px-5 py-4">
                    <span
                      className={cn(
                        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium",
                        status.className
                      )}
                    >
                      <status.icon className="h-3 w-3" />
                      {status.label}
                    </span>
                  </td>
                  <td className="px-5 py-4">
                    {expense.receipt ? (
                      <FileText className="h-4 w-4 text-success" />
                    ) : (
                      <span className="text-xs text-destructive">Missing</span>
                    )}
                  </td>
                  <td className="px-5 py-4 text-right">
                    <button className="rounded-lg p-1.5 text-muted-foreground opacity-0 transition-all hover:bg-secondary hover:text-foreground group-hover:opacity-100">
                      <MoreHorizontal className="h-4 w-4" />
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

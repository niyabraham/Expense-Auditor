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

interface Claim {
  id: string;
  merchant: string;
  location: string;
  category: string;
  amount: number;
  date: string;
  status: "approved" | "flagged" | "rejected";
  submittedBy: string;
  receipt: boolean;
  aiReason: string;
}

const claims: Claim[] = [
  {
    id: "CLM-001",
    merchant: "Uber",
    location: "San Francisco",
    category: "Transportation",
    amount: 45,
    date: "2026-04-02",
    status: "approved",
    submittedBy: "Sarah Chen",
    receipt: true,
    aiReason: "Receipt verified. Amount within Tier-1 city limit.",
  },
  {
    id: "CLM-002",
    merchant: "The Ritz Carlton",
    location: "New York",
    category: "Accommodation",
    amount: 485,
    date: "2026-04-01",
    status: "flagged",
    submittedBy: "John Doe",
    receipt: true,
    aiReason: "Amount exceeds Tier-1 accommodation limit of $250/night.",
  },
  {
    id: "CLM-003",
    merchant: "Starbucks",
    location: "London",
    category: "Meals",
    amount: 28,
    date: "2026-03-30",
    status: "rejected",
    submittedBy: "Mike Wilson",
    receipt: false,
    aiReason: "NO_RECEIPT_FOUND: Image appears to be blank/corrupted.",
  },
  {
    id: "CLM-004",
    merchant: "Delta Airlines",
    location: "Singapore",
    category: "Transportation",
    amount: 1850,
    date: "2026-03-28",
    status: "approved",
    submittedBy: "Lisa Park",
    receipt: true,
    aiReason: "Business class approved for long-haul flight over 8hrs.",
  },
  {
    id: "CLM-005",
    merchant: "Nobu Restaurant",
    location: "Zurich",
    category: "Client Entertainment",
    amount: 320,
    date: "2026-03-27",
    status: "flagged",
    submittedBy: "John Doe",
    receipt: true,
    aiReason: "Weekend expense flagged as high-risk per Article VII.",
  },
];

const statusConfig = {
  approved: {
    label: "Approved",
    icon: CheckCircle2,
    className: "text-success bg-success/10",
  },
  flagged: {
    label: "Flagged",
    icon: Clock,
    className: "text-warning bg-warning/10",
  },
  rejected: {
    label: "Rejected",
    icon: AlertCircle,
    className: "text-destructive bg-destructive/10",
  },
};

export function RecentExpenses() {
  return (
    <div className="rounded-xl border border-border bg-card">
      <div className="flex items-center justify-between border-b border-border p-5">
        <div>
          <h3 className="text-lg font-semibold">Audit Queue</h3>
          <p className="text-sm text-muted-foreground">Claims awaiting review - sorted by priority</p>
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
                Merchant
              </th>
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Category
              </th>
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Employee
              </th>
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Amount
              </th>
              <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                AI Status
              </th>
              <th className="hidden lg:table-cell px-5 py-3 text-left text-xs font-medium uppercase tracking-wider text-muted-foreground">
                AI Reason
              </th>
              <th className="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider text-muted-foreground">
                Review
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {claims.map((claim) => {
              const status = statusConfig[claim.status];
              return (
                <tr
                  key={claim.id}
                  className="group transition-colors hover:bg-secondary/50"
                >
                  <td className="px-5 py-4">
                    <div>
                      <p className="text-sm font-medium text-foreground">
                        {claim.merchant}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {claim.location} · {claim.date}
                      </p>
                    </div>
                  </td>
                  <td className="px-5 py-4">
                    <span className="inline-flex items-center rounded-md bg-secondary px-2 py-1 text-xs font-medium text-secondary-foreground">
                      {claim.category}
                    </span>
                  </td>
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-2">
                      <div className="flex h-6 w-6 items-center justify-center rounded-full bg-primary/20 text-xs font-medium text-primary">
                        {claim.submittedBy
                          .split(" ")
                          .map((n) => n[0])
                          .join("")}
                      </div>
                      <span className="text-sm text-muted-foreground">
                        {claim.submittedBy}
                      </span>
                    </div>
                  </td>
                  <td className="px-5 py-4">
                    <span className="text-sm font-semibold">
                      {formatCurrency(claim.amount)}
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
                  <td className="hidden lg:table-cell px-5 py-4">
                    <p className="text-xs text-muted-foreground max-w-xs truncate" title={claim.aiReason}>
                      {claim.aiReason}
                    </p>
                  </td>
                  <td className="px-5 py-4 text-right">
                    <button className="rounded-lg px-3 py-1.5 text-xs font-medium bg-primary/10 text-primary hover:bg-primary/20 transition-colors">
                      Review
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

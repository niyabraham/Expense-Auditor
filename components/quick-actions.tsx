"use client";

import { 
  Plus, 
  Upload, 
  FileBarChart, 
  Send,
  ArrowRight
} from "lucide-react";
import { cn } from "@/lib/utils";

interface QuickAction {
  label: string;
  description: string;
  icon: React.ElementType;
  color: string;
}

const actions: QuickAction[] = [
  {
    label: "Scan Receipt",
    description: "Submit new expense with AI verification",
    icon: Plus,
    color: "bg-primary text-primary-foreground",
  },
  {
    label: "Upload Evidence",
    description: "Bulk upload receipt images",
    icon: Upload,
    color: "bg-chart-2 text-foreground",
  },
  {
    label: "Analytics",
    description: "View spend analysis & charts",
    icon: FileBarChart,
    color: "bg-chart-3 text-foreground",
  },
  {
    label: "Policy Manual",
    description: "View compliance guidelines",
    icon: Send,
    color: "bg-chart-5 text-foreground",
  },
];

export function QuickActions() {
  return (
    <div className="rounded-xl border border-border bg-card p-5">
      <div className="mb-4">
        <h3 className="text-lg font-semibold">Quick Actions</h3>
        <p className="text-sm text-muted-foreground">Common tasks and shortcuts</p>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {actions.map((action) => (
          <button
            key={action.label}
            className="group flex flex-col items-start gap-3 rounded-lg border border-border bg-background p-4 text-left transition-all hover:border-primary/50 hover:bg-secondary/50"
          >
            <div className={cn("rounded-lg p-2", action.color)}>
              <action.icon className="h-4 w-4" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium text-foreground">{action.label}</p>
              <p className="mt-0.5 text-xs text-muted-foreground">{action.description}</p>
            </div>
            <ArrowRight className="h-4 w-4 text-muted-foreground opacity-0 transition-all group-hover:translate-x-1 group-hover:opacity-100" />
          </button>
        ))}
      </div>
    </div>
  );
}

"use client";

import { cn } from "@/lib/utils";
import { 
  AlertTriangle, 
  AlertCircle, 
  Info, 
  ChevronRight,
  X
} from "lucide-react";

interface Alert {
  id: string;
  type: "critical" | "warning" | "info";
  title: string;
  description: string;
  time: string;
}

const alerts: Alert[] = [
  {
    id: "1",
    type: "critical",
    title: "NO_RECEIPT_FOUND",
    description: "CLM-003: AI detected blank/corrupted image. Manual review required per Article IX.",
    time: "2 hours ago",
  },
  {
    id: "2",
    type: "warning",
    title: "Policy Violation",
    description: "CLM-002: Amount $485 exceeds Tier-1 accommodation limit ($250/night) per Article VI.",
    time: "5 hours ago",
  },
  {
    id: "3",
    type: "info",
    title: "High-Risk Flag",
    description: "CLM-005: Weekend expense flagged. Article VII requires keyword justification.",
    time: "1 day ago",
  },
];

const alertConfig = {
  critical: {
    icon: AlertCircle,
    className: "border-destructive/50 bg-destructive/5",
    iconClassName: "text-destructive",
  },
  warning: {
    icon: AlertTriangle,
    className: "border-warning/50 bg-warning/5",
    iconClassName: "text-warning",
  },
  info: {
    icon: Info,
    className: "border-primary/50 bg-primary/5",
    iconClassName: "text-primary",
  },
};

export function AuditAlerts() {
  return (
    <div className="rounded-xl border border-border bg-card p-5">
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold">AI Policy Alerts</h3>
          <p className="text-sm text-muted-foreground">Claims requiring auditor review</p>
        </div>
        <button className="flex items-center gap-1 text-sm font-medium text-primary hover:underline">
          View All
          <ChevronRight className="h-4 w-4" />
        </button>
      </div>

      <div className="space-y-3">
        {alerts.map((alert) => {
          const config = alertConfig[alert.type];
          return (
            <div
              key={alert.id}
              className={cn(
                "group relative rounded-lg border p-4 transition-colors hover:bg-secondary/30",
                config.className
              )}
            >
              <button className="absolute right-2 top-2 rounded-md p-1 opacity-0 transition-opacity hover:bg-secondary group-hover:opacity-100">
                <X className="h-3.5 w-3.5 text-muted-foreground" />
              </button>
              <div className="flex gap-3">
                <div className={cn("mt-0.5", config.iconClassName)}>
                  <config.icon className="h-5 w-5" />
                </div>
                <div className="flex-1 pr-6">
                  <p className="text-sm font-medium text-foreground">{alert.title}</p>
                  <p className="mt-1 text-xs text-muted-foreground">{alert.description}</p>
                  <p className="mt-2 text-xs text-muted-foreground/70">{alert.time}</p>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

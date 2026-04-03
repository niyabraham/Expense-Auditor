"use client";

import { cn } from "@/lib/utils";

interface Activity {
  id: string;
  user: {
    name: string;
    avatar?: string;
    initials: string;
  };
  action: string;
  target: string;
  time: string;
}

const activities: Activity[] = [
  {
    id: "1",
    user: { name: "AI Engine", initials: "AI" },
    action: "approved",
    target: "CLM-001 Uber $45 - Tier-1 compliant",
    time: "2 min ago",
  },
  {
    id: "2",
    user: { name: "Sarah Chen", initials: "SC" },
    action: "submitted",
    target: "CLM-007 Delta Airlines $1,850",
    time: "15 min ago",
  },
  {
    id: "3",
    user: { name: "AI Engine", initials: "AI" },
    action: "flagged",
    target: "CLM-002 - exceeds Tier-1 limit",
    time: "1 hour ago",
  },
  {
    id: "4",
    user: { name: "Lisa Park", initials: "LP" },
    action: "uploaded",
    target: "receipt for CLM-004",
    time: "2 hours ago",
  },
  {
    id: "5",
    user: { name: "Admin", initials: "AD" },
    action: "rejected",
    target: "CLM-003 - NO_RECEIPT_FOUND",
    time: "3 hours ago",
  },
];

const actionColors: Record<string, string> = {
  approved: "text-success",
  submitted: "text-primary",
  flagged: "text-warning",
  uploaded: "text-chart-5",
  rejected: "text-destructive",
};

export function TeamActivity() {
  return (
    <div className="rounded-xl border border-border bg-card p-5">
      <div className="mb-4">
        <h3 className="text-lg font-semibold">Live Activity</h3>
        <p className="text-sm text-muted-foreground">Real-time AI and team actions</p>
      </div>

      <div className="space-y-4">
        {activities.map((activity, index) => (
          <div key={activity.id} className="flex items-start gap-3">
            <div className="relative">
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-xs font-medium">
                {activity.user.initials}
              </div>
              {index < activities.length - 1 && (
                <div className="absolute left-1/2 top-8 h-6 w-px -translate-x-1/2 bg-border" />
              )}
            </div>
            <div className="flex-1 pt-0.5">
              <p className="text-sm">
                <span className="font-medium text-foreground">{activity.user.name}</span>{" "}
                <span className={cn("font-medium", actionColors[activity.action])}>
                  {activity.action}
                </span>{" "}
                <span className="text-muted-foreground">{activity.target}</span>
              </p>
              <p className="mt-0.5 text-xs text-muted-foreground">{activity.time}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

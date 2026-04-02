"use client";

import { useState } from "react";
import { cn } from "@/lib/utils";
import {
  LayoutDashboard,
  Receipt,
  FileSearch,
  PieChart,
  Users,
  Settings,
  ChevronLeft,
  ChevronRight,
  Building2,
  AlertTriangle,
  FileText,
  CreditCard,
} from "lucide-react";

interface NavItem {
  label: string;
  icon: React.ElementType;
  href: string;
  badge?: string;
  active?: boolean;
}

const mainNavItems: NavItem[] = [
  { label: "Overview", icon: LayoutDashboard, href: "#", active: true },
  { label: "Expenses", icon: Receipt, href: "#", badge: "24" },
  { label: "Audit Log", icon: FileSearch, href: "#" },
  { label: "Analytics", icon: PieChart, href: "#" },
];

const complianceItems: NavItem[] = [
  { label: "Flagged Items", icon: AlertTriangle, href: "#", badge: "3" },
  { label: "Reports", icon: FileText, href: "#" },
  { label: "Policies", icon: FileText, href: "#" },
];

const settingsItems: NavItem[] = [
  { label: "Team", icon: Users, href: "#" },
  { label: "Payments", icon: CreditCard, href: "#" },
  { label: "Settings", icon: Settings, href: "#" },
];

function NavSection({ 
  title, 
  items, 
  collapsed 
}: { 
  title?: string; 
  items: NavItem[]; 
  collapsed: boolean 
}) {
  return (
    <div className="space-y-1">
      {title && !collapsed && (
        <p className="px-3 py-2 text-xs font-medium uppercase tracking-wider text-muted-foreground">
          {title}
        </p>
      )}
      {items.map((item) => (
        <a
          key={item.label}
          href={item.href}
          className={cn(
            "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
            item.active
              ? "bg-primary/10 text-primary"
              : "text-muted-foreground hover:bg-secondary hover:text-foreground"
          )}
        >
          <item.icon className="h-5 w-5 shrink-0" />
          {!collapsed && (
            <>
              <span className="flex-1">{item.label}</span>
              {item.badge && (
                <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-primary/20 px-1.5 text-xs font-semibold text-primary">
                  {item.badge}
                </span>
              )}
            </>
          )}
        </a>
      ))}
    </div>
  );
}

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <aside
      className={cn(
        "flex h-screen flex-col border-r border-border bg-card transition-all duration-300",
        collapsed ? "w-16" : "w-64"
      )}
    >
      {/* Logo */}
      <div className="flex h-16 items-center justify-between border-b border-border px-4">
        {!collapsed && (
          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
              <Building2 className="h-5 w-5 text-primary-foreground" />
            </div>
            <span className="text-lg font-semibold">ExpenseAudit</span>
          </div>
        )}
        {collapsed && (
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary mx-auto">
            <Building2 className="h-5 w-5 text-primary-foreground" />
          </div>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-6 overflow-y-auto p-3">
        <NavSection items={mainNavItems} collapsed={collapsed} />
        <NavSection title="Compliance" items={complianceItems} collapsed={collapsed} />
        <NavSection title="Settings" items={settingsItems} collapsed={collapsed} />
      </nav>

      {/* Collapse Toggle */}
      <div className="border-t border-border p-3">
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="flex w-full items-center justify-center gap-2 rounded-lg bg-secondary px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-secondary/80 hover:text-foreground"
        >
          {collapsed ? (
            <ChevronRight className="h-4 w-4" />
          ) : (
            <>
              <ChevronLeft className="h-4 w-4" />
              <span>Collapse</span>
            </>
          )}
        </button>
      </div>
    </aside>
  );
}

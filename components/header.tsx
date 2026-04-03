"use client";

import { Bell, Search, ChevronDown, Calendar } from "lucide-react";

export function Header() {
  return (
    <header className="flex h-16 items-center justify-between border-b border-border bg-card px-6">
      {/* Left Section */}
      <div className="flex items-center gap-4">
        <h1 className="text-xl font-semibold">Compliance Audit Desk</h1>
        <span className="hidden sm:inline-flex items-center gap-1.5 rounded-full bg-success/10 px-2.5 py-1 text-xs font-medium text-success">
          <span className="h-1.5 w-1.5 rounded-full bg-success animate-pulse" />
          AI Engine Active
        </span>
      </div>

      {/* Right Section */}
      <div className="flex items-center gap-3">
        {/* Search */}
        <div className="relative hidden md:block">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            placeholder="Search claims..."
            className="h-9 w-64 rounded-lg border border-border bg-background pl-9 pr-4 text-sm placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
          />
        </div>

        {/* Date Range Selector */}
        <button className="flex items-center gap-2 rounded-lg border border-border bg-background px-3 py-2 text-sm font-medium text-foreground transition-colors hover:bg-secondary">
          <Calendar className="h-4 w-4 text-muted-foreground" />
          <span>Last 30 days</span>
          <ChevronDown className="h-4 w-4 text-muted-foreground" />
        </button>

        {/* Notifications */}
        <button className="relative flex h-9 w-9 items-center justify-center rounded-lg border border-border bg-background transition-colors hover:bg-secondary">
          <Bell className="h-4 w-4" />
          <span className="absolute -right-1 -top-1 flex h-4 w-4 items-center justify-center rounded-full bg-destructive text-[10px] font-bold text-destructive-foreground">
            3
          </span>
        </button>

        {/* User Avatar */}
        <button className="flex items-center gap-2 rounded-lg p-1 transition-colors hover:bg-secondary">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-primary to-accent text-sm font-semibold text-primary-foreground">
            JD
          </div>
          <ChevronDown className="h-4 w-4 text-muted-foreground" />
        </button>
      </div>
    </header>
  );
}

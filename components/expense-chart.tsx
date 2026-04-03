"use client";

import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import { ChevronRight } from "lucide-react";

const data = [
  { name: "Week 1", approved: 12500, flagged: 2800 },
  { name: "Week 2", approved: 18200, flagged: 3400 },
  { name: "Week 3", approved: 15600, flagged: 1900 },
  { name: "Week 4", approved: 21400, flagged: 2100 },
  { name: "Week 5", approved: 16550, flagged: 1850 },
];

function CustomTooltip({ active, payload, label }: { active?: boolean; payload?: { value: number; dataKey: string }[]; label?: string }) {
  if (active && payload && payload.length) {
    return (
      <div className="rounded-lg border border-border bg-card p-3 shadow-xl">
        <p className="mb-2 text-sm font-medium text-foreground">{label}</p>
        {payload.map((entry, index) => (
          <p key={index} className="text-xs text-muted-foreground">
            <span
              className="mr-2 inline-block h-2 w-2 rounded-full"
              style={{
                backgroundColor:
                  entry.dataKey === "approved"
                    ? "hsl(142, 71%, 45%)"
                    : "hsl(38, 92%, 50%)",
              }}
            />
            {entry.dataKey === "approved" ? "Approved" : "Flagged"}: $
            {entry.value.toLocaleString()}
          </p>
        ))}
      </div>
    );
  }
  return null;
}

export function ExpenseChart() {
  return (
    <div className="rounded-xl border border-border bg-card p-5">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold">Financial Health Overview</h3>
          <p className="text-sm text-muted-foreground">Approved spend vs flagged claims</p>
        </div>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: "hsl(142, 71%, 45%)" }} />
            <span className="text-xs text-muted-foreground">Approved</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: "hsl(38, 92%, 50%)" }} />
            <span className="text-xs text-muted-foreground">Flagged</span>
          </div>
          <button className="flex items-center gap-1 text-xs font-medium text-primary hover:underline">
            View Details
            <ChevronRight className="h-3 w-3" />
          </button>
        </div>
      </div>
      <div className="h-[280px]">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data} margin={{ top: 0, right: 0, left: -20, bottom: 0 }}>
            <defs>
              <linearGradient id="approvedGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="hsl(142, 71%, 45%)" stopOpacity={0.3} />
                <stop offset="100%" stopColor="hsl(142, 71%, 45%)" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="flaggedGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="hsl(38, 92%, 50%)" stopOpacity={0.2} />
                <stop offset="100%" stopColor="hsl(38, 92%, 50%)" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="hsl(0, 0%, 18%)" vertical={false} />
            <XAxis
              dataKey="name"
              axisLine={false}
              tickLine={false}
              tick={{ fill: "hsl(0, 0%, 64%)", fontSize: 12 }}
              dy={10}
            />
            <YAxis
              axisLine={false}
              tickLine={false}
              tick={{ fill: "hsl(0, 0%, 64%)", fontSize: 12 }}
              tickFormatter={(value) => `$${value / 1000}k`}
            />
            <Tooltip content={<CustomTooltip />} />
            <Area
              type="monotone"
              dataKey="flagged"
              stroke="hsl(38, 92%, 50%)"
              strokeWidth={2}
              fill="url(#flaggedGradient)"
            />
            <Area
              type="monotone"
              dataKey="approved"
              stroke="hsl(142, 71%, 45%)"
              strokeWidth={2}
              fill="url(#approvedGradient)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

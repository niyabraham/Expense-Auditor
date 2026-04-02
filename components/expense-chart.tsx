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
  { name: "Jan", expenses: 32000, budget: 45000 },
  { name: "Feb", expenses: 28000, budget: 45000 },
  { name: "Mar", expenses: 41000, budget: 45000 },
  { name: "Apr", expenses: 38000, budget: 45000 },
  { name: "May", expenses: 35000, budget: 45000 },
  { name: "Jun", expenses: 42000, budget: 45000 },
  { name: "Jul", expenses: 39000, budget: 45000 },
  { name: "Aug", expenses: 44000, budget: 45000 },
  { name: "Sep", expenses: 37000, budget: 45000 },
  { name: "Oct", expenses: 43000, budget: 45000 },
  { name: "Nov", expenses: 46000, budget: 45000 },
  { name: "Dec", expenses: 41000, budget: 45000 },
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
                  entry.dataKey === "expenses"
                    ? "hsl(262, 83%, 58%)"
                    : "hsl(173, 80%, 40%)",
              }}
            />
            {entry.dataKey === "expenses" ? "Expenses" : "Budget"}: $
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
          <h3 className="text-lg font-semibold">Expense Overview</h3>
          <p className="text-sm text-muted-foreground">Monthly expense tracking vs budget</p>
        </div>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full bg-primary" />
            <span className="text-xs text-muted-foreground">Expenses</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full bg-chart-2" />
            <span className="text-xs text-muted-foreground">Budget</span>
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
              <linearGradient id="expenseGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="hsl(262, 83%, 58%)" stopOpacity={0.3} />
                <stop offset="100%" stopColor="hsl(262, 83%, 58%)" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="budgetGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="hsl(173, 80%, 40%)" stopOpacity={0.2} />
                <stop offset="100%" stopColor="hsl(173, 80%, 40%)" stopOpacity={0} />
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
              dataKey="budget"
              stroke="hsl(173, 80%, 40%)"
              strokeWidth={2}
              fill="url(#budgetGradient)"
            />
            <Area
              type="monotone"
              dataKey="expenses"
              stroke="hsl(262, 83%, 58%)"
              strokeWidth={2}
              fill="url(#expenseGradient)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

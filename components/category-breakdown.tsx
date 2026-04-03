"use client";

import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from "recharts";
import { formatCurrency } from "@/lib/utils";

const data = [
  { name: "Approved", value: 47, color: "hsl(142, 71%, 45%)" },
  { name: "Flagged", value: 8, color: "hsl(38, 92%, 50%)" },
  { name: "Rejected", value: 5, color: "hsl(0, 72%, 51%)" },
];

const total = data.reduce((acc, item) => acc + item.value, 0);

function CustomTooltip({ active, payload }: { active?: boolean; payload?: { payload: { name: string; value: number } }[] }) {
  if (active && payload && payload.length) {
    const item = payload[0].payload;
    return (
      <div className="rounded-lg border border-border bg-card p-3 shadow-xl">
        <p className="text-sm font-medium text-foreground">{item.name}</p>
        <p className="text-xs text-muted-foreground">
          {item.value} claims ({((item.value / total) * 100).toFixed(1)}%)
        </p>
      </div>
    );
  }
  return null;
}

export function CategoryBreakdown() {
  return (
    <div className="rounded-xl border border-border bg-card p-5">
      <div className="mb-4">
        <h3 className="text-lg font-semibold">AI Audit Status</h3>
        <p className="text-sm text-muted-foreground">Claims by AI decision</p>
      </div>

      <div className="flex flex-col gap-6 lg:flex-row lg:items-center">
        <div className="relative h-[180px] w-full lg:w-[180px]">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={data}
                cx="50%"
                cy="50%"
                innerRadius={55}
                outerRadius={80}
                paddingAngle={3}
                dataKey="value"
                strokeWidth={0}
              >
                {data.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <p className="text-xs text-muted-foreground">Total</p>
            <p className="text-lg font-bold">{total}</p>
          </div>
        </div>

        <div className="flex-1 space-y-3">
          {data.map((category) => (
            <div key={category.name} className="flex items-center gap-3">
              <span
                className="h-3 w-3 shrink-0 rounded-full"
                style={{ backgroundColor: category.color }}
              />
              <div className="flex flex-1 items-center justify-between">
                <span className="text-sm text-muted-foreground">{category.name}</span>
                <div className="text-right">
                  <span className="text-sm font-medium">{category.value} claims</span>
                  <span className="ml-2 text-xs text-muted-foreground">
                    {((category.value / total) * 100).toFixed(0)}%
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

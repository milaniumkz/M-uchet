import { accountReference } from "./legal.js";
import { fail } from "./security.js";

// Internal report classification from the researched 2026 reference, not a
// posting policy or an assertion that a statutory financial form is complete.
const categories = new Map();
for (const account of accountReference("2026-01-01").accounts) {
  if (account.group) continue;
  if (account.code.startsWith("6"))
    categories.set(
      account.code,
      account.code.startsWith("60") ? "revenue" : "otherIncome",
    );
  if (account.code.startsWith("7"))
    categories.set(account.code, account.code === "7010" ? "cogs" : "expenses");
}
categories.set("revenue", "revenue");
categories.set("inventory_surplus", "otherIncome");
categories.set("cogs", "cogs");
for (const account of [
  "expenses",
  "inventory_loss",
  "depreciation",
  "asset_disposal_loss",
  "salary_expense",
  "payroll_employer_expense",
])
  categories.set(account, "expenses");

export const profitBucket = () => ({
  revenue: 0n,
  cogs: 0n,
  expenses: 0n,
  otherIncome: 0n,
});
export function accumulateProfit(bucket, lines) {
  for (const line of lines) {
    const category = categories.get(line.account);
    if (!category) continue;
    const debit = BigInt(line.debit),
      credit = BigInt(line.credit);
    bucket[category] += ["revenue", "otherIncome"].includes(category)
      ? credit - debit
      : debit - credit;
  }
}
export function profitResult(bucket) {
  const values = {
    ...bucket,
    revenue: bucket.revenue + bucket.otherIncome,
    salesRevenue: bucket.revenue,
    costs: bucket.cogs + bucket.expenses,
    grossProfit: bucket.revenue - bucket.cogs,
    netProfit:
      bucket.revenue + bucket.otherIncome - bucket.cogs - bucket.expenses,
  };
  return Object.fromEntries(
    Object.entries(values).map(([key, value]) => {
      if (
        value > BigInt(Number.MAX_SAFE_INTEGER) ||
        value < BigInt(Number.MIN_SAFE_INTEGER)
      )
        fail(422, "report_amount_overflow");
      return [key, Number(value)];
    }),
  );
}

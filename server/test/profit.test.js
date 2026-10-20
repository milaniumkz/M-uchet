import { test } from "node:test";
import assert from "node:assert/strict";
import { profitBucket, accumulateProfit, profitResult } from "../src/profit.js";

test("sales returns reduce sales while financial income affects net profit without inflating gross profit", () => {
  const bucket = profitBucket();
  accumulateProfit(bucket, [
    { account: "6010", debit: 0, credit: 10000 },
    { account: "6020", debit: 1000, credit: 0 },
    { account: "6030", debit: 500, credit: 0 },
    { account: "7010", debit: 3000, credit: 0 },
    { account: "6110", debit: 0, credit: 700 },
    { account: "6290", debit: 200, credit: 0 },
    { account: "7210", debit: 800, credit: 0 },
    { account: "1010", debit: 1234, credit: 0 },
  ]);
  assert.deepEqual(profitResult(bucket), {
    revenue: 9000,
    cogs: 3000,
    expenses: 800,
    otherIncome: 500,
    salesRevenue: 8500,
    costs: 3800,
    grossProfit: 5500,
    netProfit: 5200,
  });
});
test("intermediate aggregation above the safe Number limit does not lose a minor unit after a reversal", () => {
  const bucket = profitBucket(),
    maximum = Number.MAX_SAFE_INTEGER;
  accumulateProfit(bucket, [
    { account: "revenue", credit: maximum, debit: 0 },
    { account: "revenue", credit: 1, debit: 0 },
    { account: "revenue", credit: 0, debit: maximum },
  ]);
  assert.equal(profitResult(bucket).revenue, 1);
});
test("combined costs and income overflow are rejected even when each input subtotal and net profit fit", () => {
  const max = BigInt(Number.MAX_SAFE_INTEGER);
  assert.throws(
    () =>
      profitResult({ revenue: max, otherIncome: 0n, cogs: max, expenses: 1n }),
    (e) => e.statusCode === 422 && e.code === "report_amount_overflow",
  );
  assert.throws(
    () =>
      profitResult({ revenue: max, otherIncome: 1n, cogs: max, expenses: 1n }),
    (e) => e.statusCode === 422 && e.code === "report_amount_overflow",
  );
});

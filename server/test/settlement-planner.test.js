import { test } from "node:test";
import assert from "node:assert/strict";
import { planSettlements } from "../src/settlement-planner.js";
const payment = (id, amount, date, kind = "PAYMENT") => ({
  id,
  amount,
  business_date: `2026-10-${date}`,
  kind,
});
const plan = (payments) =>
  planSettlements({
    recognized: true,
    total: 100,
    recognitionDate: "2026-10-20",
    payments,
  });
test("dated allocation applies only pre-recognition cash and splits later excess", () => {
  const result = plan([
    payment("later", 100, "25"),
    payment("advance", 40, "19"),
  ]);
  assert.equal(result.applied, 40);
  assert.deepEqual(
    result.allocations.map((a) => [
      a.payment.id,
      a.debtAmount,
      a.advanceAmount,
    ]),
    [
      ["advance", 0, 40],
      ["later", 60, 40],
    ],
  );
  assert.equal(result.outstanding, 0);
  assert.equal(result.advance, 40);
  assert.equal(result.paid, 140);
});
test("refund first consumes excess, then reopens debt without changing recognition", () => {
  const result = plan([
    payment("paid", 140, "21"),
    payment("refunded", 70, "22", "REFUND"),
  ]);
  assert.equal(result.applied, 0);
  assert.equal(result.allocations[1].advanceAmount, 40);
  assert.equal(result.allocations[1].debtAmount, 30);
  assert.equal(result.outstanding, 30);
  assert.equal(result.advance, 0);
  assert.equal(result.paid, 70);
});
test("refund before recognition reduces the advance application", () => {
  const result = plan([
    payment("paid", 140, "18"),
    payment("refunded", 70, "19", "REFUND"),
  ]);
  assert.equal(result.applied, 70);
  assert.equal(result.outstanding, 30);
  assert.equal(result.advance, 0);
});
test("same-day receipts precede refunds and recognition precedes both", () => {
  const result = plan([
    payment("refund", 70, "20", "REFUND"),
    payment("receipt", 140, "20"),
  ]);
  assert.equal(result.applied, 0);
  assert.equal(result.allocations[0].payment.id, "receipt");
  assert.equal(result.outstanding, 30);
});
test("cancelled and invoice cash remains an advance after partial refund", () => {
  const result = planSettlements({
    recognized: false,
    total: 100,
    recognitionDate: "2026-10-20",
    payments: [
      payment("paid", 100, "21"),
      payment("refund", 30, "22", "REFUND"),
    ],
  });
  assert.equal(result.outstanding, 0);
  assert.equal(result.advance, 70);
  assert.equal(result.applied, 0);
});
test("refund cannot use a later receipt or exceed actual net payments", () => {
  for (const payments of [
    [payment("receipt", 100, "22"), payment("refund", 10, "21", "REFUND")],
    [payment("receipt", 100, "20"), payment("refund", 101, "21", "REFUND")],
  ])
    assert.throws(
      () => plan(payments),
      (e) => e.code === "refund_exceeds_paid_on_date",
    );
});
test("chronological allocation preserves exact integers and does not mutate its input", () => {
  const payments = [
    payment("b", 1000000000000, "21"),
    payment("a", 1000000000000, "19"),
    payment("c", 999999999999, "22", "REFUND"),
  ];
  const before = JSON.stringify(payments),
    result = plan(payments);
  assert.equal(JSON.stringify(payments), before);
  assert.equal(result.paid, 1000000000001);
  assert.equal(result.advance, 999999999901);
  assert.equal(result.outstanding, 0);
});

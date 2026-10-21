import { businessDate, fail, integer } from "./security.js";

// All amounts remain integer minor units. Recognition precedes money events on
// the same business date; receipts precede refunds within that date.
export function planSettlements({
  recognized,
  total,
  recognitionDate,
  payments,
}) {
  integer(total, "total", 1);
  businessDate(recognitionDate);
  const sorted = payments
    .map((payment) => {
      integer(payment.amount, "amount", 1);
      businessDate(payment.business_date);
      if (!["PAYMENT", "REFUND"].includes(payment.kind ?? "PAYMENT"))
        fail(400, "invalid_payment_kind");
      return { ...payment, kind: payment.kind ?? "PAYMENT" };
    })
    .sort(
      (a, b) =>
        a.business_date.localeCompare(b.business_date) ||
        Number(a.kind === "REFUND") - Number(b.kind === "REFUND") ||
        String(a.created_at ?? "").localeCompare(String(b.created_at ?? "")) ||
        String(a.id).localeCompare(String(b.id)),
    );
  let claim = 0n,
    advance = 0n,
    paid = 0n,
    applied = 0n,
    posted = false;
  const recognize = () => {
    if (!recognized || posted) return;
    posted = true;
    claim = BigInt(total);
    applied = advance < claim ? advance : claim;
    claim -= applied;
    advance -= applied;
  };
  const allocations = sorted.map((payment) => {
    if (payment.business_date >= recognitionDate) recognize();
    const amount = BigInt(payment.amount);
    let debtAmount, advanceAmount;
    if (payment.kind === "REFUND") {
      if (amount > paid) fail(409, "refund_exceeds_paid_on_date");
      advanceAmount = advance < amount ? advance : amount;
      debtAmount = amount - advanceAmount;
      advance -= advanceAmount;
      claim += debtAmount;
      paid -= amount;
    } else {
      debtAmount = claim < amount ? claim : amount;
      advanceAmount = amount - debtAmount;
      claim -= debtAmount;
      advance += advanceAmount;
      paid += amount;
    }
    return {
      payment,
      debtAmount: Number(debtAmount),
      advanceAmount: Number(advanceAmount),
    };
  });
  recognize();
  if (
    [claim, advance, paid].some(
      (value) => value > BigInt(Number.MAX_SAFE_INTEGER),
    )
  )
    fail(422, "settlement_amount_out_of_range");
  return {
    allocations,
    applied: Number(applied),
    paid: Number(paid),
    outstanding: Number(claim),
    advance: Number(advance),
  };
}

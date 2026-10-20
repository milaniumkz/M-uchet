import { test } from "node:test";
import assert from "node:assert/strict";
import {
  calculatePayroll2026,
  annualIPN2026,
  payrollRules2026,
} from "../src/payroll-calculation.js";
const input = (extra = {}) => ({
  month: "2026-01",
  gross: 30000000,
  category: "ORDINARY_CASH_SALARY",
  singleEmployer: true,
  company: { legalForm: "TOO", taxRegime: "GENERAL" },
  employee: {
    birthDate: "1990-01-01",
    hireDate: "2025-01-01",
    resident: true,
    citizenship: "KZ",
    sex: "M",
    standardDeductionDeclaration: true,
  },
  ...extra,
});
test("ordinary resident payroll separates employee and employer charges with documented bases", () => {
  const r = calculatePayroll2026(input());
  assert.equal(r.opv, 3000000);
  assert.equal(r.vosms, 600000);
  assert.equal(r.ipn, 1342500);
  assert.equal(r.net, 25057500);
  assert.equal(r.so, 1350000);
  assert.equal(r.oosms, 900000);
  assert.equal(r.opvr, 1050000);
  assert.equal(r.sn, 1584000);
  assert.equal(r.totalCost, 34884000);
});
test("SO rounds every nonzero tiyn up while OSMS uses the fifty tiyn boundary", () => {
  const r = calculatePayroll2026(input({ gross: 30000001 }));
  assert.equal(r.so, 1350100);
  assert.equal(r.vosms, 600000);
  assert.equal(r.oosms, 900000);
  assert.equal(calculatePayroll2026(input({ gross: 30002499 })).vosms, 600000);
  assert.equal(calculatePayroll2026(input({ gross: 30002500 })).vosms, 600100);
});
test("contribution caps, floors and the birth cutoff are applied independently", () => {
  const low = calculatePayroll2026(input({ gross: 1000000 }));
  assert.equal(low.so, 425000);
  assert.equal(low.opvr, 297500);
  assert.equal(low.ipn, 0);
  assert.equal(low.sn, 363300);
  const high = calculatePayroll2026(input({ gross: 1000000000 }));
  assert.equal(high.opv, 42500000);
  assert.equal(high.vosms, 3400000);
  assert.equal(high.oosms, 10200000);
  assert.equal(high.opvr, 14875000);
  assert.equal(high.so, 2975000);
  const old = calculatePayroll2026(
    input({ employee: { ...input().employee, birthDate: "1974-12-31" } }),
  );
  assert.equal(old.opvr, 0);
  assert.equal(old.opv, 3000000);
  const young = calculatePayroll2026(
    input({ employee: { ...input().employee, birthDate: "1975-01-01" } }),
  );
  assert.equal(young.opvr, 1050000);
});
test("social tax distinguishes simplified regime, IP head count and a hiring month", () => {
  assert.equal(
    calculatePayroll2026(
      input({ company: { legalForm: "TOO", taxRegime: "SIMPLIFIED" } }),
    ).sn,
    0,
  );
  assert.equal(
    calculatePayroll2026(
      input({ company: { legalForm: "IP", taxRegime: "GENERAL" } }),
    ).sn,
    432500,
  );
  const low = calculatePayroll2026(
    input({
      gross: 1000000,
      employee: { ...input().employee, hireDate: "2026-01-10" },
    }),
  );
  assert.equal(low.sn, 52800);
});
test("IPN uses the annual threshold and carries unused basic deductions within the employer", () => {
  const threshold = 8500 * payrollRules2026.mrp;
  assert.equal(
    annualIPN2026(threshold + 10000) - annualIPN2026(threshold),
    1500,
  );
  const jan = calculatePayroll2026(input({ gross: 1000000 }));
  assert.equal(jan.basicUsed, 880000);
  assert.equal(jan.ytd.basicCarry, 12095000);
  const feb = calculatePayroll2026(input({ month: "2026-02", prior: jan.ytd }));
  assert.equal(feb.basicUsed, 25070000);
  assert.equal(feb.taxableBase, 1330000);
  assert.equal(feb.ipn, 133000);
});
test("unresearched categories, pension transitions and unsupported years fail explicitly", () => {
  for (const value of [
    input({ month: "2027-01" }),
    input({ singleEmployer: false }),
    input({ category: "GPH" }),
    input({ employee: { ...input().employee, birthDate: "1963-01-15" } }),
    input({ employee: { ...input().employee, resident: false } }),
  ])
    assert.throws(
      () => calculatePayroll2026(value),
      (e) => e.statusCode === 422,
    );
});

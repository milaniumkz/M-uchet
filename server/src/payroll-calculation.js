import { businessDate, fail, integer } from "./security.js";

export const payrollRules2026 = Object.freeze({
  version: "KZ_REGULAR_RESIDENT_PAYROLL_2026_V1",
  currency: "KZT",
  mrp: 432500,
  mzp: 8500000,
  legalStatus:
    "SELECTED_PRIMARY_RULES_TECHNICAL_IMPLEMENTATION_NOT_ACCOUNTANT_ACCEPTED",
  sources: [
    "K2500000214",
    "K2300000224",
    "Z1500000405",
    "Z2500000239",
    "P2300000525",
    "P2300000540",
    "V1700015361",
    "V2300032897",
  ],
  accountingRounding: "HALF_UP_MINOR",
  osmsRounding: "HALF_UP_WHOLE_TENGE",
  socialContributionsRounding: "CEILING_WHOLE_TENGE",
  scope: "ORDINARY_CASH_SALARY_RESIDENT_KZ_EMPLOYEE_NO_SPECIAL_EXEMPTIONS",
});
const percentage = (minor, bps) =>
  Number((BigInt(minor) * BigInt(bps) + 5000n) / 10000n);
const wholeTenge = (minor, bps, ceil = false) =>
  Number(
    (BigInt(minor) * BigInt(bps) + (ceil ? 999999n : 500000n)) / 1000000n,
  ) * 100;
export function annualIPN2026(taxableBase) {
  integer(taxableBase, "taxableBase");
  const threshold = 8500 * payrollRules2026.mrp;
  return (
    percentage(Math.min(taxableBase, threshold), 1000) +
    percentage(Math.max(0, taxableBase - threshold), 1500)
  );
}
export function calculatePayroll2026(input) {
  const { company, employee } = input,
    month = input.month;
  if (typeof month !== "string" || !/^2026-(0[1-9]|1[0-2])$/.test(month))
    fail(422, "payroll_rule_period_not_supported");
  if (company?.currency !== undefined && company.currency !== "KZT")
    fail(422, "payroll_currency_not_supported");
  if (
    !company ||
    !["TOO", "IP"].includes(company.legalForm) ||
    !["GENERAL", "SIMPLIFIED"].includes(company.taxRegime)
  )
    fail(422, "payroll_company_profile_required");
  if (
    !employee ||
    employee.resident !== true ||
    employee.citizenship !== "KZ" ||
    input.category !== "ORDINARY_CASH_SALARY" ||
    input.singleEmployer !== true
  )
    fail(422, "payroll_category_not_supported");
  if (
    employee.specialCategory !== undefined &&
    employee.specialCategory !== "NONE"
  )
    fail(422, "payroll_category_not_supported");
  if (!employee.birthDate) fail(422, "payroll_birth_date_required");
  const birth = businessDate(employee.birthDate),
    hire = businessDate(employee.hireDate),
    termination = employee.terminationDate
      ? businessDate(employee.terminationDate)
      : null;
  const first = month + "-01",
    last = new Date(Date.UTC(2026, Number(month.slice(5)), 0))
      .toISOString()
      .substring(0, 10);
  if (hire > last || (termination && termination < first))
    fail(422, "employee_not_employed_in_month");
  // A category transition inside the month needs separately identified income;
  // silently applying one status to the whole month would change contributions.
  const eighteenth = `${Number(birth.slice(0, 4)) + 18}${birth.slice(4)}`;
  if (eighteenth > first || birth > first)
    fail(422, "payroll_age_or_transition_not_supported");
  if (!["M", "F"].includes(employee.sex)) fail(422, "payroll_sex_required");
  const pensionAge = employee.sex === "M" ? 63 : 61,
    pensionDate = `${Number(birth.slice(0, 4)) + pensionAge}${birth.slice(4)}`;
  if (pensionDate <= last) fail(422, "payroll_pension_category_not_supported");
  if (typeof employee.standardDeductionDeclaration !== "boolean")
    fail(400, "invalid_employee_profile");
  const gross = integer(input.gross, "gross"),
    p = input.prior ?? {};
  const previous = {
    taxableBase: integer(p.taxableBase ?? 0, "priorTaxableBase"),
    ipn: integer(p.ipn ?? 0, "priorIPN"),
    basicUsed: integer(p.basicUsed ?? 0, "priorBasicUsed"),
    basicCarry: integer(p.basicCarry ?? 0, "priorBasicCarry"),
    opvBase: integer(p.opvBase ?? 0, "priorOPVBase"),
  };
  const { mrp, mzp } = payrollRules2026,
    annualBasic = 360 * mrp,
    elapsed = Number(month.slice(5)) - 1;
  if (
    previous.basicUsed + previous.basicCarry >
      Math.min(annualBasic, elapsed * 30 * mrp) ||
    previous.opvBase > elapsed * 50 * mzp ||
    (elapsed === 0 && (previous.taxableBase !== 0 || previous.ipn !== 0))
  )
    fail(400, "invalid_payroll_opening_context");
  const opvBase = Math.min(
      gross,
      50 * mzp,
      Math.max(0, 600 * mzp - previous.opvBase),
    ),
    opv = percentage(opvBase, 1000);
  const vosmsBase = Math.min(gross, 20 * mzp),
    vosms = wholeTenge(vosmsBase, 200);
  const allowance = employee.standardDeductionDeclaration
    ? Math.min(30 * mrp + previous.basicCarry, annualBasic - previous.basicUsed)
    : 0;
  const beforeBasic = Math.max(0, gross - opv - vosms),
    basicUsed = Math.min(beforeBasic, allowance),
    taxableBase = beforeBasic - basicUsed;
  const cumulativeTaxable = previous.taxableBase + taxableBase;
  integer(cumulativeTaxable, "cumulativeTaxable");
  const assessed = annualIPN2026(cumulativeTaxable),
    ipn = assessed - previous.ipn,
    net = gross - opv - vosms - ipn;
  if (net < 0) fail(422, "payroll_withholding_exceeds_gross");
  const soBase = gross ? Math.min(7 * mzp, Math.max(mzp, gross - opv)) : 0,
    so = wholeTenge(soBase, 500, true);
  const oosmsBase = Math.min(gross, 40 * mzp),
    oosms = wholeTenge(oosmsBase, 300);
  const opvrEligible = birth >= "1975-01-01",
    opvrBase =
      gross && opvrEligible ? Math.min(50 * mzp, Math.max(mzp, gross)) : 0,
    opvr = percentage(opvrBase, 350);
  const hiredOrTerminated =
    hire.startsWith(month) || termination?.startsWith(month);
  const snObject = Math.max(0, gross - opv - vosms),
    snBase =
      snObject && !hiredOrTerminated ? Math.max(14 * mrp, snObject) : snObject;
  const sn =
    company.taxRegime === "SIMPLIFIED"
      ? 0
      : company.legalForm === "IP"
        ? mrp
        : percentage(snBase, 600);
  const employer = so + oosms + opvr + sn;
  const result = {
    ruleVersion: payrollRules2026.version,
    month,
    gross,
    opv,
    vosms,
    ipn,
    net,
    employeeWithholdings: opv + vosms + ipn,
    so,
    oosms,
    opvr,
    sn,
    employerContributions: employer,
    totalCost: gross + employer,
    basicUsed,
    taxableBase,
    ytd: {
      taxableBase: cumulativeTaxable,
      ipn: assessed,
      basicUsed: previous.basicUsed + basicUsed,
      basicCarry: employee.standardDeductionDeclaration
        ? allowance - basicUsed
        : previous.basicCarry,
      opvBase: previous.opvBase + opvBase,
    },
    breakdown: [
      {
        code: "OPV",
        base: opvBase,
        basisPoints: 1000,
        amount: opv,
        rounding: "HALF_UP_MINOR",
        source: "K2300000224:249;P2300000525:6",
      },
      {
        code: "VOSMS",
        base: vosmsBase,
        basisPoints: 200,
        amount: vosms,
        rounding: "HALF_UP_WHOLE_TENGE",
        source: "Z1500000405:28;V1700015361:39",
      },
      {
        code: "IPN",
        base: taxableBase,
        annualThreshold: 8500 * mrp,
        amount: ipn,
        rounding: "HALF_UP_MINOR_CUMULATIVE",
        source: "K2500000214:363,403,437,438,439,441",
      },
      {
        code: "SO",
        base: soBase,
        basisPoints: 500,
        amount: so,
        rounding: "CEILING_WHOLE_TENGE",
        source: "K2300000224:243,244,245;V2300032897:9,14",
      },
      {
        code: "OOSMS",
        base: oosmsBase,
        basisPoints: 300,
        amount: oosms,
        rounding: "HALF_UP_WHOLE_TENGE",
        source: "Z1500000405:27;V1700015361:39",
      },
      {
        code: "OPVR",
        base: opvrBase,
        basisPoints: opvrEligible ? 350 : 0,
        amount: opvr,
        rounding: "HALF_UP_MINOR",
        source: "K2300000224:248(6),251;P2300000540:6",
      },
      {
        code: "SN",
        base: snBase,
        basisPoints:
          company.taxRegime === "GENERAL" && company.legalForm === "TOO"
            ? 600
            : 0,
        fixedMRP:
          company.taxRegime === "GENERAL" && company.legalForm === "IP" ? 1 : 0,
        amount: sn,
        rounding: "HALF_UP_MINOR",
        source: "K2500000214:555,556,557,558",
      },
    ],
    scope: payrollRules2026.scope,
    excludes: [
      "SPECIAL_EXEMPTIONS",
      "NONRESIDENTS",
      "GPH",
      "BENEFITS_AND_IN_KIND_INCOME",
      "HOLIDAY_AND_SICK_LEAVE_CALCULATIONS",
      "UNIFIED_PAYMENT",
      "IP_SELF_TAX",
      "OFFICIAL_DECLARATION_EXPORT",
    ],
  };
  for (const value of [
    gross,
    opv,
    vosms,
    ipn,
    net,
    so,
    oosms,
    opvr,
    sn,
    employer,
    result.totalCost,
  ])
    if (!Number.isSafeInteger(value)) fail(422, "payroll_amount_overflow");
  return result;
}

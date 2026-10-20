// Business commands own financial registers; they are never exposed as arbitrary JSON writes.
export const resourceGroups = {
  catalog: ['nomenklatura','nomenclature_categories','warehouses','shops','clients','suppliers',
    'services','service_categories','service_cost_models','statRashod','country','valuta','nalogi','taxes','forma','oced','otrasli'],
  organization: ['company_profile','company_branches','company_departments','employees','staff_schedule'],
  planning: ['budget_projects','expense_plans','fin_models','marketing_campaigns','funding_requests','funding_request_categories'],
  devices: ['devices'],
  support: ['support_tickets'],
};
export const kinds = Object.fromEntries(Object.entries(resourceGroups).flatMap(([group, list]) => list.map(kind => [kind, group])));
export const permissions = [
  ...Object.keys(resourceGroups).flatMap(group => [`${group}.read`, `${group}.write`]),
  'inventory.read','inventory.receive','inventory.move','inventory.writeoff','orders.read','orders.write','orders.fulfill',
  'accounting.read','accounting.post','payments.write','files.read','files.write','audit.read',
  'wallets.read','wallets.write','wallets.transact','debts.read','debts.write','debts.settle',
  'shifts.read','shifts.write','devices.command','reports.read',
  'periods.close','periods.reopen',
  'accounting.edit','orders.edit','projects.read','projects.write',
];

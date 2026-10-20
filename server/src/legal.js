import { readFile } from 'node:fs/promises';
import { businessDate, fail } from './security.js';
const chart = JSON.parse(await readFile(new URL('../../docs/legal/chart-of-accounts-2026.json',import.meta.url),'utf8'));
export function accountReference(date) {
  const selected = businessDate(date);
  if (selected < chart.supported_from || selected > chart.supported_to) fail(422,'chart_reference_period_not_researched');
  return { ...chart, selectedDate: selected };
}

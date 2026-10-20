import { fail, businessDate, integer, text } from './security.js';

// RFC4180 quoting; limits bound CPU/memory before database work. No executable cells.
export function parseCSV(source, delimiter = ';') {
  if (typeof source !== 'string' || Buffer.byteLength(source) > 750000 || !source.trim()) fail(400, 'invalid_bank_csv');
  if (![',', ';', '\t'].includes(delimiter)) fail(400, 'invalid_csv_delimiter');
  source = source.replace(/^\uFEFF/, '');
  const rows = []; let row = [], cell = '', quoted = false, closed = false;
  const append = () => { if (cell.length > 4000 || row.length >= 50) fail(400, 'bank_csv_limit'); row.push(cell); cell = ''; closed = false; };
  const finish = () => { append(); if (row.some(c => c.trim())) rows.push(row); row = []; if (rows.length > 501) fail(400, 'bank_csv_limit'); };
  for (let i = 0; i < source.length; i++) {
    const char = source[i];
    if (quoted) {
      if (char === '"') { if (source[i + 1] === '"') { cell += '"'; i++; } else { quoted = false; closed = true; } }
      else cell += char;
    } else if (char === '"') {
      if (cell || closed) fail(400, 'invalid_bank_csv'); quoted = true;
    } else if (char === delimiter) append();
    else if (char === '\r' || char === '\n') { if (char === '\r' && source[i + 1] === '\n') i++; finish(); }
    else { if (closed) fail(400, 'invalid_bank_csv'); cell += char; }
  }
  if (quoted) fail(400, 'invalid_bank_csv');
  if (cell || row.length || closed) finish();
  if (rows.length < 2) fail(400, 'bank_csv_no_rows');
  const headers = rows.shift().map(c => c.trim());
  if (new Set(headers).size !== headers.length || headers.some(h => !h)) fail(400, 'invalid_bank_csv_headers');
  if (rows.some(r => r.length !== headers.length)) fail(400, 'invalid_bank_csv_columns');
  return { headers, rows };
}
export function bankMoney(value) {
  const normalized = value.replace(/[\s\u00a0]/g, '').replace(',', '.');
  if (!/^\d{1,10}(\.\d{1,2})?$/.test(normalized)) fail(400, 'invalid_bank_amount');
  const [whole, fraction = ''] = normalized.split('.');
  return integer(Number(whole) * 100 + Number(fraction.padEnd(2, '0')), 'bank_amount');
}
export function bankRows(body) {
  const { headers, rows } = parseCSV(body.csv, body.delimiter);
  const mapping = body.mapping ?? { date: 'date', reference: 'reference', debit: 'debit', credit: 'credit', description: 'description', counterparty: 'counterparty' };
  if (typeof mapping !== 'object' || Array.isArray(mapping)) fail(400, 'invalid_bank_mapping');
  for (const key of ['date','reference','debit','credit','description']) if (!headers.includes(mapping[key])) fail(400, 'invalid_bank_mapping');
  const value = (r, key) => headers.includes(mapping[key]) ? r[headers.indexOf(mapping[key])].trim() : '';
  return rows.map((row, index) => {
    const debit = bankMoney(value(row, 'debit') || '0'), credit = bankMoney(value(row, 'credit') || '0');
    if ((debit === 0) === (credit === 0)) fail(400, 'bank_row_requires_one_direction');
    let date = value(row, 'date');
    if (/^\d{2}\.\d{2}\.\d{4}$/.test(date)) date = date.split('.').reverse().join('-');
    return { position: index + 2, externalId: text(value(row,'reference'),'bank_reference',200),
      businessDate: businessDate(date), amount: credit - debit,
      description: text(value(row,'description'),'description',500), counterparty: value(row,'counterparty').slice(0,250) };
  });
}

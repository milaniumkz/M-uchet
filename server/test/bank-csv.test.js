import {test} from 'node:test';
import assert from 'node:assert/strict';
import {parseCSV,bankRows} from '../src/bank-csv.js';
test('CSV quoting preserves Cyrillic, embedded delimiters, escaped quotes and newlines',()=>{
 const parsed=parseCSV('\uFEFFdate;reference;debit;credit;description\r\n2026-10-20;id;0;1,25;"Текст; ""кавычки""\nвторая строка"\r\n');
 assert.equal(parsed.rows[0][4],'Текст; "кавычки"\nвторая строка');
 assert.equal(bankRows({csv:'date,reference,debit,credit,description\n2026-10-20,id,0,"1,25",ТЕСТ',delimiter:','})[0].amount,125);
});
test('CSV rejects malformed boundaries, ambiguous directions and invalid dates before import',()=>{
 for(const csv of ['a;a\n1;2','a;b\n"unclosed;2','a;b\n"closed"junk;2','a;b\n1;2;3'])assert.throws(()=>parseCSV(csv),e=>e.statusCode===400);
 assert.throws(()=>bankRows({csv:'date;reference;debit;credit;description\n2026-02-30;id;0;1;ТЕСТ'}),e=>e.code==='invalid_business_date');
 assert.throws(()=>bankRows({csv:'date;reference;debit;credit;description\n2026-10-20;id;0;0;ТЕСТ'}),e=>e.code==='bank_row_requires_one_direction');
 assert.throws(()=>parseCSV('a\n'+Array(501).fill('x').join('\n')),e=>e.code==='bank_csv_limit');
});

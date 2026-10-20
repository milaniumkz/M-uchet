import { existsSync, writeFileSync, chmodSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
if (process.versions.node.split('.')[0] !== '24') throw new Error('Node.js 24.x required');
if (!existsSync('.env')) {
  const password = randomBytes(32).toString('base64url');
  const directory = new URL('../.runtime/data', import.meta.url).pathname;
  writeFileSync('.env', `APP_ENV=development\nDB_PASSWORD=${password}\nDATABASE_URL=postgresql://muchet:${password}@127.0.0.1:55432/muchet\nHOST=127.0.0.1\nPORT=8080\nDATA_DIR=${directory}\nALLOW_REGISTRATION=false\n`, { flag: 'wx', mode: 0o600 });
  chmodSync('.env', 0o600);
  console.log('Created private development settings; values are not logged.');
} else console.log('Existing .env preserved.');

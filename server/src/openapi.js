import { writeFile } from 'node:fs/promises';
import { createApp } from './app.js';
const app=await createApp();
try { await writeFile(new URL('../../docs/openapi.json',import.meta.url),JSON.stringify(app.swagger(),null,2)+'\n');console.log('Saved docs/openapi.json from registered API routes.'); }
finally { await app.close(); }

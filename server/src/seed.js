import { randomBytes } from 'node:crypto';
import { writeFile, mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { openDatabase, transaction } from './db.js';
import { hashPassword } from './security.js';
if(process.env.APP_ENV!=='development')throw Error('Synthetic seed is restricted to APP_ENV=development');
const db=await openDatabase();
try {
 const id='synthetic-owner', company='synthetic-company';
 if(await db.prepare('SELECT 1 FROM users WHERE id=?').get(id)){console.log('Synthetic seed already exists; preserved existing credentials.');}
 else {
  const password=randomBytes(24).toString('base64url'), hash=await hashPassword(password);
  const directory=resolve('../.runtime');await mkdir(directory,{recursive:true,mode:0o700});
  const credentialFile=resolve(directory,'synthetic-login.json');
  // Save local access securely before committing the synthetic account. Never print credentials.
  await writeFile(credentialFile,JSON.stringify({login:'synthetic-owner@example.test',password}),{flag:'wx',mode:0o600});
  await transaction(db,async()=>{
   await db.prepare('INSERT INTO users(id,login,password,name,created_at,can_create_companies) VALUES(?,?,?,?,?,TRUE)').run(id,'synthetic-owner@example.test',hash,'SYNTHETIC TEST OWNER',new Date().toISOString());
   await db.prepare('INSERT INTO companies(id,name,currency,created_at) VALUES(?,?,?,?)').run(company,'SYNTHETIC TEST COMPANY — NOT REAL','KZT',new Date().toISOString());
   await db.prepare("INSERT INTO memberships VALUES(?,?,'owner','[]')").run(company,id);
  });
  console.log('Synthetic owner/company created. Local login is in .runtime/synthetic-login.json (not Git).');
 }
}finally{await db.close();}

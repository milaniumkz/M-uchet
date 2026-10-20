import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdtemp,open,rm,cp,mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join,resolve } from 'node:path';
import { createApp } from '../src/app.js';
import { openDatabase } from '../src/db.js';
const root=resolve(new URL('../..',import.meta.url).pathname);
async function docker(args,input='ignore',output='ignore'){
 const process=spawn('docker',['compose','exec','-T','db',...args],{cwd:root,stdio:[input,output,'inherit']});
 const exit=await new Promise((done,reject)=>{process.once('error',reject);process.once('exit',done);});
 assert.equal(exit,0,'PostgreSQL backup/restore command failed');
}
test('real PostgreSQL dump/restore retains users, exact journal and private files',async t=>{
 if(process.env.APP_ENV!=='test')throw Error('APP_ENV=test required');
 const sourceURL=new URL(process.env.DATABASE_URL);
 if(sourceURL.hostname!=='127.0.0.1'||sourceURL.port!=='55432'||sourceURL.pathname!=='/muchet')throw Error('Backup test is restricted to the local Compose development database');
 const id=randomUUID().replaceAll('-',''),schema='test_'+id,restoreDB='restore_'+id;
 const directory=await mkdtemp(join(tmpdir(),'muchet-restore-')),source=join(directory,'source'),target=join(directory,'restored');
 let app=await createApp({schema,dataDir:source,allowRegistration:true}),restored,createdDB=false;
 t.after(async()=>{
  if(app)await app.close();if(restored)await restored.close();
  const db=await openDatabase();try{await db.exec(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);}finally{await db.close();}
  if(createdDB)await docker(['dropdb','-U','muchet',restoreDB]);
  await rm(directory,{recursive:true,force:true});
 });
 const request=async(method,url,payload,token,extra={})=>{
  const r=await app.inject({method,url,payload,headers:{...(token?{authorization:'Bearer '+token}:{}),...extra}});
  assert.ok(r.statusCode<300,r.body);return r.json();
 };
 const credentials={login:'restore-test@example.test',password:randomUUID()};
 await request('POST','/v1/auth/register',{...credentials,name:'SYNTHETIC RESTORE TEST'});
 const session=await request('POST','/v1/auth/login',credentials);
 const company=await request('POST','/v1/companies',{name:'SYNTHETIC RESTORE COMPANY',currency:'KZT'},session.token);
 const prefix=`/v1/companies/${company.id}`;
 const journal=await request('POST',prefix+'/accounting/journal',{description:'Restore exact amount',lines:[{account:'cash',debit:123456789},{account:'capital',credit:123456789}]},session.token,{'idempotency-key':randomUUID()});
 const uploaded=await request('POST',prefix+'/files',Buffer.from('--testboundary\r\nContent-Disposition: form-data; name="file"; filename="synthetic.txt"\r\nContent-Type: text/plain\r\n\r\nSYNTHETIC RESTORE CONTENT\r\n--testboundary--\r\n'),session.token,{'content-type':'multipart/form-data; boundary=testboundary'});
 await app.close();app=undefined;
 const dump=await open(join(directory,'backup.dump'),'wx',0o600);
 try{await docker(['pg_dump','-U','muchet','-d','muchet',`--schema=${schema}`,'--format=custom','--no-owner','--no-acl'],'ignore',dump.fd);}finally{await dump.close();}
 await mkdir(target,{recursive:true});await cp(join(source,'uploads'),join(target,'uploads'),{recursive:true});
 await docker(['createdb','-U','muchet',restoreDB]);createdDB=true;
 const input=await open(join(directory,'backup.dump'),'r');
 try{await docker(['pg_restore','-U','muchet','--no-owner','--no-acl',`--dbname=${restoreDB}`],input.fd);}finally{await input.close();}
 const restoredURL=new URL(sourceURL);restoredURL.pathname='/'+restoreDB;
 restored=await createApp({schema,dataDir:target,databaseUrl:restoredURL.href,allowRegistration:false});
 const login=await restored.inject({method:'POST',url:'/v1/auth/login',payload:credentials});assert.equal(login.statusCode,200);
 const headers={authorization:'Bearer '+login.json().token};
 const entries=(await restored.inject({url:prefix+'/accounting/journal',headers})).json().items;
 assert.equal(entries.find(e=>e.id===journal.id).lines[0].debit,123456789);
 assert.equal((await restored.db.prepare('SELECT debit FROM journal_lines WHERE entry_id=? AND position=0').get(journal.id)).debit,123456789);
 const file=await restored.inject({url:prefix+'/files/'+uploaded.id,headers});assert.equal(file.body,'SYNTHETIC RESTORE CONTENT');
});

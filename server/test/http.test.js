import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtemp,rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.js';
test('real HTTP login/company/document persists across API restart on PostgreSQL',async t=>{
 if(process.env.APP_ENV!=='test')throw Error('APP_ENV=test required');
 const schema='test_'+randomUUID().replaceAll('-',''),dataDir=await mkdtemp(join(tmpdir(),'uchet-http-'));
 let app=await createApp({schema,dataDir,allowRegistration:true});
 t.after(async()=>{await app.db.exec(`DROP SCHEMA "${schema}" CASCADE`);await app.close();await rm(dataDir,{recursive:true,force:true});});
 let origin=await app.listen({host:'127.0.0.1',port:0});
 const call=async(method,path,body,token)=>{
  const r=await fetch(origin+path,{method,headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},...(body?{body:JSON.stringify(body)}:{})});
  const data=await r.json();assert.ok(r.ok,JSON.stringify(data));return data;
 };
 const credentials={login:'synthetic-http@example.test',password:randomUUID()};
 await call('POST','/v1/auth/register',{...credentials,name:'SYNTHETIC USER'});
 let login=await call('POST','/v1/auth/login',credentials);
 const company=await call('POST','/v1/companies',{name:'SYNTHETIC COMPANY',currency:'KZT'},login.token);
 const path=`/v1/companies/${company.id}/resources/clients`;
 const doc=await call('POST',path,{data:{name:'SYNTHETIC CLIENT'}},login.token);
 await app.close();app=await createApp({schema,dataDir,allowRegistration:false});origin=await app.listen({host:'127.0.0.1',port:0});
 login=await call('POST','/v1/auth/login',credentials);
 assert.equal((await call('GET',path+'/'+doc.id,null,login.token)).data.name,'SYNTHETIC CLIENT');
 const spec=await call('GET','/openapi.json');assert.equal(spec.openapi,'3.0.3');assert.ok(spec.paths['/v1/auth/login']);
});

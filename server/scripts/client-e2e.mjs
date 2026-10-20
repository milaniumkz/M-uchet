import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdtemp,writeFile,rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve,join } from 'node:path';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
if(process.env.APP_ENV!=='test')throw Error('APP_ENV=test required');
const root=resolve(new URL('../..',import.meta.url).pathname),schema='test_'+randomUUID().replaceAll('-','');
const directory=await mkdtemp(join(tmpdir(),'muchet-dart-'));
const app=await createApp({schema,dataDir:join(directory,'data'),allowRegistration:true});
try{
 const login='synthetic-dart@example.test',password=randomUUID();
 const registered=await app.inject({method:'POST',url:'/v1/auth/register',payload:{login,password,name:'SYNTHETIC DART USER'}});assert.equal(registered.statusCode,201);
 const session=(await app.inject({method:'POST',url:'/v1/auth/login',payload:{login,password}})).json();
 const company=await app.inject({method:'POST',url:'/v1/companies',payload:{name:'SYNTHETIC DART COMPANY',currency:'KZT'},headers:{authorization:'Bearer '+session.token}});assert.equal(company.statusCode,201);
 const origin=await app.listen({host:'127.0.0.1',port:0}),fixture=join(directory,'fixture.json');
 await writeFile(fixture,JSON.stringify({origin,login,password}),{mode:0o600});
 const child=spawn(resolve(root,'scripts/flutter.sh'),['test','--no-pub','test_live/rest_repository_test.dart','test_live/project_workspace_test.dart','--concurrency=1','--reporter','expanded'],{cwd:root,env:{...process.env,MUCHET_TEST_FIXTURE:fixture},stdio:'inherit'});
 const code=await new Promise((done,reject)=>{child.once('error',reject);child.once('exit',done);});
 if(code!==0)process.exitCode=code??1;
}finally{await app.db.exec(`DROP SCHEMA "${schema}" CASCADE`);await app.close();await rm(directory,{recursive:true,force:true});}

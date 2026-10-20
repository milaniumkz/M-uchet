import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdtemp,writeFile,rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve,join } from 'node:path';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { issueRecoveryToken } from '../src/recovery.js';
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
 const recoveryLogin='synthetic-recovery@example.test',recoveryNextPassword=randomUUID();
 const recoveryUser=await app.inject({method:'POST',url:'/v1/auth/register',payload:{login:recoveryLogin,password:randomUUID(),name:'SYNTHETIC RECOVERY USER'}});assert.equal(recoveryUser.statusCode,201);
 const recovery=await issueRecoveryToken(app.db,recoveryLogin);
 await writeFile(fixture,JSON.stringify({origin,login,password,recoveryLogin,recoveryNextPassword,recoveryToken:recovery.token}),{mode:0o600});
 const available=['test_live/rest_repository_test.dart','test_live/project_workspace_test.dart','test_live/commercial_workspace_test.dart','test_live/bank_workspace_test.dart','test_live/ledger_workspace_test.dart','test_live/inventory_workspace_test.dart','test_live/recovery_dialog_test.dart','test_live/assets_workspace_test.dart','test_live/employees_workspace_test.dart','test_live/access_workspace_test.dart','test_live/cash_workspace_test.dart','test_live/counterparty_workspace_test.dart'];
 const requested=process.argv.slice(2);if(requested.some(file=>!available.includes(file)))throw Error('Unknown live test selection');
 const child=spawn(resolve(root,'scripts/flutter.sh'),['test','--no-pub',...(requested.length?requested:available),'--timeout=2m','--concurrency=1','--reporter','expanded'],{cwd:root,env:{...process.env,MUCHET_TEST_FIXTURE:fixture},stdio:'inherit'});
 const code=await new Promise((done,reject)=>{child.once('error',reject);child.once('exit',done);});
 if(code!==0)process.exitCode=code??1;
}finally{await app.db.exec(`DROP SCHEMA "${schema}" CASCADE`);await app.close();await rm(directory,{recursive:true,force:true});}

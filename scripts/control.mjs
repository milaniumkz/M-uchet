import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, openSync, existsSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';
const root = resolve(new URL('..', import.meta.url).pathname);
const runtime = resolve(root,'.runtime'); mkdirSync(runtime,{recursive:true,mode:0o700});
const pidfile=resolve(runtime,'api.pid');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
if(process.argv[2]==='down') {
 if(existsSync(pidfile)) {
  const pid=Number(readFileSync(pidfile,'utf8'));
  try {
   const args=readFileSync(`/proc/${pid}/cmdline`,'utf8');
   if(!args.includes(resolve(root,'server/src/main.js')))throw Error('PID belongs to a different process');
   process.kill(pid,'SIGTERM');
  } catch(error) { if(error.code!=='ENOENT'&&error.code!=='ESRCH')throw error; }
  rmSync(pidfile,{force:true});
 }
} else {
 const url=`http://${process.env.HOST??'127.0.0.1'}:${process.env.PORT??8080}/health`;
 try {
  const result=await fetch(url);
  if(result.ok&&existsSync(pidfile)) {
   const pid=Number(readFileSync(pidfile,'utf8'));
   const args=readFileSync(`/proc/${pid}/cmdline`,'utf8');
   const body=await result.json();
   if(args.includes(resolve(root,'server/src/main.js'))&&body.status==='ok'&&body.schemaVersion>=4){console.log('Existing task-runner API verified and reused.');process.exit(0);}
  }
  throw Error('Port is occupied. Inspect the existing service; no second process started.');
 }
 catch(error) { if(!error.cause)throw error; }
 const log=openSync(resolve(runtime,'api.log'),'a',0o600);
 const child=spawn(process.execPath,[`--env-file=${resolve(root,'.env')}`,resolve(root,'server/src/main.js')],{cwd:resolve(root,'server'),stdio:['ignore',log,log],detached:true,env:process.env});
 writeFileSync(pidfile,String(child.pid),{mode:0o600});child.unref();
 let ready=false;
 for(let i=0;i<100;i++) {try {const r=await fetch(url); const body=await r.json(); if(r.ok&&body.status==='ok'&&body.schemaVersion>=3){ready=true;break;}}catch{} await wait(100);}
 if(!ready)throw Error('API startup failed; inspect .runtime/api.log');
 console.log('API readiness verified; see .runtime/api.log.');
}

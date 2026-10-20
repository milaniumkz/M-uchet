import { spawn } from 'node:child_process';
import { mkdir,open,rm } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(new URL('../..',import.meta.url).pathname);
if(!['development','test'].includes(process.env.APP_ENV))throw Error('Compose backup command is restricted to development/test. Configure production backup separately.');
const directory=resolve(root,'.runtime/backups');await mkdir(directory,{recursive:true,mode:0o700});
const target=resolve(directory,`muchet-${Date.now()}.dump`),file=await open(target,'wx',0o600);
try{
 const child=spawn('docker',['compose','exec','-T','db','pg_dump','-U','muchet','-d','muchet','--format=custom','--no-owner','--no-acl'],{cwd:root,env:process.env,stdio:['ignore',file.fd,'inherit']});
 const code=await new Promise((done,reject)=>{child.once('error',reject);child.once('exit',done);});
 if(code!==0)throw Error(`pg_dump exited ${code}`);
 console.log(`Database backup: ${target}. Uploads require a separate copy with the API stopped.`);
}catch(error){await rm(target,{force:true});throw error;}finally{await file.close();}

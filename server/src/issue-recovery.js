import { open, rm } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { openDatabase } from './db.js';
import { issueRecoveryToken } from './recovery.js';
let db,createdFile,output;
try {
 const {values}=parseArgs({options:{login:{type:'string'},output:{type:'string'}}});
 if(!values.login||!values.output)throw Error('arguments_required');
 // Reserve the output path before issuing the token; do not overwrite or follow symlinks.
 output=await open(values.output,'wx',0o600);createdFile=values.output;
 db=await openDatabase();
 const result=await issueRecoveryToken(db,values.login);
 await output.writeFile(JSON.stringify(result)+'\n');await output.close();output=null;createdFile=null;
 console.log('Recovery token saved to the requested private file; valid for 15 minutes, usable once. No email was sent.');
}catch(_){console.error('Recovery issuance failed. Check login, database and a new writable output path. No token is printed.');process.exitCode=1;}
finally{if(output)await output.close();if(createdFile)await rm(createdFile,{force:true});if(db)await db.close();}

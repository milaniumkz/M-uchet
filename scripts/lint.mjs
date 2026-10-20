import { readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const paths=['server/src','server/test','scripts'];
for(const directory of paths)for(const file of readdirSync(directory))if(/\.(m?js)$/.test(file)){
 const r=spawnSync(process.execPath,['--check',`${directory}/${file}`],{stdio:'inherit'});
 if(r.status!==0)process.exit(r.status??1);
}
console.log('Node syntax checks passed. Flutter analysis is a separate required check.');

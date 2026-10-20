import { randomUUID } from 'node:crypto';
import { transaction } from './db.js';
import { fail,text,newToken,hashToken,hashPassword,verifyPassword } from './security.js';
import { permissions } from './resources.js';

export function registerInvitationRoutes(app,{db,auth,owner,object}){
 const route=(method,path,handler)=>app.route({method,url:'/v1/companies/:companyId'+path,preHandler:auth,handler});
 const tokenHash=body=>{if(typeof body.token!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(body.token))fail(400,'invalid_invitation');return hashToken(body.token);};
 const invitation=async hash=>{
  const item=await db.prepare('SELECT i.*,c.name AS company_name FROM company_invitations i JOIN companies c ON c.id=i.company_id WHERE token_hash=?').get(hash);
  if(!item||item.revoked||item.expires_at<=Date.now())fail(400,'invalid_invitation');return item;
 };
 const audit=async(companyId,actor,action,id)=>db.prepare('INSERT INTO audit(company_id,actor_id,action,resource_id,created_at) VALUES(?,?,?,?,?)').run(companyId,actor,action,id,new Date().toISOString());
 route('GET','/invitations',async request=>{
  await owner(request);
  return {items:(await db.prepare('SELECT id,login,name,permissions,expires_at,accepted_at,revoked,created_at FROM company_invitations WHERE company_id=? ORDER BY created_at DESC LIMIT 100').all(request.params.companyId)).map(i=>({...i,permissions:JSON.parse(i.permissions)}))};
 });
 route('POST','/invitations',async request=>{
  await owner(request);const companyId=request.params.companyId,body=object(request.body),login=text(body.login,'login',254).toLowerCase(),name=text(body.name,'name');
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(login))fail(400,'invalid_login');
  if(!Array.isArray(body.permissions)||body.permissions.length>permissions.length||body.permissions.some(p=>!permissions.includes(p)))fail(400,'invalid_permissions');
  const granted=[...new Set(body.permissions)],id=randomUUID(),token=newToken(),expiresAt=Date.now()+7*24*60*60*1000;
  return transaction(db,async()=>{
   await db.prepare('SELECT id FROM companies WHERE id=? FOR UPDATE').get(companyId);
   const membership=await db.prepare('SELECT m.role FROM memberships m JOIN users u ON u.id=m.user_id WHERE m.company_id=? AND u.login=?').get(companyId,login);
   if(membership?.role==='owner')fail(409,'owner_membership_protected');
   await db.prepare('UPDATE company_invitations SET revoked=TRUE WHERE company_id=? AND login=? AND accepted_at IS NULL').run(companyId,login);
   await db.prepare('INSERT INTO company_invitations(id,token_hash,company_id,login,name,permissions,created_by,expires_at,created_at) VALUES(?,?,?,?,?,?,?,?,?)').run(id,hashToken(token),companyId,login,name,JSON.stringify(granted),request.user.id,expiresAt,new Date().toISOString());
   await audit(companyId,request.user.id,'invitation.create',id);
   // Credential returned once; never store the raw token in idempotency/audit.
   return {id,token,login,name,permissions:granted,expiresAt};
  });
 });
 route('POST','/invitations/:id/revoke',async request=>{
  await owner(request);
  return transaction(db,async()=>{
   await db.prepare('SELECT id FROM companies WHERE id=? FOR UPDATE').get(request.params.companyId);
   const item=await db.prepare('SELECT id FROM company_invitations WHERE company_id=? AND id=?').get(request.params.companyId,request.params.id);if(!item)fail(404,'invitation_not_found');
   await db.prepare('UPDATE company_invitations SET revoked=TRUE WHERE company_id=? AND id=?').run(request.params.companyId,item.id);
   await audit(request.params.companyId,request.user.id,'invitation.revoke',item.id);return {ok:true,id:item.id};
  });
 });
 app.post('/v1/auth/invitations/preview',{config:{rateLimit:{max:10,timeWindow:'1 minute'}}},async request=>{
  const item=await invitation(tokenHash(object(request.body))),account=await db.prepare('SELECT id FROM users WHERE login=?').get(item.login);
  return {companyId:item.company_id,companyName:item.company_name,login:item.login,name:item.name,permissions:JSON.parse(item.permissions),accountExists:Boolean(account),accepted:item.accepted_at!==null};
 });
 app.post('/v1/auth/invitations/accept',{config:{rateLimit:{max:5,timeWindow:'1 minute'}}},async request=>{
  const body=object(request.body),hash=tokenHash(body),initial=await invitation(hash);
  if(typeof body.password!=='string'||body.password.length<12||body.password.length>256)fail(400,'password_length_12_to_256');
  return transaction(db,async()=>{
   await db.prepare('SELECT id FROM companies WHERE id=? FOR UPDATE').get(initial.company_id);
   await db.prepare('SELECT pg_advisory_xact_lock(hashtextextended(?,62700324))').get(initial.login);
   const item=await invitation(hash);
   let user=await db.prepare('SELECT * FROM users WHERE login=?').get(item.login);
   if(user&&!await verifyPassword(body.password,user.password))fail(401,'invalid_credentials');
   if(item.accepted_by){
    if(!user||item.accepted_by!==user.id||!await db.prepare('SELECT 1 FROM memberships WHERE company_id=? AND user_id=?').get(item.company_id,user.id))fail(403,'invitation_access_revoked');
    return {ok:true,login:item.login,companyId:item.company_id};
   }
   if(!user){
    user={id:randomUUID(),name:item.name};
    const password=await hashPassword(body.password);
    await db.prepare('INSERT INTO users(id,login,password,name,created_at) VALUES(?,?,?,?,?)').run(user.id,item.login,password,user.name,new Date().toISOString());
   }
   const previous=await db.prepare('SELECT role FROM memberships WHERE company_id=? AND user_id=?').get(item.company_id,user.id);
   if(previous?.role==='owner')fail(409,'owner_membership_protected');
   await db.prepare("INSERT INTO memberships(company_id,user_id,role,permissions) VALUES(?,?,'member',?) ON CONFLICT(company_id,user_id) DO UPDATE SET permissions=excluded.permissions").run(item.company_id,user.id,item.permissions);
   await db.prepare('UPDATE company_invitations SET accepted_by=?,accepted_at=? WHERE id=?').run(user.id,Date.now(),item.id);
   await audit(item.company_id,user.id,'invitation.accept',item.id);return {ok:true,login:item.login,companyId:item.company_id};
  });
 });
}

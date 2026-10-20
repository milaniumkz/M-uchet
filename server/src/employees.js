import { randomUUID } from 'node:crypto';
import { fail,text,integer,businessDate } from './security.js';
import { projectReference } from './accounting.js';
export function registerEmployeeRoutes(app,{db,auth,access,command,object,pageLimit}){
 const base='/v1/companies/:companyId/employees';
 const route=(method,path,handler)=>app.route({method,url:base+path,preHandler:auth,handler});
 const get=async(companyId,id)=>{const row=await db.prepare('SELECT * FROM employees WHERE company_id=? AND id=?').get(companyId,text(id,'employeeId'));if(!row)fail(404,'employee_not_found');return row;};
 const input=async(company,body)=>{
  const name=text(body.name,'name'),jobTitle=text(body.jobTitle,'jobTitle');
  const identifier=body.identifier===null||body.identifier===''?null:text(body.identifier,'identifier',12);if(identifier!==null&&!/^\d{12}$/.test(identifier))fail(400,'invalid_identifier');
  const hireDate=businessDate(body.hireDate),birthDate=body.birthDate?businessDate(body.birthDate):null,terminationDate=body.terminationDate?businessDate(body.terminationDate):null;
  if(birthDate&&birthDate>=hireDate||terminationDate&&terminationDate<hireDate)fail(400,'invalid_employee_dates');
  if(!['ACTIVE','INACTIVE'].includes(body.status)||typeof body.resident!=='boolean'||typeof body.standardDeductionDeclaration!=='boolean')fail(400,'invalid_employee_profile');
  const citizenship=text(body.citizenship,'citizenship',2).toUpperCase();if(!/^[A-Z]{2}$/.test(citizenship))fail(400,'invalid_employee_profile');
  const notes=typeof body.notes==='string'?body.notes.trim():'';if(notes.length>2000)fail(400,'invalid_notes');
  return {name,identifier,jobTitle,hireDate,birthDate,terminationDate,status:body.status,grossBase:integer(body.grossBase,'grossBase'),projectId:await projectReference(db,company.id,body.projectId),data:{resident:body.resident,citizenship,standardDeductionDeclaration:body.standardDeductionDeclaration,notes}};
 };
 route('GET','',async request=>{
  const company=await access(request,'employees.read'),search=typeof request.query.q==='string'?request.query.q.trim():'';
  if(search.length>200)fail(400,'invalid_search');const pattern='%'+search.replace(/[\\%_]/g,c=>'\\'+c)+'%';
  const project=request.query.projectId;if(project!==undefined&&project!=='unassigned')await projectReference(db,company.id,project);
  const items=await db.prepare(`SELECT * FROM employees WHERE company_id=? AND id>?${project===undefined?'':' AND project_id IS NOT DISTINCT FROM ?'}${search?' AND (name ILIKE ? OR identifier ILIKE ? OR job_title ILIKE ?)':''} ORDER BY id LIMIT ?`).all(company.id,request.query.after??'',...(project===undefined?[]:[project==='unassigned'?null:project]),...(search?[pattern,pattern,pattern]:[]),pageLimit(request.query));
  return {items,nextCursor:items.length===pageLimit(request.query)?items.at(-1).id:null};
 });
 route('GET','/:id',async request=>{const company=await access(request,'employees.read');return get(company.id,request.params.id);});
 route('POST','',request=>command(request,'employees.write','employee.create',async company=>{
  const d=await input(company,object(request.body)),id=randomUUID(),now=new Date().toISOString();
  try{await db.prepare('INSERT INTO employees(id,company_id,name,identifier,job_title,hire_date,birth_date,termination_date,gross_base,project_id,status,data,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)').run(id,company.id,d.name,d.identifier,d.jobTitle,d.hireDate,d.birthDate,d.terminationDate,d.grossBase,d.projectId,d.status,JSON.stringify(d.data),now,now);}catch(e){if(e.code==='23505')fail(409,'employee_identifier_conflict');throw e;}
  return get(company.id,id);
 }));
 route('PUT','/:id',request=>command(request,'employees.write','employee.edit',async company=>{
  const old=await get(company.id,request.params.id),body=object(request.body);if(body.version!==old.version)fail(409,'version_conflict');
  const d=await input(company,body);await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'employee',old.id,JSON.stringify(old),request.user.id);
  try{await db.prepare('UPDATE employees SET name=?,identifier=?,job_title=?,hire_date=?,birth_date=?,termination_date=?,gross_base=?,project_id=?,status=?,data=?,version=version+1,updated_at=? WHERE id=?').run(d.name,d.identifier,d.jobTitle,d.hireDate,d.birthDate,d.terminationDate,d.grossBase,d.projectId,d.status,JSON.stringify(d.data),new Date().toISOString(),old.id);}catch(e){if(e.code==='23505')fail(409,'employee_identifier_conflict');throw e;}
  return get(company.id,old.id);
 }));
 route('GET','/:id/history',async request=>{const company=await access(request,'employees.read');await get(company.id,request.params.id);return {items:await db.prepare("SELECT * FROM entity_history WHERE company_id=? AND kind='employee' AND entity_id=? ORDER BY revision DESC").all(company.id,request.params.id)};});
}

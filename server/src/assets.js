import {randomUUID} from 'node:crypto';
import {fail,text,integer,scope,businessDate} from './security.js';
import {postJournal,projectReference} from './accounting.js';

const monthIndex=value=>Number(value.slice(0,4))*12+Number(value.slice(5,7))-1;
const monthAt=value=>`${Math.floor(value/12).toString().padStart(4,'0')}-${(value%12+1).toString().padStart(2,'0')}`;
const monthEnd=month=>{const [year,m]=month.split('-').map(Number);return `${month}-${new Date(Date.UTC(year,m,0)).getUTCDate()}`;};
function month(value){if(typeof value!=='string'||!/^\d{4}-(0[1-9]|1[0-2])$/.test(value)||value<'0001-01')fail(400,'invalid_period');return value;}
const round=(n,d)=>(n+d/2n)/d;
export function depreciationSchedule(data,through){
 const result=[],start=monthIndex(data.depreciationStart),end=Math.min(monthIndex(month(through)),start+data.lifeMonths-1),base=BigInt(data.cost-data.residual),life=BigInt(data.lifeMonths);
 for(let index=start;index<=end;index++){
  const elapsed=BigInt(index-start),amount=Number(round(base*(elapsed+1n),life)-round(base*elapsed,life));
  result.push({month:monthAt(index),businessDate:monthEnd(monthAt(index)),amount});
 }
 return result;
}
export function registerAssetRoutes(app,{db,auth,access,command,object,pageLimit}){
 const base='/v1/companies/:companyId/assets';
 const route=(method,path,handler)=>app.route({method,url:base+path,preHandler:auth,handler});
 const get=async(companyId,id)=>{const item=await db.prepare('SELECT * FROM fixed_assets WHERE company_id=? AND id=?').get(companyId,text(id,'assetId'));if(!item)fail(404,'asset_not_found');return item;};
 const dto=asset=>{
  const schedule=(asset.depreciation_through?depreciationSchedule(asset.data,asset.depreciation_through):[]).filter(line=>!asset.disposal_date||line.businessDate<=asset.disposal_date);
  const depreciation=asset.status==='DRAFT'?0:schedule.reduce((sum,m)=>sum+m.amount,0);
  return {...asset,depreciation,carryingAmount:asset.status!=='ACTIVE'?0:asset.data.cost-depreciation,schedule};
 };
 const input=async(company,body,previous)=>{
  const cost=integer(body.cost,'cost',1),residual=integer(body.residual,'residual');if(residual>cost)fail(400,'residual_exceeds_cost');
  const lifeMonths=integer(body.lifeMonths,'lifeMonths',1);if(lifeMonths>600)fail(400,'invalid_asset_life');
  if(body.method!=='LINEAR_MONTHLY'||body.policyAcknowledged!==true)fail(422,'asset_policy_required');
  const acquisitionDate=businessDate(body.acquisitionDate),depreciationStart=month(body.depreciationStart);
  if(depreciationStart<acquisitionDate.slice(0,7))fail(400,'invalid_depreciation_start');
  const supplierId=text(body.supplierId,'supplierId');
  const supplier=await db.prepare("SELECT data FROM documents WHERE company_id=? AND kind='suppliers' AND id=?").get(company.id,supplierId);
  if(!supplier)fail(404,'counterparty_not_found');
  return {name:text(body.name,'name'),inventoryNumber:text(body.inventoryNumber,'inventoryNumber',100),projectId:await projectReference(db,company.id,body.projectId),scope:scope(body.scope),supplierId,
   data:{cost,residual,lifeMonths,acquisitionDate,depreciationStart,method:'LINEAR_MONTHLY',policyVersion:'OWNER_LINEAR_MONTHLY_V1',rounding:'CUMULATIVE_HALF_UP_MINOR',policyAcknowledged:true,location:typeof body.location==='string'?body.location.trim().slice(0,250):'',supplier:previous?.supplier_id===supplierId?previous.data.supplier:JSON.parse(supplier.data)}};
 };
 const snapshot=async(request,row)=>db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(row.company_id,'fixed_asset',row.id,JSON.stringify(row),request.user.id);
 const posting=async(company,asset,kind,date,lines,active=true)=>{
  const entry=await postJournal(db,company,{scope:asset.scope,projectId:asset.project_id,businessDate:date,description:`${kind}: ${asset.inventory_number} · ${asset.name}`,lines});
  await db.prepare('INSERT INTO asset_postings(company_id,asset_id,journal_id,kind,business_date,active) VALUES(?,?,?,?,?,?)').run(company.id,asset.id,entry.id,kind,date,active);return entry;
 };
 const rebuild=async(company,asset)=>{
  const active=await db.prepare('SELECT p.id,p.kind,p.business_date,j.scope AS old_scope,j.project_id AS old_project,j.lines FROM asset_postings p JOIN journal j ON j.id=p.journal_id WHERE p.company_id=? AND p.asset_id=? AND p.active=TRUE ORDER BY p.id').all(company.id,asset.id);
  for(const old of active){await posting(company,{...asset,scope:old.old_scope,project_id:old.old_project},'Сторно '+old.kind,old.business_date,JSON.parse(old.lines).map(l=>({account:l.account,debit:l.credit,credit:l.debit})),false);}
  await db.prepare('UPDATE asset_postings SET active=FALSE WHERE company_id=? AND asset_id=? AND active=TRUE').run(company.id,asset.id);
  if(asset.status==='DRAFT')return;
  const d=asset.data;
  await posting(company,asset,'Поступление ОС',d.acquisitionDate,[{account:'fixed_assets',debit:d.cost},{account:'payables',credit:d.cost}]);
  const schedule=asset.depreciation_through?depreciationSchedule(d,asset.depreciation_through):[];
  for(const line of schedule){
   if(asset.disposal_date&&line.businessDate>asset.disposal_date)continue;
   if(line.amount)await posting(company,asset,'Амортизация ОС',line.businessDate,[{account:'depreciation',debit:line.amount},{account:'accumulated_depreciation',credit:line.amount}]);
  }
  if(asset.status==='WRITTEN_OFF'){
   const depreciated=schedule.filter(m=>m.businessDate<=asset.disposal_date).reduce((sum,m)=>sum+m.amount,0),remaining=d.cost-depreciated;
   await posting(company,asset,'Списание ОС',asset.disposal_date,[...(depreciated?[{account:'accumulated_depreciation',debit:depreciated}]:[]),...(remaining?[{account:'asset_disposal_loss',debit:remaining}]:[]),{account:'fixed_assets',credit:d.cost}]);
  }
 };
 route('GET','',async request=>{const company=await access(request,'assets.read');const items=await db.prepare('SELECT * FROM fixed_assets WHERE company_id=? AND id>? ORDER BY id LIMIT ?').all(company.id,request.query.after??'',pageLimit(request.query));return {items:items.map(dto),nextCursor:items.length===pageLimit(request.query)?items.at(-1).id:null};});
 route('GET','/:id',async request=>{const company=await access(request,'assets.read');return dto(await get(company.id,request.params.id));});
 route('POST','',request=>command(request,'assets.write','asset.create',async company=>{
  const data=await input(company,object(request.body)),id=randomUUID(),now=new Date().toISOString();
  try{await db.prepare("INSERT INTO fixed_assets(id,company_id,inventory_number,name,scope,project_id,supplier_id,data,status,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,'DRAFT',?,?)").run(id,company.id,data.inventoryNumber,data.name,data.scope,data.projectId,data.supplierId,JSON.stringify(data.data),now,now);}catch(e){if(e.code==='23505')fail(409,'asset_number_conflict');throw e;}
  return dto(await get(company.id,id));
 }));
 route('PUT','/:id',request=>command(request,'assets.write','asset.edit',async company=>{
  const old=await get(company.id,request.params.id),body=object(request.body);if(body.version!==old.version)fail(409,'version_conflict');
  if(old.status!=='DRAFT')await access(request,'assets.post');
  const next=await input(company,body,old);
  if(old.disposal_date&&old.disposal_date<next.data.acquisitionDate)fail(400,'invalid_disposal_date');
  await snapshot(request,old);
  try{await db.prepare('UPDATE fixed_assets SET inventory_number=?,name=?,scope=?,project_id=?,supplier_id=?,data=?,version=version+1,updated_at=? WHERE id=?').run(next.inventoryNumber,next.name,next.scope,next.projectId,next.supplierId,JSON.stringify(next.data),new Date().toISOString(),old.id);}catch(e){if(e.code==='23505')fail(409,'asset_number_conflict');throw e;}
  const asset=await get(company.id,old.id);await rebuild(company,asset);return dto(asset);
 }));
 route('POST','/:id/activate',request=>command(request,'assets.post','asset.activate',async company=>{
  const old=await get(company.id,request.params.id);if(old.status==='ACTIVE')return dto(old);await snapshot(request,old);
  await db.prepare("UPDATE fixed_assets SET status='ACTIVE',disposal_date=NULL,disposal_reason=NULL,version=version+1 WHERE id=?").run(old.id);
  const asset=await get(company.id,old.id);await rebuild(company,asset);return dto(asset);
 }));
 route('POST','/:id/depreciation',request=>command(request,'assets.post','asset.depreciation',async company=>{
  const old=await get(company.id,request.params.id),through=month(object(request.body).throughMonth);
  if(old.status!=='ACTIVE')fail(409,'asset_not_active');if(through<old.data.depreciationStart)fail(400,'invalid_depreciation_start');
  await snapshot(request,old);await db.prepare('UPDATE fixed_assets SET depreciation_through=?,version=version+1 WHERE id=?').run(through,old.id);
  const asset=await get(company.id,old.id);await rebuild(company,asset);return dto(asset);
 }));
 route('POST','/:id/writeoff',request=>command(request,'assets.post','asset.writeoff',async company=>{
  const old=await get(company.id,request.params.id),body=object(request.body),date=businessDate(body.businessDate),reason=text(body.reason,'reason',500);
  if(old.status==='DRAFT')fail(409,'asset_not_active');if(date<old.data.acquisitionDate)fail(400,'invalid_disposal_date');
  await snapshot(request,old);await db.prepare("UPDATE fixed_assets SET status='WRITTEN_OFF',disposal_date=?,disposal_reason=?,version=version+1 WHERE id=?").run(date,reason,old.id);
  const asset=await get(company.id,old.id);await rebuild(company,asset);return dto(asset);
 }));
 route('GET','/:id/history',async request=>{const company=await access(request,'assets.read');await get(company.id,request.params.id);return {items:await db.prepare("SELECT * FROM entity_history WHERE company_id=? AND kind='fixed_asset' AND entity_id=? ORDER BY revision DESC").all(company.id,request.params.id)};});
 route('GET','/:id/movements',async request=>{const company=await access(request,'assets.read');await get(company.id,request.params.id);return {items:await db.prepare('SELECT p.*,j.lines FROM asset_postings p JOIN journal j ON j.id=p.journal_id WHERE p.company_id=? AND p.asset_id=? ORDER BY p.id DESC').all(company.id,request.params.id)};});
 return {getAsset:get};
}

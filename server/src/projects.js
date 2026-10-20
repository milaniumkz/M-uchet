import { readSnapshot } from './db.js';
import { profitBucket, accumulateProfit, profitResult } from './profit.js';
import { randomUUID } from 'node:crypto';
import { fail, text, scope, businessDate } from './security.js';
import { projectReference } from './accounting.js';

export function registerProjectRoutes({ route, db, access, command, object }) {
  route('GET', '/projects', async request => {
    await access(request, 'projects.read');
    return { items: await db.prepare('SELECT * FROM projects WHERE company_id=? ORDER BY archived,name,id').all(request.params.companyId) };
  });
  route('POST', '/projects', request => command(request, 'projects.write', 'project.create', async company => {
    const body = object(request.body), id = randomUUID(), name = text(body.name, 'name', 160);
    const description = body.description === undefined ? '' : text(body.description, 'description', 2000);
    await db.prepare('INSERT INTO projects(id,company_id,name,description,created_at) VALUES(?,?,?,?,?)').run(id,company.id,name,description,new Date().toISOString());
    return { id, name, description, archived: false, version: 1 };
  }));
  route('PUT', '/projects/:id', request => command(request, 'projects.write', 'project.edit', async company => {
    const body = object(request.body);
    const old = await db.prepare('SELECT * FROM projects WHERE company_id=? AND id=?').get(company.id,request.params.id);
    if (!old) fail(404,'project_not_found');
    if (body.version !== old.version) fail(409,'version_conflict');
    if (body.archived !== undefined && typeof body.archived !== 'boolean') fail(400,'invalid_archived');
    const next = { ...old, name: body.name === undefined ? old.name : text(body.name,'name',160),
      description: body.description === undefined ? old.description : (body.description === '' ? '' : text(body.description,'description',2000)),
      archived: body.archived ?? old.archived, version: old.version+1 };
    await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'project',old.id,JSON.stringify(old),request.user.id);
    await db.prepare('UPDATE projects SET name=?,description=?,archived=?,version=? WHERE id=?').run(next.name,next.description,next.archived,next.version,old.id);
    return next;
  }));
  route('GET', '/reports/projects', request => readSnapshot(db,async () => {
    await access(request,'reports.read');
    const companyId = request.params.companyId, ledgerScope = scope(request.query.scope);
    const from = businessDate(request.query.from ?? '0001-01-01'), to = businessDate(request.query.to ?? '9999-12-31');
    if (from > to) fail(400,'invalid_date_range');
    const selected = request.query.projectId;
    if (selected && selected !== 'unassigned') await projectReference(db,companyId,selected);
    const projects = await db.prepare('SELECT id,name,archived FROM projects WHERE company_id=? ORDER BY name,id').all(companyId);
    const buckets = new Map(projects.map(p=>[p.id,{projectId:p.id,name:p.name,archived:p.archived,amounts:profitBucket()}]));
    buckets.set(null,{projectId:null,name:'Общие операции фирмы',archived:false,amounts:profitBucket()});
    const rows = await db.prepare("SELECT project_id,lines FROM journal WHERE company_id=? AND (scope=? OR scope='BOTH') AND business_date>=? AND business_date<=?").all(companyId,ledgerScope,from,to);
    for (const row of rows) accumulateProfit(buckets.get(row.project_id).amounts, JSON.parse(row.lines));
    const totals = profitBucket();
    const items = [...buckets.values()].map(({amounts,...item})=>{
      for(const key of Object.keys(totals)) totals[key] += amounts[key];
      return {...item,...profitResult(amounts)};
    });
    const total = profitResult(totals);
    const selectionTotal = selected ? profitResult(buckets.get(selected==='unassigned'?null:selected).amounts) : total;
    return { scope:ledgerScope,from,to,currency:(await access(request,'reports.read')).currency,
      items:selected?items.filter(p=>p.projectId===(selected==='unassigned'?null:selected)):items,total,selectionTotal };
 }));
}

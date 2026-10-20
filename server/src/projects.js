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
  route('GET', '/reports/projects', async request => {
    await access(request,'reports.read');
    const companyId = request.params.companyId, ledgerScope = scope(request.query.scope);
    const from = businessDate(request.query.from ?? '1900-01-01'), to = businessDate(request.query.to ?? '9999-12-31');
    if (from > to) fail(400,'invalid_date_range');
    const selected = request.query.projectId;
    if (selected && selected !== 'unassigned') await projectReference(db,companyId,selected);
    const projects = await db.prepare('SELECT id,name,archived FROM projects WHERE company_id=? ORDER BY name,id').all(companyId);
    const empty = () => ({ revenue:0, cogs:0, expenses:0, grossProfit:0, netProfit:0 });
    const buckets = new Map(projects.map(p=>[p.id,{projectId:p.id,name:p.name,archived:p.archived,...empty()}]));
    buckets.set(null,{projectId:null,name:'Общие операции фирмы',archived:false,...empty()});
    const rows = await db.prepare("SELECT project_id,lines FROM journal WHERE company_id=? AND (scope=? OR scope='BOTH') AND business_date>=? AND business_date<=?").all(companyId,ledgerScope,from,to);
    for (const row of rows) for (const line of JSON.parse(row.lines)) {
      const bucket=buckets.get(row.project_id);
      if(line.account==='revenue')bucket.revenue+=line.credit-line.debit;
      if(line.account==='cogs')bucket.cogs+=line.debit-line.credit;
      if(['expenses','inventory_loss','depreciation','asset_disposal_loss','salary_expense','payroll_employer_expense'].includes(line.account))bucket.expenses+=line.debit-line.credit;
    }
    const items=[...buckets.values()];
    const total=empty();
    for(const item of items){
      item.grossProfit=item.revenue-item.cogs;item.netProfit=item.grossProfit-item.expenses;
      for(const key of Object.keys(total)){if(!Number.isSafeInteger(item[key]))fail(422,'report_amount_overflow');total[key]+=item[key];}
    }
    for(const value of Object.values(total))if(!Number.isSafeInteger(value))fail(422,'report_amount_overflow');
    return { scope:ledgerScope,from,to,currency:(await access(request,'reports.read')).currency,
      items:selected?items.filter(p=>p.projectId===(selected==='unassigned'?null:selected)):items,total };
  });
}

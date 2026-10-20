from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
rows=[]
for path in sorted((root/'lib').rglob('*_widget.dart')):
 source=path.read_text();route=re.search(r"routeName\s*=\s*['\"]([^'\"]+)",source)
 collections=sorted(set(re.findall(r"\.collection(?:Group)?\(\s*['\"]([^'\"]+)",source)))
 prefix=path.relative_to(root).parts[1]
 module={'auth':'identity','product':'inventory','sale':'sales','money':'cash-bank/accounting','analitics':'reporting','personal':'payroll'}.get(prefix,'organizations/shared')
 rows.append({'screen':str(path.relative_to(root)),'route':route.group(1) if route else None,'models':[str(p.relative_to(root)) for p in path.parent.glob('*_model.dart')],'direct_collections':collections,'target_module':module,'new_api':None,'status':'not_migrated','verification_scenario':'Real API binding and widget/E2E tests pending'})
target=root/'docs/architecture';target.mkdir(parents=True,exist_ok=True)
(target/'screen-map.json').write_text(json.dumps({'method':'static scan; indirect data flow requires manual review','screens':rows},ensure_ascii=False,indent=2)+'\n')
lines=['# Карта сохранённых экранов','','Статический аудит. Все экраны сохранены; ни один не объявлен подключённым к новому API. Отсутствие прямого collection-вызова не исключает косвенную зависимость.','','| Экран | Маршрут | Модель | Прямые коллекции | Модуль | API / проверка |','|---|---|---|---|---|---|']
for r in rows:lines.append('| '+' | '.join([r['screen'],r['route'] or '—',', '.join(r['models']) or '—',', '.join(r['direct_collections']) or '—',r['target_module'],'Не подключён / не проверен'])+' |')
(target/'screen-map.md').write_text('\n'.join(lines)+'\n')
print(f'Audited {len(rows)} existing widget files; actual API binding pending.')

from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
pattern=re.compile(r'package:(?:cloud_firestore|firebase_[a-z_]+|cloud_functions)/|(?:FirebaseFirestore|FirebaseAuth|FirebaseStorage|FirebaseFunctions)\.')
findings=[]
for path in (root/'lib').rglob('*.dart'):
 for number,line in enumerate(path.read_text().splitlines(),1):
  if pattern.search(line): findings.append(f'{path.relative_to(root)}:{number}')
for number,line in enumerate((root/'pubspec.yaml').read_text().splitlines(),1):
 if re.match(r'\s*(?:firebase_[a-z_]+|cloud_firestore[a-z_]*|cloud_functions)\s*:',line):findings.append(f'pubspec.yaml:{number}')
if findings:
 print(f'FAIL: {len(findings)} active Firebase dependencies/access declarations remain.');print('\n'.join(findings[:30]));sys.exit(1)
print('PASS: no active Firebase package/API access found in lib/pubspec.')

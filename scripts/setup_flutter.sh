#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
flutter_sdk="${FLUTTER_ROOT:-/workspace/.tools/flutter}"
if [[ ! -d "$flutter_sdk/.git" ]]; then
 if [[ -e "$flutter_sdk" ]]; then
  echo 'Existing non-Git Flutter directory preserved; set FLUTTER_ROOT to the pinned SDK.' >&2
  exit 1
 fi
 mkdir -p "$(dirname "$flutter_sdk")"
 git clone --depth 1 --branch 3.35.6 https://github.com/flutter/flutter.git "$flutter_sdk"
fi
flutter_commit="$(git -C "$flutter_sdk" rev-parse HEAD)"
if [[ "$flutter_commit" != 9f455d2486bcb28cad87b062475f42edc959f636 ]]; then
 echo 'Flutter checkout differs from the pinned 3.35.6 commit; preserved without resetting.' >&2
 exit 1
fi
export FLUTTER_ROOT="$flutter_sdk"
cd "$repo_root"
./scripts/flutter.sh --version
./scripts/flutter.sh pub get --enforce-lockfile

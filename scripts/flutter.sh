#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x /workspace/.tools/java/jdk-21.0.13/bin/javac ]]; then
 export JAVA_HOME="${JAVA_HOME:-/workspace/.tools/java/jdk-21.0.13}"
 export PATH="$JAVA_HOME/bin:$PATH"
fi
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$repo_root/.runtime/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$repo_root/.runtime/cache}"
export PUB_CACHE="${PUB_CACHE:-/workspace/.pub-cache}"
export ANALYZER_STATE_LOCATION_OVERRIDE="${ANALYZER_STATE_LOCATION_OVERRIDE:-$repo_root/.runtime/analyzer}"
if [[ -d /workspace/.tools/android-sdk ]]; then
 export ANDROID_HOME="${ANDROID_HOME:-/workspace/.tools/android-sdk}"
 export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
 export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$repo_root/.runtime/android}"
 export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$repo_root/.runtime/gradle}"
fi
if [[ -n "${FLUTTER_ROOT:-}" ]]; then
 flutter_binary="$FLUTTER_ROOT/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
 flutter_binary="$(command -v flutter)"
else
 flutter_binary=/workspace/.tools/flutter/bin/flutter
fi
if [[ ! -x "$flutter_binary" ]]; then
 echo 'Flutter 3.35.6 is required; set FLUTTER_ROOT or install it on PATH.' >&2
 exit 127
fi
exec "$flutter_binary" "$@"

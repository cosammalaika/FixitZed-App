#!/bin/sh
set -e

# Xcode can start script phases from an inaccessible working directory when the
# project lives in a protected macOS folder like Documents. Dart fails during
# startup before Flutter can switch to explicit paths, so move to a safe
# directory first.
cd "${TMPDIR:-/tmp}" 2>/dev/null || cd /tmp

exec /bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" "$@"

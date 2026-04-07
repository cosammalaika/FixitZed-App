#!/bin/sh
set -e

# Xcode can start script phases from an inaccessible working directory when the
# project lives in a protected macOS folder like Documents. Dart fails during
# startup before Flutter can switch to explicit paths, so move to a safe
# directory first.
cd "${TMPDIR:-/tmp}" 2>/dev/null || cd /tmp

fix_objective_c_native_asset_for_iphoneos() {
  if [ "${PLATFORM_NAME:-}" != "iphoneos" ]; then
    return 0
  fi

  if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
    return 0
  fi

  framework_dir="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/objective_c.framework"
  framework_binary="$framework_dir/objective_c"
  if [ ! -f "$framework_binary" ]; then
    return 0
  fi

  arch_info="$(lipo -info "$framework_binary" 2>/dev/null || true)"
  build_info="$(xcrun vtool -show-build "$framework_binary" 2>/dev/null || true)"
  needs_repair=false
  case "$arch_info $build_info" in
    *x86_64*|*IOSSIMULATOR*) needs_repair=true ;;
  esac

  if [ "$needs_repair" = true ]; then
    project_root="${FLUTTER_APPLICATION_PATH:-}"
    if [ -z "$project_root" ] && [ -n "${SOURCE_ROOT:-}" ]; then
      project_root="$SOURCE_ROOT/.."
    fi
    if [ -z "$project_root" ]; then
      echo "error: Unable to locate Flutter project root while repairing objective_c.framework." >&2
      exit 1
    fi

    replacement_binary=""
    for candidate in "$project_root/.dart_tool/hooks_runner/shared/objective_c/build"/*/objective_c.dylib; do
      if [ ! -f "$candidate" ]; then
        continue
      fi

      candidate_arch_info="$(lipo -info "$candidate" 2>/dev/null || true)"
      candidate_build_info="$(xcrun vtool -show-build "$candidate" 2>/dev/null || true)"
      case "$candidate_arch_info" in
        *arm64*) ;;
        *) continue ;;
      esac
      case "$candidate_arch_info" in
        *x86_64*) continue ;;
      esac
      case "$candidate_build_info" in
        *"platform IOS"*) ;;
        *) continue ;;
      esac
      case "$candidate_build_info" in
        *IOSSIMULATOR*) continue ;;
      esac

      replacement_binary="$candidate"
      break
    done

    if [ -z "$replacement_binary" ]; then
      echo "error: objective_c.framework contains simulator slices, but no iphoneos arm64 replacement was found." >&2
      exit 1
    fi

    echo "Repairing objective_c.framework for iphoneos with $replacement_binary"
    chmod u+w "$framework_binary" 2>/dev/null || true
    cp "$replacement_binary" "$framework_binary"
    chmod +x "$framework_binary"
  fi

  if [ -n "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
    mkdir -p "$DWARF_DSYM_FOLDER_PATH"
    xcrun dsymutil "$framework_binary" -o "$DWARF_DSYM_FOLDER_PATH/objective_c.framework.dSYM"
  fi

  if [ "$needs_repair" = true ] && [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ] && [ "${CODE_SIGNING_REQUIRED:-YES}" != "NO" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --preserve-metadata=identifier,entitlements "$framework_dir"
  fi
}

/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" "$@"

if [ "${1:-}" = "embed_and_thin" ]; then
  fix_objective_c_native_asset_for_iphoneos
fi

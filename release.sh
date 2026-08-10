#!/usr/bin/env bash

# XYDevTool 发布流程
#
# 前置条件：
#   1. 已安装 Xcode Command Line Tools、hdiutil、codesign 和 gh。
#   2. 已执行 `gh auth login`，并确认当前账号有仓库 Release 的写入权限。
#   3. 发布代码已经提交；版本号和即将发布的 tag 保持一致，例如 v1.4.6。
#
# 推荐操作（使用 Xcode 手动生成 App）：
#   1. 在 Xcode 中选择 Release 配置并完成构建。
#   2. 将生成的 XYDevTool.app 放到：
#        dist/dmg-root/XYDevTool.app
#      请替换旧 App，避免把上一个版本的构建产物再次发布。
#   3. 准备版本说明文件（可选），例如 release-notes.md。
#   4. 仅生成并检查 DMG，不上传：
#        ./release.sh v1.4.6 --no-upload
#   5. 确认无误后发布：
#        ./release.sh v1.4.6 --notes-file release-notes.md
#      不传 --notes-file 时，GitHub 会自动生成版本说明。
#
# 自动构建：
#   如果 dist/dmg-root/XYDevTool.app 不存在，脚本会尝试通过 xcodebuild
#   生成 Release App，再复制到上述目录。当前项目遇到命令行构建兼容问题时，
#   使用前面的 Xcode 手动构建流程。
#
# 脚本执行内容：
#   1. 对嵌套 framework、dylib、XPC 和 App 统一进行 ad-hoc 签名。
#   2. 移除不适用于无 Team ID 构建的 Hardened Runtime 签名标记。
#   3. 严格验证 App 及嵌套代码签名。
#   4. 添加 Applications 快捷方式并生成压缩 DMG。
#   5. 创建 GitHub Release；如果同名 Release 已存在，则使用 --clobber
#      覆盖其中的同名 DMG，不重复创建 Release。
#
# 注意：
#   - 当前发布方式不使用 Apple Developer 证书，也不做公证（notarization）。
#   - 用户首次打开时可能需要右键 App 选择“打开”；这属于 Gatekeeper 提示。
#   - 脚本签名完成后不要再修改 App 内容，否则签名会失效，应重新执行脚本。
#   - 最终产物路径：dist/XYDevTool-<version>.dmg

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./release.sh <version> [--notes-file FILE] [--draft] [--target TAG] [--no-upload]

Examples:
  ./release.sh v1.4.6 --notes-file release-notes.md
  ./release.sh v1.4.6 --draft
  ./release.sh v1.4.6 --no-upload
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

VERSION="$1"
shift

NOTES_FILE=""
CREATE_DRAFT=0
TARGET_REF=""
NO_UPLOAD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes-file)
      if [[ $# -lt 2 ]]; then
        echo "error: --notes-file requires a path" >&2
        exit 1
      fi
      NOTES_FILE="$2"
      shift 2
      ;;
    --draft)
      CREATE_DRAFT=1
      shift
      ;;
    --target)
      if [[ $# -lt 2 ]]; then
        echo "error: --target requires a ref" >&2
        exit 1
      fi
      TARGET_REF="$2"
      shift 2
      ;;
    --no-upload)
      NO_UPLOAD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="$ROOT_DIR/XYDevTool/XYDevTool.xcodeproj"
SCHEME="XYDevTool"
CONFIGURATION="Release"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
DMG_ROOT="$DIST_DIR/dmg-root"
APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/XYDevTool.app"
STAGED_APP_PATH="$DMG_ROOT/XYDevTool.app"
DMG_PATH="$DIST_DIR/XYDevTool-${VERSION}.dmg"

if [[ ! -f "$PROJECT_FILE/project.pbxproj" ]]; then
  echo "error: project not found: $PROJECT_FILE" >&2
  exit 1
fi

BUILD_INPUT=(-project "$PROJECT_FILE")

for tool in xcodebuild hdiutil codesign; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: required tool not found in PATH: $tool" >&2
    exit 1
  fi
done

if [[ -n "$NOTES_FILE" && ! -f "$NOTES_FILE" ]]; then
  echo "error: notes file not found: $NOTES_FILE" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR" "$DIST_DIR"
if [[ -d "$STAGED_APP_PATH" ]]; then
  echo "==> Found existing app bundle in dist/dmg-root, skipping build"
else
  rm -rf "$DMG_ROOT"
  mkdir -p "$DMG_ROOT"

  echo "==> Building $SCHEME ($CONFIGURATION)"
  xcodebuild \
    "${BUILD_INPUT[@]}" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR" \
    clean build

  if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app bundle not found after build: $APP_PATH" >&2
    exit 1
  fi

  echo "==> Preparing dmg payload"
  cp -R "$APP_PATH" "$STAGED_APP_PATH"
fi

echo "==> Applying a consistent ad-hoc signature"
# An ad-hoc signed app has no Team ID. Hardened Runtime library validation
# therefore cannot establish that embedded third-party frameworks belong to
# the same team. Re-sign every nested code bundle first, then the app itself,
# without preserving the Hardened Runtime flag.
while IFS= read -r -d '' code_path; do
  codesign \
    --force \
    --sign - \
    --preserve-metadata=identifier,entitlements \
    "$code_path"
done < <(
  find "$STAGED_APP_PATH/Contents" -depth \
    \( -type d \( -name '*.framework' -o -name '*.xpc' -o -name '*.appex' \) \
       -o -type f -name '*.dylib' \) \
    -print0
)

codesign \
  --force \
  --sign - \
  --preserve-metadata=identifier,entitlements \
  "$STAGED_APP_PATH"

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP_PATH"

ln -sfn /Applications "$DMG_ROOT/Applications"

echo "==> Creating dmg"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "XYDevTool" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "==> Created $DMG_PATH"

if [[ "$NO_UPLOAD" -eq 1 ]]; then
  echo "==> Skipping GitHub release upload (--no-upload)"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: required tool not found in PATH: gh" >&2
  exit 1
fi

if gh release view "$VERSION" >/dev/null 2>&1; then
  echo "==> Release $VERSION already exists, uploading asset"
  gh release upload "$VERSION" "$DMG_PATH" --clobber
else
  GH_ARGS=(release create "$VERSION" "$DMG_PATH" --title "$VERSION")

  if [[ -n "$TARGET_REF" ]]; then
    GH_ARGS+=(--target "$TARGET_REF")
  fi

  if [[ "$CREATE_DRAFT" -eq 1 ]]; then
    GH_ARGS+=(--draft)
  fi

  if [[ -n "$NOTES_FILE" ]]; then
    GH_ARGS+=(--notes-file "$NOTES_FILE")
  else
    GH_ARGS+=(--generate-notes)
  fi

  echo "==> Publishing GitHub release"
  gh "${GH_ARGS[@]}"
fi

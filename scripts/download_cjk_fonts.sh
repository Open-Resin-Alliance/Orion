#!/usr/bin/env bash
set -euo pipefail

# Downloads static (non-variable) Noto Sans CJK fonts into assets/fonts/.
# This is recommended for envs like flutter-pi where variable fonts may not
# render or be picked up for fallback.
#
# The files are licensed under the SIL Open Font License.
# See: https://github.com/notofonts
#
# After running, update pubspec.yaml to point to *_Regular.ttf files if you
# prefer the static fonts on all platforms.

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
FONT_DIR="$ROOT_DIR/assets/fonts"
mkdir -p "$FONT_DIR"

# Helper to download if missing
fetch() {
  local url="$1" name="$2"
  if [[ -f "$FONT_DIR/$name" ]]; then
    echo "Already present: $name"
    return
  fi
  echo "Downloading $name..."
  curl -L -o "$FONT_DIR/$name" "$url"
}

# Simplified direct links to regular-weight TTFs.
# JP
fetch "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf" "NotoSansJP-Regular.otf"
# KR
fetch "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/Korean/NotoSansCJKkr-Regular.otf" "NotoSansKR-Regular.otf"
# SC
fetch "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf" "NotoSansSC-Regular.otf"

cat <<EOF

Downloaded static CJK fonts to:
  $FONT_DIR

To use these on flutter-pi, you may swap the font assets in pubspec.yaml:
  - family: NotoSansSC
    fonts:
      - asset: assets/fonts/NotoSansSC-Regular.otf
  - family: NotoSansJP
    fonts:
      - asset: assets/fonts/NotoSansJP-Regular.otf
  - family: NotoSansKR
    fonts:
      - asset: assets/fonts/NotoSansKR-Regular.otf

Then run:
  flutter pub get

EOF

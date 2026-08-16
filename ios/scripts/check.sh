#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
destination="${SETLINE_SIMULATOR_DESTINATION:-platform=iOS Simulator,id=38FDB30B-69F2-406E-A253-17183F2348BE}"
derived_data="${SETLINE_DERIVED_DATA:-/private/tmp/setline-ios-derived}"
personal_team="8F7LXHTJZR"

cd "$project_root"
xcodegen generate
xcodebuild \
  -project Setline.xcodeproj \
  -scheme Setline \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  DEVELOPMENT_TEAM="$personal_team" \
  test
xcodebuild \
  -project Setline.xcodeproj \
  -scheme Setline \
  -configuration Release \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  DEVELOPMENT_TEAM="$personal_team" \
  build

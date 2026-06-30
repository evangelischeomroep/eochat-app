#!/bin/sh
# ci_post_clone.sh — runs on Xcode Cloud after the repo is cloned
# Installs Flutter (stable), fetches dependencies, generates code, and installs CocoaPods.
set -e

echo "=== Installing Flutter (stable) ==="
git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch stable \
  "$HOME/flutter"

export PATH="$PATH:$HOME/flutter/bin"

echo "=== Flutter version ==="
flutter --version

echo "=== flutter pub get ==="
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "=== dart run build_runner build ==="
dart run build_runner build --delete-conflicting-outputs

echo "=== Patch xcodeproj for Xcode 26 object version 70 ==="
# CocoaPods bundles xcodeproj and hardcodes a load path to a specific version
# (e.g. xcodeproj-1.27.0), so `gem install xcodeproj` is bypassed at runtime.
# The only reliable fix is to patch the bundled project.rb in place to add
# version 70 (Xcode 26) to the OBJECT_VERSION_TO_COMPATIBILITY_VERSION hash.
XCODEPROJ_PROJECT_RB=$(find /usr/local/Cellar/cocoapods -name "project.rb" \
  -path "*/xcodeproj-*/lib/xcodeproj/project.rb" 2>/dev/null | head -1)

if [ -z "$XCODEPROJ_PROJECT_RB" ]; then
  echo "ERROR: xcodeproj project.rb not found under /usr/local/Cellar/cocoapods"
  exit 1
fi

echo "Found xcodeproj project.rb at: $XCODEPROJ_PROJECT_RB"

ruby - "$XCODEPROJ_PROJECT_RB" << 'RUBY_PATCH'
path = ARGV[0]
content = File.read(path)
if content.include?("'70'") || content.include?('"70"')
  puts "xcodeproj already has version 70 support, skipping patch"
else
  patched = content
    .gsub("'63' => 'Xcode 15.0'", "'63' => 'Xcode 15.0', '70' => 'Xcode 26.0'")
    .gsub('"63" => "Xcode 15.0"', '"63" => "Xcode 15.0", "70" => "Xcode 26.0"')
  if patched == content
    warn "ERROR: Could not find version 63 entry to patch in #{path} — xcodeproj format may have changed"
    exit 1
  end
  File.write(path, patched)
  puts "Patched #{path}"
end
RUBY_PATCH

echo "=== pod install ==="
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "=== Done ==="

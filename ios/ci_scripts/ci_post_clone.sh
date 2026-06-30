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

# Print a snippet around version 63 to aid future debugging
if (m = content.match(/.{0,60}63\s*=>.{0,60}/))
  puts "Found near version 63: #{m[0].inspect}"
end

if content =~ /\b70\s*=>/
  puts "xcodeproj already has version 70 support, skipping patch"
else
  # Integer keys: `63 => 'Xcode 15.x'` followed by }.freeze
  # Inserts 70 => 'Xcode 26.0' before the closing brace
  patched = content.gsub(/(\b63\s*=>\s*'[^']*')(\s*\}\.freeze)/) do
    "#{$1},\n    70 => 'Xcode 26.0'#{$2}"
  end
  if patched == content
    warn "ERROR: Could not patch #{path} — dump the constants block and update this script"
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

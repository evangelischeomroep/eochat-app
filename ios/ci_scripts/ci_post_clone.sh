#!/bin/sh
# ci_post_clone.sh — runs on Xcode Cloud after the repo is cloned
# Installs Flutter (stable), fetches dependencies, generates code, and installs CocoaPods.
set -e

echo "=== Ensuring git submodules are initialized ==="
# pubspec.yaml has path: dependencies (mermaid_core, mermaid_flutter) that live
# inside the third_party/mermaid submodule. Xcode Cloud's automatic submodule
# checkout can be unreliable for submodules newly added in the commit being
# built, so initialize explicitly rather than relying on it.
cd "$CI_PRIMARY_REPOSITORY_PATH"
git submodule update --init --recursive

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
# Retry up to 3 times — git dependencies (super_sliver_list) can hit transient
# GitHub 502s in Xcode Cloud's network environment.
# Use `if` rather than `&&` so set -e does not abort on the first failure.
pub_get_ok=0
for attempt in 1 2 3; do
  if flutter pub get; then
    pub_get_ok=1
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "flutter pub get failed after 3 attempts"
    exit 1
  fi
  echo "flutter pub get failed (attempt $attempt), retrying in 10s..."
  sleep 10
done
[ "$pub_get_ok" -eq 1 ] || exit 1

echo "=== dart run build_runner build ==="
dart run build_runner build --delete-conflicting-outputs

echo "=== Patch xcodeproj for Xcode 26 object version 70 ==="
# CocoaPods bundles xcodeproj with a hardcoded load path, so gem install is
# bypassed. We patch the version compatibility hash in place.
# The hash may live in project.rb or constants.rb depending on xcodeproj version.
XCODEPROJ_GEM_DIR=$(find /usr/local/Cellar/cocoapods \
  -type d -name "xcodeproj-*" -path "*/gems/*" 2>/dev/null | head -1)

if [ -z "$XCODEPROJ_GEM_DIR" ]; then
  echo "ERROR: xcodeproj gem dir not found under /usr/local/Cellar/cocoapods"
  exit 1
fi

echo "xcodeproj gem dir: $XCODEPROJ_GEM_DIR"

ruby - "$XCODEPROJ_GEM_DIR" << 'RUBY_PATCH'
gem_dir = ARGV[0]

# Search all .rb files for whichever one has the integer version hash
target_file = nil
Dir.glob("#{gem_dir}/lib/**/*.rb").sort.each do |f|
  content = File.read(f) rescue next
  if content =~ /\b63\s*=>/
    puts "Found version hash in: #{f}"
    target_file = f
    break
  end
end

if target_file.nil?
  warn "Could not find '63 =>' in any .rb file under #{gem_dir}/lib — listing files:"
  Dir.glob("#{gem_dir}/lib/**/*.rb").sort.each { |f| puts "  #{f}" }
  exit 1
end

content = File.read(target_file)

if content =~ /\b70\s*=>/
  puts "Already has version 70 support, skipping"
  exit 0
end

# The hash has entries in descending order (77, 63, 60, 56...).
# Insert 70 after the highest existing entry (77 => 'Xcode 16.0').
# This is safe regardless of how many entries follow.
patched = content.gsub(/(\b77\s*=>\s*'[^']*')/) do
  "#{$1},\n    70 => 'Xcode 26.0'"
end

if patched == content
  # Fallback: insert before the closing }.freeze of the hash
  patched = content.gsub(/(COMPATIBILITY_VERSION_BY_OBJECT_VERSION\s*=\s*\{[^}]+?)(\s*\}\.freeze)/) do
    "#{$1},\n    70 => 'Xcode 26.0'#{$2}"
  end
end

if patched == content
  warn "ERROR: Could not patch constants.rb. Printing lines with version numbers:"
  content.each_line { |l| puts l.chomp if l =~ /=>\s*'Xcode/ }
  exit 1
end

File.write(target_file, patched)
puts "Successfully patched #{target_file}"
RUBY_PATCH

echo "=== flutter precache --ios ==="
flutter precache --ios

echo "=== pod install ==="
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "=== Done ==="

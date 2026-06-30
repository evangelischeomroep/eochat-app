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

echo "=== Update xcodeproj gem (Xcode 26 object version 70 fix) ==="
# xcodeproj 1.27.0 (bundled with CocoaPods 1.16.2) doesn't recognise Xcode 26's
# project object version 70. We upgrade xcodeproj inside CocoaPods' own bundled
# gem environment so no root/sudo is needed.
#
# Homebrew installs CocoaPods' gems under $(brew --prefix cocoapods)/libexec/,
# not directly under $(dirname $(which pod))/../libexec/.
POD_PATH=$(which pod)
echo "pod is at: $POD_PATH"
COCOAPODS_PREFIX=$(brew --prefix cocoapods 2>/dev/null || echo "")
echo "CocoaPods Homebrew prefix: $COCOAPODS_PREFIX"
if [ -n "$COCOAPODS_PREFIX" ] && [ -f "$COCOAPODS_PREFIX/libexec/bin/gem" ]; then
  echo "Using CocoaPods bundled gem: $COCOAPODS_PREFIX/libexec/bin/gem"
  "$COCOAPODS_PREFIX/libexec/bin/gem" install xcodeproj
else
  echo "CocoaPods bundled gem not found via brew; falling back to user gem install"
  gem install --user-install xcodeproj
  export PATH="$(ruby -e 'puts Gem.user_bin_dir'):$PATH"
fi

echo "=== pod install ==="
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "=== Done ==="

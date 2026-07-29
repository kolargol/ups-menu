#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-release}"
PROJECT="$ROOT_DIR/UPSMenu.xcodeproj"
SCHEME="UPSMenu"
VERSION_FILE="$ROOT_DIR/VERSION"
BUILD_NUMBER_FILE="$ROOT_DIR/BUILD_NUMBER"
SIGNING_CONFIG="${SIGNING_CONFIG:-$ROOT_DIR/.signing.env}"

if [[ -f "$SIGNING_CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$SIGNING_CONFIG"
fi

DISTRIBUTION_BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.local.UPSMenu}"

read_versions() {
    VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
    BUILD_NUMBER="$(tr -d '[:space:]' < "$BUILD_NUMBER_FILE")"

    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "error: VERSION must use major.minor.patch format" >&2
        exit 1
    fi
    if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
        echo "error: BUILD_NUMBER must be a positive integer" >&2
        exit 1
    fi
}

show_version() {
    echo "UPS Menu $VERSION ($BUILD_NUMBER)"
}

bump_version() {
    local component="${1:-build}"
    local major minor patch
    IFS=. read -r major minor patch <<< "$VERSION"

    case "$component" in
        build)
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        *)
            echo "Usage: $0 bump [build|patch|minor|major]" >&2
            exit 2
            ;;
    esac

    VERSION="$major.$minor.$patch"
    BUILD_NUMBER=$((BUILD_NUMBER + 1))
    printf '%s\n' "$VERSION" > "$VERSION_FILE"
    printf '%s\n' "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"
    show_version
}

read_versions

case "$MODE" in
    version)
        show_version
        exit 0
        ;;
    bump)
        bump_version "${2:-build}"
        exit 0
        ;;
    compatibility)
        compatibility_directory="$(mktemp -d)"
        trap 'rm -rf "$compatibility_directory"' EXIT
        compatibility_binary="$compatibility_directory/ups-menu-compatibility"
        xcrun swiftc \
            "$ROOT_DIR/UPSMenu/UPSDeviceProfile.swift" \
            "$ROOT_DIR/Scripts/CompatibilityCheck.swift" \
            -o "$compatibility_binary"
        "$compatibility_binary" "${@:2}"
        exit $?
        ;;
esac

if command -v xcodegen >/dev/null 2>&1; then
    XCODEGEN="$(command -v xcodegen)"
elif [[ -x /opt/homebrew/bin/xcodegen ]]; then
    XCODEGEN="/opt/homebrew/bin/xcodegen"
else
    echo "error: XcodeGen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi

cd "$ROOT_DIR"
"$XCODEGEN" generate

build_local() {
    local configuration="$1"
    local derived_data="$2"
    local app="$derived_data/Build/Products/$configuration/UPS Menu.app"

    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$configuration" \
        -destination "platform=macOS,arch=$(uname -m)" \
        -derivedDataPath "$derived_data" \
        MARKETING_VERSION="$VERSION" \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
        PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
        CODE_SIGNING_ALLOWED=NO \
        build

    codesign --force --deep --sign - "$app"
    codesign --verify --deep --strict --verbose=2 "$app"
    echo "Built: $app"
}

case "$MODE" in
    debug)
        build_local Debug "$ROOT_DIR/.build"
        ;;
    release)
        build_local Release "$ROOT_DIR/.release-build"
        ;;
    test)
        xcodebuild test \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -destination "platform=macOS,arch=$(uname -m)" \
            -derivedDataPath "$ROOT_DIR/.test-build" \
            MARKETING_VERSION="$VERSION" \
            CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
            PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
            CODE_SIGNING_ALLOWED=NO
        ;;
    distribution)
        if [[ -z "${DEVELOPMENT_TEAM:-}" || -z "${CODE_SIGN_IDENTITY:-}" || -z "$DISTRIBUTION_BUNDLE_IDENTIFIER" ]]; then
            echo "error: distribution requires DEVELOPMENT_TEAM, CODE_SIGN_IDENTITY, and BUNDLE_IDENTIFIER." >&2
            echo "Copy .signing.env.example to .signing.env and set your Apple Developer values." >&2
            exit 1
        fi
        derived_data="$ROOT_DIR/.distribution-build"
        app="$derived_data/Build/Products/Release/UPS Menu.app"

        xcodebuild \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration Release \
            -destination "platform=macOS,arch=$(uname -m)" \
            -derivedDataPath "$derived_data" \
            DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
            MARKETING_VERSION="$VERSION" \
            CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
            PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
            CODE_SIGN_STYLE=Manual \
            CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
            OTHER_CODE_SIGN_FLAGS="--timestamp" \
            build

        codesign --verify --deep --strict --verbose=2 "$app"
        echo "Built and signed: $app"
        ;;
    *)
        echo "Usage: $0 [debug|release|test|distribution|compatibility|version|bump]" >&2
        exit 2
        ;;
esac

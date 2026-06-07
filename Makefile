.PHONY: generate format lint test test-functions test-backend test-backend-linked test-backend-linked-query hosted-dress-rehearsal build-ios archive-ios upload-ios ci tickets

ARCHIVE_PATH ?= Build/Archives/Bracket48.xcarchive
EXPORT_PATH ?= Build/Export
APP_STORE_EXPORT_OPTIONS ?= BuildSupport/ExportOptions.app-store-connect.plist

generate:
	xcodegen generate

format:
	@command -v swiftformat >/dev/null 2>&1 || { echo "swiftformat is not installed"; exit 1; }
	swiftformat App

lint:
	@command -v swiftlint >/dev/null 2>&1 || { echo "swiftlint is not installed"; exit 1; }
	swiftlint lint

test:
	swift test --package-path App/Bracket48Core

test-functions:
	pnpm dlx deno test Backend/supabase/functions/_shared

test-backend:
	pnpm dlx supabase test db --workdir Backend --local Backend/supabase/tests

test-backend-linked:
	pnpm dlx supabase test db --workdir Backend --linked Backend/supabase/tests

test-backend-linked-query:
	pnpm dlx supabase db query --workdir Backend --linked --file supabase/tests/rls_authorization_test.sql --output table

hosted-dress-rehearsal:
	node Backend/scripts/hosted_dress_rehearsal.mjs

build-ios: generate
	xcodebuild -project Bracket48.xcodeproj -scheme Bracket48 -destination 'generic/platform=iOS Simulator' build

archive-ios: generate
	xcodebuild -project Bracket48.xcodeproj -scheme Bracket48 -configuration Release -destination 'generic/platform=iOS' -archivePath "$(ARCHIVE_PATH)" archive

upload-ios:
	xcodebuild -exportArchive -archivePath "$(ARCHIVE_PATH)" -exportPath "$(EXPORT_PATH)" -exportOptionsPlist "$(APP_STORE_EXPORT_OPTIONS)" -allowProvisioningUpdates

ci: lint test test-functions test-backend build-ios

tickets:
	@ls tickets/WCB-*.md 2>/dev/null | sort || true

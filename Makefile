.PHONY: generate format lint test test-functions test-backend test-backend-linked test-backend-linked-query build-ios ci tickets

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

build-ios: generate
	xcodebuild -project Bracket48.xcodeproj -scheme Bracket48 -destination 'generic/platform=iOS Simulator' build

ci: lint test test-functions test-backend build-ios

tickets:
	@ls tickets/WCB-*.md 2>/dev/null | sort || true

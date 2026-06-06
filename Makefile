.PHONY: generate format lint test build-ios ci tickets

generate:
	xcodegen generate

format:
	@command -v swiftformat >/dev/null 2>&1 || { echo "swiftformat is not installed"; exit 1; }
	swiftformat App

lint:
	@command -v swiftlint >/dev/null 2>&1 || { echo "swiftlint is not installed"; exit 1; }
	swiftlint lint

test:
	swift test --package-path App/WorldCupBracketCore

build-ios: generate
	xcodebuild -project WorldCupBracket.xcodeproj -scheme WorldCupBracket -destination 'generic/platform=iOS Simulator' build

ci: lint test build-ios

tickets:
	@ls tickets/WCB-*.md 2>/dev/null | sort || true

.PHONY: build test run verify lint format icons package clean

build:
	swift build

test:
	swift test

run:
	./script/build_and_run.sh

verify:
	./script/build_and_run.sh --verify

lint:
	swift-format lint --configuration .swift-format --recursive --strict Sources Tests
	shellcheck script/*.sh

format:
	swift-format format --configuration .swift-format --in-place --recursive Sources Tests

icons:
	./script/make_icons.sh

package:
	./script/package_dmg.sh

clean:
	rm -rf .build dist

include .env
export DECISION_MODEL DECISION_DEBUG

.PHONY: format run test

format:
	find bin lib -name "*.dart" \
		! -name "*.g.dart" \
		! -name "*.freezed.dart" \
		! -path "lib/l10n/*" \
		! -path "lib/util/assets/*" \
		| xargs fvm dart format

run:
	fvm dart run

test:
	fvm dart test

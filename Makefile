.PHONY: format

format:
	find bin lib -name "*.dart" \
		! -name "*.g.dart" \
		! -name "*.freezed.dart" \
		! -path "lib/l10n/*" \
		! -path "lib/util/assets/*" \
		| xargs fvm dart format

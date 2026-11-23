#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2026 Authors of shirudo
#
# Check that every file the page refers to is in the site and that every
# link it makes answers, so that a page renamed in the documentation does
# not leave a dead link here.

set -u

site=${1:-site}
page=$site/index.html
fail=0

for ref in $(grep -oE '(src|srcset|href)="[^"#:]+"' "$page" |
	sed -E 's/^[a-z]+="//; s/"$//' | sort -u); do
	[ "$ref" = / ] && continue
	if [ ! -e "$site/$ref" ]; then
		printf 'missing file: %s\n' "$ref"
		fail=1
	fi
done

# Links a reader follows; the canonical address is the page itself, which
# the first deployment brings up only after this check passes.
for url in $(grep -oE '<a [^>]*href="https://[^"]+"' "$page" |
	sed -E 's/.*href="//; s/"$//' | sort -u); do
	code=$(curl -s -L -o /dev/null -m 30 --retry 3 --retry-delay 5 \
		-w '%{http_code}' "$url") || code=000
	# github.com throttles scripted requests with a 429 or a 5xx; only an
	# answer that the page is gone fails the check.
	case $code in
	2??) ;;
	429 | 5?? | 000)
		printf 'not checked: %s %s\n' "$code" "$url"
		;;
	*)
		printf 'dead link: %s %s\n' "$code" "$url"
		fail=1
		;;
	esac
done

exit $fail

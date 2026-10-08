#!/usr/bin/env bash
# Waits for the latest CI run (or the run id given) and prints only what matters from the report:
# step outcomes, failed tests, compile errors and the l10n sync line.
#   bash scripts/ci_report.sh [run-id]
set -u
GH="${GH:-gh}"
command -v "$GH" >/dev/null 2>&1 || GH="/c/Program Files/GitHub CLI/gh.exe"
REPO=Dakrsnyk/tessera
RUN="${1:-$("$GH" run list --repo $REPO --limit 1 --json databaseId -q '.[0].databaseId')}"
"$GH" run watch "$RUN" --repo $REPO --interval 60 >/dev/null 2>&1
"$GH" run view "$RUN" --repo $REPO --json conclusion,displayTitle -q '"run \(.displayTitle): \(.conclusion)"'
git fetch -q origin ci-report
REPORT=$(git show origin/ci-report:report.txt)
echo "$REPORT" | sed -n '1,9p'
echo "$REPORT" | grep -E "l10n sync|Test Case .*failed|error:" | sort -u | head -60
echo "tests passed: $(echo "$REPORT" | grep -cE 'Test Case .*passed')"

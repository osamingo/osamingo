#!/usr/bin/env bash
#
# Tests for trim-svg.sh.
#
# Usage: trim-svg_test.sh

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR
readonly TRIM="${SCRIPT_DIR}/trim-svg.sh"
readonly TESTDATA="${SCRIPT_DIR}/testdata"

# Set by main before any test runs; the test cases read it.
workdir=""

passed=0
failed=0

pass() {
	printf 'ok   %s\n' "$1"
	passed=$((passed + 1))
}

fail() {
	printf 'FAIL %s\n     %s\n' "$1" "$2" >&2
	failed=$((failed + 1))
}

# Copies a fixture into the work directory and prints the copy's path.
stage() {
	local fixture=$1 name=$2
	local target="${workdir}/${name}.svg"
	cp "${TESTDATA}/${fixture}" "${target}"
	printf '%s' "${target}"
}

# Asserts that the script rejects a fixture without touching it. Every failure
# path is expected to leave the input as it was and to clean up after itself.
assert_rejects() {
	local name=$1 fixture=$2
	local target
	target=$(stage "${fixture}" "${name}")

	local status=0
	"${TRIM}" "${target}" >/dev/null 2>&1 || status=$?

	if ((status == 0)); then
		fail "${name}" "expected a non-zero exit status"
		return
	fi
	if ! diff -q "${TESTDATA}/${fixture}" "${target}" >/dev/null; then
		fail "${name}" "the input was modified even though the run failed"
		return
	fi
	if compgen -G "${target}.*" >/dev/null; then
		fail "${name}" "a temporary file was left behind"
		return
	fi
	pass "${name}"
}

test_matches_the_golden_output() {
	local name=${FUNCNAME[0]} target
	target=$(stage snake.svg "${name}")

	if ! "${TRIM}" "${target}"; then
		fail "${name}" "the script failed on the reference fixture"
		return
	fi
	if ! diff -q "${TESTDATA}/snake.golden.svg" "${target}" >/dev/null; then
		fail "${name}" "the output does not match testdata/snake.golden.svg"
		return
	fi
	pass "${name}"
}

test_removes_the_progress_bars() {
	local name=${FUNCNAME[0]} target
	target=$(stage snake.svg "${name}")

	"${TRIM}" "${target}"

	if grep -q 'class="u u' "${target}"; then
		fail "${name}" "progress bars are still present"
		return
	fi
	pass "${name}"
}

test_keeps_the_snake_and_the_grid() {
	local name=${FUNCNAME[0]} target
	target=$(stage snake.svg "${name}")

	"${TRIM}" "${target}"

	local snake dots
	snake=$(grep -c 'class="s s' "${target}" || true)
	dots=$(grep -c 'class="c[^"]*" x=' "${target}" || true)

	if [[ ${snake} == 0 || ${dots} == 0 ]]; then
		fail "${name}" "the snake or the grid was removed (snake=${snake} dots=${dots})"
		return
	fi
	pass "${name}"
}

test_leaves_no_temporary_file() {
	local name=${FUNCNAME[0]} target
	target=$(stage snake.svg "${name}")

	"${TRIM}" "${target}"

	if compgen -G "${target}.*" >/dev/null; then
		fail "${name}" "a temporary file was left behind"
		return
	fi
	pass "${name}"
}

test_accepts_several_files() {
	local name=${FUNCNAME[0]} first second
	first=$(stage snake.svg "${name}-1")
	second=$(stage snake.svg "${name}-2")

	"${TRIM}" "${first}" "${second}"

	if ! diff -q "${first}" "${second}" >/dev/null; then
		fail "${name}" "the two outputs differ"
		return
	fi
	if ! diff -q "${TESTDATA}/snake.golden.svg" "${first}" >/dev/null; then
		fail "${name}" "the output does not match the golden file"
		return
	fi
	pass "${name}"
}

test_rejects_a_missing_view_box() {
	assert_rejects "${FUNCNAME[0]}" no-viewbox.svg
}

test_rejects_a_non_numeric_view_box() {
	assert_rejects "${FUNCNAME[0]}" non-numeric-viewbox.svg
}

test_rejects_an_incomplete_view_box() {
	assert_rejects "${FUNCNAME[0]}" short-viewbox.svg
}

test_rejects_a_canvas_that_would_vanish() {
	assert_rejects "${FUNCNAME[0]}" tiny-canvas.svg
}

test_rejects_a_canvas_that_would_clip_the_grid() {
	assert_rejects "${FUNCNAME[0]}" overflowing-grid.svg
}

test_rejects_no_arguments() {
	local name=${FUNCNAME[0]}
	local status=0
	"${TRIM}" >/dev/null 2>&1 || status=$?

	if ((status != 2)); then
		fail "${name}" "expected exit status 2 for a usage error, got ${status}"
		return
	fi
	pass "${name}"
}

test_rejects_a_path_that_is_not_a_file() {
	local name=${FUNCNAME[0]}
	local status=0
	"${TRIM}" "${workdir}/does-not-exist.svg" >/dev/null 2>&1 || status=$?

	if ((status == 0)); then
		fail "${name}" "expected a non-zero exit status"
		return
	fi
	pass "${name}"
}

main() {
	# The template is spelled out because BSD mktemp ignores TMPDIR without one.
	workdir=$(mktemp -d "${TMPDIR:-/tmp}/trim-svg-test.XXXXXX")
	trap 'rm -rf "${workdir}"' EXIT

	local test_case
	local -a cases
	mapfile -t cases < <(declare -F | awk '{print $3}' | grep '^test_')

	for test_case in "${cases[@]}"; do
		"${test_case}"
	done

	printf '\n%d passed, %d failed\n' "${passed}" "${failed}"
	((failed == 0))
}

main "$@"

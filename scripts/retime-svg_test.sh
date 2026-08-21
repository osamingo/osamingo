#!/usr/bin/env bash
#
# Tests for retime-svg.sh.
#
# Usage: retime-svg_test.sh

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR
readonly RETIME="${SCRIPT_DIR}/retime-svg.sh"
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

# Prints every keyframe block of the file, sorted so that the comparison does
# not depend on the order they appear in.
keyframes_of() {
	local file=$1
	grep -oE '@keyframes [a-z0-9]+\{([^{}]|\{[^{}]*\})*\}' "${file}" | sort
}

# Asserts that the script rejects a fixture without touching it. Every failure
# path is expected to leave the input as it was and to clean up after itself.
assert_rejects() {
	local name=$1 fixture=$2
	local target
	target=$(stage "${fixture}" "${name}")

	local status=0
	"${RETIME}" "${target}" >/dev/null 2>&1 || status=$?

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

	if ! "${RETIME}" "${target}"; then
		fail "${name}" "the script failed on the reference fixture"
		return
	fi
	if ! diff -q "${TESTDATA}/snake.retimed.golden.svg" "${target}" >/dev/null; then
		fail "${name}" "the output does not match testdata/snake.retimed.golden.svg"
		return
	fi
	pass "${name}"
}

# The fixture spells the shorthand two ways, `none 54100ms linear infinite` for
# the grid and `none linear 54100ms infinite` for the snake, so this also
# covers both orders.
test_stretches_every_duration() {
	local name=${FUNCNAME[0]} target
	target=$(stage snake.svg "${name}")

	"${RETIME}" "${target}"

	local -a durations
	mapfile -t durations < <(grep -oE 'animation:[^;}]*' "${target}" |
		grep -oE '[0-9]+ms' | sort -u)

	if [[ ${#durations[@]} != 1 || ${durations[0]} != 81150ms ]]; then
		fail "${name}" "expected every animation to last 81150ms, got ${durations[*]}"
		return
	fi
	pass "${name}"
}

test_delays_every_animation() {
	local name=${FUNCNAME[0]} target
	target=$(stage snake.svg "${name}")

	local before
	before=$(grep -oE 'animation:[^;}]*' "${target}" | wc -l || true)

	"${RETIME}" "${target}"

	local delayed
	delayed=$(grep -oE 'animation-delay:1000ms;animation-fill-mode:backwards' "${target}" | wc -l || true)

	if ((before != delayed)); then
		fail "${name}" "expected ${before} delayed animations, got ${delayed}"
		return
	fi
	pass "${name}"
}

# Keyframe offsets are percentages of the duration, so the rewrite must leave
# them alone: stretching the duration is what slows the animation down. The
# reference fixture carries no keyframes, hence the dedicated one.
test_keeps_the_keyframes_untouched() {
	local name=${FUNCNAME[0]} target
	target=$(stage keyframes.svg "${name}")

	local before
	before=$(keyframes_of "${TESTDATA}/keyframes.svg")

	"${RETIME}" "${target}"

	local after
	after=$(keyframes_of "${target}")

	if [[ ${before} != "${after}" ]]; then
		fail "${name}" "the keyframes were rewritten"
		return
	fi
	if ! grep -q 'animation:none 15000ms linear infinite' "${target}"; then
		fail "${name}" "the duration was not stretched to 15000ms"
		return
	fi
	pass "${name}"
}

test_leaves_no_temporary_file() {
	local name=${FUNCNAME[0]} target
	target=$(stage snake.svg "${name}")

	"${RETIME}" "${target}"

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

	"${RETIME}" "${first}" "${second}"

	if ! diff -q "${first}" "${second}" >/dev/null; then
		fail "${name}" "the two outputs differ"
		return
	fi
	if ! diff -q "${TESTDATA}/snake.retimed.golden.svg" "${first}" >/dev/null; then
		fail "${name}" "the output does not match the golden file"
		return
	fi
	pass "${name}"
}

test_rejects_a_file_without_an_animation() {
	assert_rejects "${FUNCNAME[0]}" no-animation.svg
}

test_rejects_an_already_retimed_file() {
	assert_rejects "${FUNCNAME[0]}" already-retimed.svg
}

test_rejects_no_arguments() {
	local name=${FUNCNAME[0]}
	local status=0
	"${RETIME}" >/dev/null 2>&1 || status=$?

	if ((status != 2)); then
		fail "${name}" "expected exit status 2 for a usage error, got ${status}"
		return
	fi
	pass "${name}"
}

test_rejects_a_path_that_is_not_a_file() {
	local name=${FUNCNAME[0]}
	local status=0
	"${RETIME}" "${workdir}/does-not-exist.svg" >/dev/null 2>&1 || status=$?

	if ((status == 0)); then
		fail "${name}" "expected a non-zero exit status"
		return
	fi
	pass "${name}"
}

main() {
	# The template is spelled out because BSD mktemp ignores TMPDIR without one.
	workdir=$(mktemp -d "${TMPDIR:-/tmp}/retime-svg-test.XXXXXX")
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

#!/usr/bin/env bash
#
# Slows the snake animation down and holds its first frame for a moment before
# it starts. snk fixes the pace at 100ms per step and exposes no option for
# either.
#
# Files are rewritten in place. A file is only replaced once the rewrite has
# been verified, so a failure leaves the original untouched.
#
# Usage: retime-svg.sh <file.svg>...

set -euo pipefail

# The animation is stretched to SLOWDOWN_NUM/SLOWDOWN_DEN of its length. Every
# keyframe offset snk emits is a percentage of the duration, so stretching the
# duration alone slows the whole animation down evenly.
readonly SLOWDOWN_NUM=3
readonly SLOWDOWN_DEN=2

# How long the animation holds still before it starts, in ms. CSS applies a
# delay to the first iteration only, so the loop keeps running without a pause
# afterwards. `backwards` makes the wait show the first frame instead of the
# state the elements would be in with no animation at all.
readonly START_DELAY_MS=2000

err() {
	printf '%s: %s\n' "${0##*/}" "$*" >&2
}

# Prints every `animation` shorthand declaration in the file, one per line.
# `animation-name` and the other longhands do not match, because their property
# name is followed by a dash rather than by a colon.
animation_declarations() {
	local file=$1
	grep -oE 'animation:[^;}]*' "${file}"
}

# Prints the duration of every animation, in ms, without duplicates. snk emits
# the same duration for the grid, the snake and the progress bars, but the
# order of the values within the shorthand differs between them, so the number
# is read from the declaration as a whole.
read_durations() {
	local file=$1
	animation_declarations "${file}" | grep -oE '[0-9]+ms' | sed 's|ms$||' | sort -un
}

# Prints the delay that this script appends, once per animation it was appended
# to. Both declarations are matched together so that a partial rewrite cannot
# pass for a complete one.
delay_declarations() {
	local file=$1
	grep -oE "animation-delay:${START_DELAY_MS}ms;animation-fill-mode:backwards" "${file}"
}

slowed_down() {
	local duration=$1
	printf '%d' "$((duration * SLOWDOWN_NUM / SLOWDOWN_DEN))"
}

# Checks the rewrite against the rewritten file rather than against the numbers
# used to produce it, so that a miscalculation cannot validate itself.
assert_retimed() {
	local src=$1 dst=$2

	local -a before after
	mapfile -t before < <(read_durations "${src}")
	mapfile -t after < <(read_durations "${dst}")

	if ((${#before[@]} != ${#after[@]})); then
		err "${dst}: expected ${#before[@]} distinct durations, got ${#after[@]}"
		return 1
	fi

	local i expected
	for i in "${!before[@]}"; do
		expected=$(slowed_down "${before[i]}")
		if [[ ${after[i]} != "${expected}" ]]; then
			err "${dst}: expected a duration of ${expected}ms, got ${after[i]}ms"
			return 1
		fi
	done

	# The delay is a declaration of its own, so it is counted over the file
	# rather than within the shorthand it was appended to.
	local total delayed
	total=$(animation_declarations "${src}" | wc -l || true)
	delayed=$(delay_declarations "${dst}" | wc -l || true)
	if ((total != delayed)); then
		err "${dst}: ${delayed} of ${total} animations carry the start delay"
		return 1
	fi
}

# Writes the retimed copy of src to dst and verifies the result. The
# expressions run in order, so the delay is appended only once the durations
# have been rewritten and can no longer be mistaken for one.
rewrite_timing() {
	local src=$1 dst=$2
	shift 2
	local -a values=("$@")

	local -a expressions=()
	local value
	for value in "${values[@]}"; do
		# The character before the duration is matched as well, so that a
		# duration cannot be rewritten while it is part of a longer number.
		expressions+=(-e "s|(animation:[^;}]*[^0-9])${value}ms|\1$(slowed_down "${value}")ms|g")
	done
	expressions+=(-e "s|(animation:[^;}]*)|\1;animation-delay:${START_DELAY_MS}ms;animation-fill-mode:backwards|g")

	sed -E "${expressions[@]}" "${src}" >"${dst}"

	assert_retimed "${src}" "${dst}"
}

retime_file() {
	local file=$1

	local -a values
	mapfile -t values < <(read_durations "${file}")
	if ((${#values[@]} == 0)); then
		err "${file}: no animation duration found"
		return 1
	fi

	# A second run would stack another delay onto the first and stretch the
	# durations again, so a file that has already been retimed is refused.
	if grep -q 'animation-delay:' "${file}"; then
		err "${file}: the animations already carry a start delay"
		return 1
	fi

	# Written next to the target so the rename stays within one file system and
	# is therefore atomic. The name keeps the original prefix so that any error
	# still points at the file being processed.
	local tmp
	tmp=$(mktemp "${file}.XXXXXX")

	if ! rewrite_timing "${file}" "${tmp}" "${values[@]}"; then
		rm -f "${tmp}"
		return 1
	fi

	mv "${tmp}" "${file}"
}

main() {
	if (($# == 0)); then
		err "usage: ${0##*/} <file.svg>..."
		return 2
	fi

	local file
	for file in "$@"; do
		if [[ ! -f ${file} ]]; then
			err "${file}: not a file"
			return 1
		fi
		retime_file "${file}"
	done
}

main "$@"

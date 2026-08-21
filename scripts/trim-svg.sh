#!/usr/bin/env bash
#
# Removes the progress bars that snk draws under the contribution grid and
# tightens the padding around the grid, so it fills the width the README gives
# it. snk exposes no option for either.
#
# Files are rewritten in place. A file is only replaced once the rewrite has
# been verified, so a failure leaves the original untouched.
#
# Usage: trim-svg.sh <file.svg>...

set -euo pipefail

# Padding to reclaim, in SVG user units. snk lays the grid out on a 16px cell
# and leaves about one cell of margin, of which 4px is kept so the dots do not
# touch the edge. The top margin is deliberately left alone: the snake waits
# above the grid before it enters, and trimming it would clip the snake.
readonly TRIM_X=14
readonly TRIM_WIDTH=28
readonly TRIM_HEIGHT=46

# Side of a single contribution dot, taken from snk's own stylesheet
# (`.c{...width:12px;height:12px}`). Used to derive the extent of the grid.
readonly DOT_SIZE=12

err() {
	printf '%s: %s\n' "${0##*/}" "$*" >&2
}

read_view_box() {
	local file=$1
	sed -nE 's|.*viewBox="([^"]*)".*|\1|p' "${file}" | head -n 1
}

# Prints the value of the given attribute for every dot of the grid, one per
# line. Dots carry either `class="c"` or `class="c cN"`.
dot_coordinates() {
	local file=$1 attr=$2
	grep -oE 'class="c[^"]*" x="[0-9]+" y="[0-9]+"' "${file}" |
		sed -E "s|.*${attr}=\"([0-9]+)\".*|\1|"
}

# Checks the canvas against the grid itself rather than against the numbers
# used to produce it, so that a miscalculation cannot validate itself.
assert_grid_fits() {
	local file=$1 x=$2 y=$3 width=$4 height=$5

	local -a xs ys
	mapfile -t xs < <(dot_coordinates "${file}" x | sort -n)
	mapfile -t ys < <(dot_coordinates "${file}" y | sort -n)

	if ((${#xs[@]} == 0)); then
		err "${file}: no contribution dots found"
		return 1
	fi

	local left=${xs[0]} top=${ys[0]}
	local right=$((xs[-1] + DOT_SIZE)) bottom=$((ys[-1] + DOT_SIZE))

	if ((x > left || y > top || x + width < right || y + height < bottom)); then
		err "${file}: canvas \"${x} ${y} ${width} ${height}\" does not cover the grid (${left},${top} to ${right},${bottom})"
		return 1
	fi
}

# Writes the trimmed copy of src to dst and verifies the result.
rewrite_canvas() {
	local src=$1 dst=$2 x=$3 y=$4 width=$5 height=$6

	sed -E \
		-e 's|<rect class="u u[0-9]+"[^>]*/>||g' \
		-e "s|viewBox=\"[^\"]*\"|viewBox=\"${x} ${y} ${width} ${height}\"|" \
		-e "s|(<svg[^>]*width=\")[0-9]+(\")|\1${width}\2|" \
		-e "s|(<svg[^>]*height=\")[0-9]+(\")|\1${height}\2|" \
		"${src}" >"${dst}"

	if grep -q 'class="u u' "${dst}"; then
		err "${dst}: progress bars are still present after the rewrite"
		return 1
	fi

	assert_grid_fits "${dst}" "${x}" "${y}" "${width}" "${height}"
}

trim_file() {
	local file=$1

	local view_box
	view_box=$(read_view_box "${file}")
	if [[ -z ${view_box} ]]; then
		err "${file}: no viewBox attribute found"
		return 1
	fi

	local -a box
	read -r -a box <<<"${view_box}"
	if ((${#box[@]} != 4)); then
		err "${file}: expected 4 values in viewBox, got \"${view_box}\""
		return 1
	fi

	local value
	for value in "${box[@]}"; do
		if [[ ! ${value} =~ ^-?[0-9]+$ ]]; then
			err "${file}: non-integer value \"${value}\" in viewBox \"${view_box}\""
			return 1
		fi
	done

	local x=$((box[0] + TRIM_X))
	local y=${box[1]}
	local width=$((box[2] - TRIM_WIDTH))
	local height=$((box[3] - TRIM_HEIGHT))

	if ((width <= 0 || height <= 0)); then
		err "${file}: trimming would leave a ${width}x${height} canvas"
		return 1
	fi

	# Written next to the target so the rename stays within one file system and
	# is therefore atomic. The name keeps the original prefix so that any error
	# still points at the file being processed.
	local tmp
	tmp=$(mktemp "${file}.XXXXXX")

	if ! rewrite_canvas "${file}" "${tmp}" "${x}" "${y}" "${width}" "${height}"; then
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
		trim_file "${file}"
	done
}

main "$@"

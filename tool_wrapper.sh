#!/bin/bash
set -euxo pipefail

tool="$1"; shift;
input="$1"; shift;
bazel_output="$1"; shift;
other_args="$@"
output="$(basename $input .dvi).svg";

$tool $input $other_args
cp $output $bazel_output

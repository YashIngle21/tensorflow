#!/bin/bash
source "${BASH_SOURCE%/*}/utilities/setup.sh"

# Parse options and build targets into arrays, so that shelllint doesn't yell
# about readability. We can't pipe into 'read -ra' to create an array because
# piped commands run in subshells, which can't store variables outside of the
# subshell environment.
# Ignore grep failures since we're using it for basic filtering
set +e
filtered_build_targets=( $(echo "$BUILD_TARGETS" | tr ' ' '\n' | grep .) )
nonpip_targets=( $(echo "$TEST_TARGETS" | tr ' ' '\n' | grep -E "^//tensorflow/" ) )
config=( $(echo "$CONFIG_OPTIONS" ) )
test_flags=( $(echo "$TEST_FLAGS" ) )
set -e

if [[ "$TFCI_NVIDIA_SMI_ENABLE" == 1 ]]; then
  tfrun nvidia-smi
fi

if [[ "${#filtered_build_targets[@]}" -ne 0 ]]; then
  tfrun bazel "${TFCI_BAZEL_BAZELRC_ARGS[@]}" "${config[@]}" "${filtered_build_targets[@]}"
fi

if [[ "${PIP_WHEEL}" -eq "1" ]]; then
  # Update the version numbers to build a "nightly" package
  if [[ "$TFCI_NIGHTLY_UPDATE_VERSION_ENABLE" == 1 ]]; then
    tfrun python3 tensorflow/tools/ci_build/update_version.py --nightly
  fi

  tfrun bazel "${TFCI_BAZEL_BAZELRC_ARGS[@]}" build "${TFCI_BAZEL_COMMON_ARGS[@]}" tensorflow/tools/pip_package:build_pip_package
  tfrun ./bazel-bin/tensorflow/tools/pip_package/build_pip_package build "${TFCI_BUILD_PIP_PACKAGE_ARGS[@]}"
  tfrun ./ci/official/utilities/rename_and_verify_wheels.sh
fi

if [[ "${#nonpip_targets[@]}" -ne 0 ]]; then
  tfrun bazel "${TFCI_BAZEL_BAZELRC_ARGS[@]}" test "${config[@]}" "${test_flags[@]}" "${nonpip_targets[@]}"
fi

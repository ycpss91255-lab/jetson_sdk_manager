#!/usr/bin/env bats
#
# What this repo has to get right against the vendored base (.base/): the
# container wrappers it calls, and the setup.toml keys whose base default is
# wrong for a tool that writes to hardware. devel-test COPYs script/ and
# setup.toml to /opt/repo for these; a missing copy FAILS, it never skips.

setup() {
  load "${BATS_TEST_DIRNAME}/test_helper"

  REPO_DIR="/opt/repo"
  [[ -d "${REPO_DIR}" ]] || REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/../../../.." && pwd)"
  SETUP_TOML="${REPO_DIR}/setup.toml"
}

@test "the repo files under test are present" {
  [[ -f "${REPO_DIR}/script/jetson.sh" ]]
  [[ -f "${REPO_DIR}/script/lib/fs.sh" ]]
  [[ -f "${SETUP_TOML}" ]]
}

@test "no script under script/ calls or advertises a make target (base removed the Makefile)" {
  [[ -f "${REPO_DIR}/script/jetson.sh" ]]
  # -r does not follow symlinks, so the .base wrappers are not scanned.
  run grep -rnE '(^|[^[:alnum:]_])make[[:space:]]+(run|build|stop|test|exec)([^[:alnum:]_]|$)' "${REPO_DIR}/script"
  assert_failure 1
  assert_output ''
}

@test "no script under script/ points at the removed setup.conf" {
  [[ -f "${REPO_DIR}/script/jetson.sh" ]]
  run grep -rnF 'setup.conf' "${REPO_DIR}/script"
  assert_failure 1
  assert_output ''
}

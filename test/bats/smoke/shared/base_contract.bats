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

# _stage_cmd <stage> — the CMD of one Dockerfile stage.
_stage_cmd() {
  awk -v want="$1" '/^FROM / { in_stage = ($NF == want) } in_stage && /^CMD /' "${REPO_DIR}/Dockerfile"
}

# _toml_table <name> — the lines of one [table] in setup.toml.
_toml_table() {
  awk -v want="[$1]" '/^\[/ { in_table = ($0 == want); next } in_table' "${SETUP_TOML}"
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

@test "jetson.sh passes run.sh the same command the stage's Dockerfile CMD runs" {
  # Without a command run.sh uses 'compose up', which exits 0 even when the
  # stage failed; with one it uses 'compose run' and returns the real code.
  local stage
  for stage in prepare flash; do
    run _stage_cmd "${stage}"
    assert_success
    assert_output "CMD [\"/opt/jetson_install/${stage}.sh\"]"
  done
  run grep -F '"${RUN_BIN}" -t "${stage}" "/opt/jetson_install/${stage}.sh"' "${REPO_DIR}/script/jetson.sh"
  assert_success
}

@test "setup.toml: no \${...} in [environment] — it reaches the container as literal text" {
  [[ -f "${SETUP_TOML}" ]]
  run _toml_table environment
  assert_success
  refute_output --partial '${'
}

@test "setup.toml: [lifecycle] restart is \"no\" — a finished flash must not start again" {
  [[ -f "${SETUP_TOML}" ]]
  run _toml_table lifecycle
  assert_success
  assert_output --partial 'restart = "no"'
}

# hooks/session-start 테스트 (JSON 검증에 python3 사용)
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"

run_session_start() {
  local hook_input="$1"
  printf '%s' "$hook_input" | BROWNFIELD_NAVIGATOR_HOME="$TEST_TMP/profiles" "$BASH" "$PLUGIN_ROOT/hooks/session-start" 2>&1
}

# 훅 출력 JSON을 파싱해 additionalContext 값을 출력. JSON이 올바르지 않으면 INVALID_JSON 출력
read_additional_context() {
  python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    sys.stdout.write(data["hookSpecificOutput"]["additionalContext"])
except Exception as error:
    sys.stdout.write("INVALID_JSON: %s" % error)
'
}

write_acme_profile() {
  write_lines "$TEST_TMP/profiles/orgs/acme/profile.md" \
    "---" "match-remotes:" '  - "*acme/*"' "---" "$@"
}

test_outputs_valid_json_with_special_characters() {
  write_acme_profile \
    "## [special] 특수문자" \
    "$(printf '따옴표 "q" 백슬래시 \\ 탭\t끝')" \
    "$(printf '폼피드\f와 제어문자\001 제거')"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local context
  context="$(run_session_start "{\"session_id\":\"s\",\"cwd\":\"$TEST_TMP/app\",\"hook_event_name\":\"SessionStart\"}" | read_additional_context)"
  assert_not_contains "$context" "INVALID_JSON" "올바른 JSON 출력"
  assert_contains "$context" "# brownfield-navigator 가이드" "가이드가 additionalContext에 들어감"
  assert_contains "$context" "$(printf '따옴표 "q" 백슬래시 \\ 탭\t끝')" "따옴표, 백슬래시, 탭 보존"
  assert_contains "$context" "폼피드와 제어문자 제거" "그 밖의 제어문자는 제거"
}

test_outputs_nothing_without_match() {
  write_acme_profile "## [rule] 규칙" "본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:other/app.git"
  assert_empty "$(run_session_start "{\"cwd\":\"$TEST_TMP/app\"}")" "매칭이 없으면 빈 출력"
}

test_falls_back_to_project_dir_env() {
  write_acme_profile "## [rule] 규칙" "본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local context
  context="$(CLAUDE_PROJECT_DIR="$TEST_TMP/app" run_session_start '{"session_id":"s"}' | read_additional_context)"
  assert_contains "$context" "## [rule] 규칙 (조직: acme)" "cwd가 없으면 CLAUDE_PROJECT_DIR 사용"
}

test_prefers_cwd_over_project_dir_env() {
  write_acme_profile "## [rule] 규칙" "본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  mkdir -p "$TEST_TMP/elsewhere"
  local output
  output="$(CLAUDE_PROJECT_DIR="$TEST_TMP/app" run_session_start "{\"cwd\":\"$TEST_TMP/elsewhere\"}")"
  assert_empty "$output" "입력의 cwd가 CLAUDE_PROJECT_DIR보다 우선"
}

run_test test_outputs_valid_json_with_special_characters
run_test test_outputs_nothing_without_match
run_test test_falls_back_to_project_dir_env
run_test test_prefers_cwd_over_project_dir_env
finish_tests

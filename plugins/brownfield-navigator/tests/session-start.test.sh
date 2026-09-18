# hooks/session-start 테스트 (JSON 검증에 python3 사용)
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"

run_session_start() {
  local hook_input="$1"
  printf '%s' "$hook_input" | BROWNFIELD_NAVIGATOR_HOME="$TEST_TMP/profiles" "$BASH" "$PLUGIN_ROOT/hooks/session-start" 2>&1
}

# 훅의 종료 코드만 출력한다 (출력은 버린다)
session_start_exit_code() {
  local hook_input="$1"
  printf '%s' "$hook_input" | BROWNFIELD_NAVIGATOR_HOME="$TEST_TMP/profiles" "$BASH" "$PLUGIN_ROOT/hooks/session-start" >/dev/null 2>&1
  printf '%s' "$?"
}

# 훅 출력 JSON을 파싱해 additionalContext 값을 출력. JSON이 올바르지 않으면 INVALID_JSON 출력
# Claude Code처럼 잘못된 UTF-8 바이트는 대체 문자로 읽음
read_additional_context() {
  python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    if data["hookSpecificOutput"]["hookEventName"] != "SessionStart":
        raise ValueError("hookEventName")
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
  # 개인 프로필은 frontmatter를 파싱하지 않으므로 CRLF로 저장된 파일의 CR이 그대로 들어온다
  printf '%s\r\n' "## [crlf] 캐리지 리턴" "본문" > "$TEST_TMP/profiles/personal.md"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local hook_input context
  hook_input="{\"session_id\":\"s\",\"cwd\":\"$TEST_TMP/app\",\"hook_event_name\":\"SessionStart\"}"
  assert_equals "0" "$(session_start_exit_code "$hook_input")" "훅은 종료 코드 0"
  context="$(run_session_start "$hook_input" | read_additional_context)"
  assert_not_contains "$context" "INVALID_JSON" "CR이 섞여 있어도 올바른 JSON 출력"
  assert_contains "$context" "$(printf '따옴표 "q" 백슬래시 \\ 탭\t끝')" "따옴표, 백슬래시, 탭 보존"
  assert_contains "$context" "폼피드와 제어문자 제거" "그 밖의 제어문자는 제거"
  assert_contains "$context" "$(printf '## [special] 특수문자 (조직: acme)\n따옴표')" "줄 구조 보존"
}

test_keeps_guide_after_invalid_utf8() {
  write_acme_profile \
    "## [first-rule] 첫 규칙" "잘못된 바이트 $(printf '\261\333') 포함" \
    "## [second-rule] 둘째 규칙" "둘째 본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local context
  context="$(LC_ALL=en_US.UTF-8 run_session_start "{\"cwd\":\"$TEST_TMP/app\"}" | read_additional_context)"
  assert_contains "$context" "## [second-rule] 둘째 규칙 (조직: acme)" "잘못된 UTF-8 뒤의 규칙도 JSON에 들어감"
}

test_outputs_nothing_without_match() {
  write_acme_profile "## [rule] 규칙" "본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:other/app.git"
  assert_empty "$(run_session_start "{\"cwd\":\"$TEST_TMP/app\"}")" "매칭이 없으면 빈 출력"
  assert_equals "0" "$(session_start_exit_code "{\"cwd\":\"$TEST_TMP/app\"}")" "매칭이 없어도 종료 코드 0"
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

test_exits_zero_when_compose_guide_fails() {
  local broken="$TEST_TMP/broken-plugin"
  mkdir -p "$broken/bin" "$broken/hooks"
  cp "$PLUGIN_ROOT/hooks/session-start" "$broken/hooks/session-start"
  printf '이것은 실행 파일이 아니다\n' > "$broken/bin/compose-guide"
  chmod -x "$broken/bin/compose-guide"
  mkdir -p "$TEST_TMP/app"
  local output exit_code
  output="$(printf '{"cwd":"%s"}' "$TEST_TMP/app" | "$BASH" "$broken/hooks/session-start" 2>&1)"
  exit_code=$?
  assert_equals "0" "$exit_code" "compose-guide를 실행할 수 없어도 종료 코드 0"
  assert_empty "$output" "그때는 아무것도 출력하지 않음"
}

run_test test_outputs_valid_json_with_special_characters
run_test test_keeps_guide_after_invalid_utf8
run_test test_outputs_nothing_without_match
run_test test_falls_back_to_project_dir_env
run_test test_prefers_cwd_over_project_dir_env
run_test test_exits_zero_when_compose_guide_fails
finish_tests

# templates/ 가 그대로 올바른 프로필로 동작하는지 확인
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"

test_templates_compose_without_warnings() {
  local profiles="$TEST_TMP/profiles"
  mkdir -p "$profiles/orgs/sample/projects" "$profiles/orgs/sample/references"
  cp "$PLUGIN_ROOT/templates/org-profile.md" "$profiles/orgs/sample/profile.md"
  cp "$PLUGIN_ROOT/templates/project.md" "$profiles/orgs/sample/projects/your-repo.md"
  cp "$PLUGIN_ROOT/templates/reference.md" "$profiles/orgs/sample/references/topic.md"
  cp "$PLUGIN_ROOT/templates/personal.md" "$profiles/personal.md"
  make_git_repo "$TEST_TMP/your-repo" "git@github.com:your-org/your-repo.git"
  local output
  output="$(BROWNFIELD_NAVIGATOR_HOME="$profiles" "$BASH" "$PLUGIN_ROOT/bin/compose-guide" "$TEST_TMP/your-repo" 2>&1)"
  assert_not_contains "$output" "## brownfield-navigator 경고" "템플릿은 경고 없이 파싱"
  assert_contains "$output" "## [commit-message] 커밋 메시지 (조직: sample)" "조직 템플릿 규칙 병합"
  assert_contains "$output" "## [commit-by-user] 커밋은 직접 (개인)" "개인 템플릿 규칙 병합"
  assert_contains "$output" "## [tests] 테스트 코드 (프로젝트: your-repo)" "프로젝트 템플릿 규칙 병합"
  assert_contains "$output" "references/topic.md: 이 참고 파일이 담은 내용을 한 줄로" "참고 템플릿 description"
}

run_test test_templates_compose_without_warnings
finish_tests

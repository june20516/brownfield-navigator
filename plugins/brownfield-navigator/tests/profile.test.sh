# lib/profile.sh 테스트
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"
. "$PLUGIN_ROOT/lib/profile.sh"

test_parses_apply_and_block_lists() {
  write_lines "$TEST_TMP/profile.md" \
    "---" \
    "apply: suggest" \
    "match-remotes:" \
    '  - "*acme/*"' \
    "  - *acme-mirror/*   # 주석은 무시" \
    "match-paths:" \
    "- ~/work/acme" \
    "---" \
    "## [rule] 본문"
  local parsed
  parsed="$(parse_profile_frontmatter "$TEST_TMP/profile.md")"
  assert_equals "apply=suggest
remote=*acme/*
remote=*acme-mirror/*
path=~/work/acme" "$parsed" "apply와 블록 리스트 항목을 따옴표, 주석 없이 출력"
}

test_accepts_empty_list_and_comment_lines() {
  write_lines "$TEST_TMP/profile.md" \
    "---" \
    "# 매칭 조건" \
    "" \
    "match-remotes: []" \
    "match-paths:" \
    '  - "~/work/*"' \
    "---"
  assert_equals "path=~/work/*" "$(parse_profile_frontmatter "$TEST_TMP/profile.md")" "빈 리스트와 주석 줄 처리"
}

test_fails_without_frontmatter() {
  write_lines "$TEST_TMP/profile.md" "## [rule] 본문"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/profile.md")" "error=frontmatter 없음" "첫 줄이 --- 가 아니면 실패"
}

test_fails_on_empty_file() {
  : > "$TEST_TMP/profile.md"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/profile.md")" "error=frontmatter 없음" "빈 파일은 실패"
}

test_fails_without_closing_delimiter() {
  write_lines "$TEST_TMP/profile.md" "---" "apply: auto"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/profile.md")" "error=닫는 --- 없음" "닫는 --- 가 없으면 실패"
}

test_fails_on_invalid_apply() {
  write_lines "$TEST_TMP/profile.md" "---" "apply: always" "---"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/profile.md")" "error=apply 값은" "허용되지 않는 apply 값은 실패"
}

test_fails_on_flow_list() {
  write_lines "$TEST_TMP/profile.md" "---" 'match-remotes: ["*acme/*"]' "---"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/profile.md")" "error=match-remotes 는 블록 리스트만 지원함" "flow 리스트는 실패"
}

test_warns_on_unsupported_key() {
  write_lines "$TEST_TMP/profile.md" "---" "name: acme" "설명: 사내 레포" "owner.team: web" '"quoted": x' "apply: auto" "---"
  local parsed
  parsed="$(parse_profile_frontmatter "$TEST_TMP/profile.md")"
  assert_contains "$parsed" "warning=지원하지 않는 키 무시: name" "지원하지 않는 키는 경고"
  assert_contains "$parsed" "warning=지원하지 않는 키 무시: 설명" "한글 키도 경고"
  assert_contains "$parsed" "warning=지원하지 않는 키 무시: owner.team" "점이 들어간 키도 경고"
  assert_contains "$parsed" 'warning=지원하지 않는 키 무시: "quoted"' "따옴표로 감싼 키도 경고"
  assert_contains "$parsed" "apply=auto" "경고 뒤에도 파싱 계속"
  assert_not_contains "$parsed" "error=" "지원하지 않는 키는 실패가 아님"
}

test_ignores_nested_values_of_unsupported_keys() {
  write_lines "$TEST_TMP/profile.md" \
    "---" \
    "tags:" \
    "  - legacy" \
    "metadata:" \
    "  owner: team-a" \
    "apply: auto" \
    "match-remotes:" \
    '  - "*acme/*"' \
    "---"
  local parsed
  parsed="$(parse_profile_frontmatter "$TEST_TMP/profile.md")"
  assert_not_contains "$parsed" "error=" "지원하지 않는 키의 하위 값은 실패가 아님"
  assert_contains "$parsed" "warning=지원하지 않는 키 무시: tags" "리스트 값을 가진 키 경고"
  assert_contains "$parsed" "warning=지원하지 않는 키 무시: metadata" "하위 키를 가진 키 경고"
  assert_contains "$parsed" "apply=auto
remote=*acme/*" "무시한 키 뒤의 지원 키는 계속 파싱"
}

test_fails_on_list_key_without_items() {
  write_lines "$TEST_TMP/before-key.md" "---" "match-paths:" "apply: auto" "---"
  write_lines "$TEST_TMP/before-close.md" "---" "match-remotes:" "---"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/before-key.md")" "error=match-paths 에 항목이 없음" "다음 키 전에 항목이 없으면 실패"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/before-close.md")" "error=match-remotes 에 항목이 없음" "닫는 --- 전에 항목이 없으면 실패"
}

test_reads_reference_description() {
  write_lines "$TEST_TMP/ref.md" "---" 'description: "레포 지도"' "---" "본문"
  assert_equals "레포 지도" "$(read_reference_description "$TEST_TMP/ref.md")" "description 값 추출"
}

test_reference_without_description_is_empty() {
  write_lines "$TEST_TMP/ref.md" "# 제목만 있음"
  assert_empty "$(read_reference_description "$TEST_TMP/ref.md" 2>&1)" "frontmatter가 없으면 빈 출력"
}

run_test test_parses_apply_and_block_lists
run_test test_accepts_empty_list_and_comment_lines
run_test test_fails_without_frontmatter
run_test test_fails_on_empty_file
run_test test_fails_without_closing_delimiter
run_test test_fails_on_invalid_apply
run_test test_fails_on_flow_list
run_test test_warns_on_unsupported_key
run_test test_ignores_nested_values_of_unsupported_keys
run_test test_fails_on_list_key_without_items
run_test test_reads_reference_description
run_test test_reference_without_description_is_empty
finish_tests

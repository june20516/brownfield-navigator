# lib/sections.sh 테스트
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"
. "$PLUGIN_ROOT/lib/sections.sh"

test_extracts_only_id_sections() {
  write_lines "$TEST_TMP/rules.md" \
    "---" \
    "name: sample" \
    "## [not-a-rule] frontmatter 안" \
    "---" \
    "# 제목" \
    "소개 문단" \
    "## 설명용 섹션" \
    "무시되는 본문" \
    "## [first-rule] 첫 규칙" \
    "첫 본문" \
    "" \
    "## [second-rule] 둘째 규칙" \
    '```markdown' \
    "## [inside-code] 코드 블록 안" \
    '```' \
    "둘째 본문" \
    "- 목록 안의 예시" \
    '   ```markdown' \
    "## [inside-indented-code] 들여쓴 코드 블록 안" \
    '   ```'
  extract_rule_sections "$TEST_TMP/rules.md" "$TEST_TMP/layer"
  assert_equals "first-rule
second-rule" "$(cat "$TEST_TMP/layer/ids")" "id 섹션만 등장 순서대로"
  assert_equals "첫 규칙" "$(cat "$TEST_TMP/layer/first-rule.title")" "제목 추출"
  assert_equals "첫 본문" "$(cat "$TEST_TMP/layer/first-rule.body")" "본문 추출"
  assert_contains "$(cat "$TEST_TMP/layer/second-rule.body")" "## [inside-code] 코드 블록 안" "코드 블록 안 헤딩은 본문으로 유지"
  assert_contains "$(cat "$TEST_TMP/layer/second-rule.body")" "## [inside-indented-code] 들여쓴 코드 블록 안" "들여쓴 코드 블록 안 헤딩도 본문으로 유지"
}

test_warns_when_frontmatter_is_not_closed() {
  write_lines "$TEST_TMP/rules.md" "---" "name: sample" "## [a-rule] 규칙" "본문"
  extract_rule_sections "$TEST_TMP/rules.md" "$TEST_TMP/layer"
  assert_empty "$(cat "$TEST_TMP/layer/ids")" "닫는 --- 가 없으면 규칙을 하나도 읽지 못함"
  assert_equals "frontmatter가 닫히지 않아 규칙을 읽지 못함" "$(cat "$TEST_TMP/layer/warnings")" "규칙이 사라진 이유를 진단으로 남김"
}

test_warns_on_heading_that_is_not_a_valid_id() {
  write_lines "$TEST_TMP/rules.md" \
    "## [My-Rule] 대문자" "대문자 본문" \
    "## [rule_1] 밑줄" "밑줄 본문" \
    "##  [two-spaces] 공백 두 개" "공백 본문" \
    "## 설명용 섹션" "설명 본문" \
    "## [ok-rule] 정상" "정상 본문"
  extract_rule_sections "$TEST_TMP/rules.md" "$TEST_TMP/layer"
  local warnings
  warnings="$(cat "$TEST_TMP/layer/warnings")"
  assert_equals "ok-rule" "$(cat "$TEST_TMP/layer/ids")" "id 형식에 맞는 섹션만 병합 대상"
  assert_contains "$warnings" "id 형식([a-z0-9-]+)이 아닌 규칙 헤딩 무시: ## [My-Rule] 대문자" "대문자 id 진단"
  assert_contains "$warnings" "id 형식([a-z0-9-]+)이 아닌 규칙 헤딩 무시: ## [rule_1] 밑줄" "밑줄 id 진단"
  assert_contains "$warnings" "id 형식([a-z0-9-]+)이 아닌 규칙 헤딩 무시: ##  [two-spaces] 공백 두 개" "공백 두 개 진단"
  assert_not_contains "$warnings" "설명용 섹션" "id를 쓰려 하지 않은 ## 섹션은 진단 없음"
}

test_merges_layers_in_place() {
  write_lines "$TEST_TMP/core.md" "## [alpha] 코어 알파" "코어 알파 본문" "## [beta] 코어 베타" "코어 베타 본문"
  write_lines "$TEST_TMP/project.md" "## [alpha] 프로젝트 알파" "프로젝트 알파 본문" "## [gamma] 프로젝트 감마" "감마 본문"
  extract_rule_sections "$TEST_TMP/core.md" "$TEST_TMP/core"
  extract_rule_sections "$TEST_TMP/project.md" "$TEST_TMP/project"
  merge_rule_layer "$TEST_TMP/core" "코어" "$TEST_TMP/merged"
  merge_rule_layer "$TEST_TMP/project" "프로젝트: app" "$TEST_TMP/merged"
  local output
  output="$(print_merged_sections "$TEST_TMP/merged")"
  assert_contains "$output" "## [alpha] 프로젝트 알파 (프로젝트: app)" "같은 id는 교체한 층의 제목과 출처"
  assert_occurrence_count "$output" "## [alpha]" 1 "교체된 id는 한 번만 출력"
  assert_contains "$output" "프로젝트 알파 본문" "교체한 층의 본문"
  assert_not_contains "$output" "코어 알파 본문" "교체된 본문은 빠짐"
  assert_order "$output" "## [alpha]" "## [beta]" "교체된 섹션은 원래 자리 유지"
  assert_order "$output" "## [beta]" "## [gamma]" "새 id는 끝에 추가"
  assert_contains "$output" "## [beta] 코어 베타 (코어)" "교체되지 않은 섹션은 원래 출처"
}

test_prints_heading_without_title() {
  write_lines "$TEST_TMP/rules.md" "## [bare]" "본문"
  extract_rule_sections "$TEST_TMP/rules.md" "$TEST_TMP/layer"
  merge_rule_layer "$TEST_TMP/layer" "개인" "$TEST_TMP/merged"
  assert_contains "$(print_merged_sections "$TEST_TMP/merged")" "## [bare] (개인)" "제목이 없으면 id와 출처만"
}

test_prints_first_paragraph_for_summary_source() {
  write_lines "$TEST_TMP/core.md" "## [alpha] 코어 알파" "" "코어 요약 문단" "요약 둘째 줄" "" "- 코어 세부 목록" "" "**Why:** 코어 이유"
  write_lines "$TEST_TMP/org.md" "## [beta] 조직 베타" "조직 요약 문단" "" "**Why:** 조직 이유"
  extract_rule_sections "$TEST_TMP/core.md" "$TEST_TMP/core"
  extract_rule_sections "$TEST_TMP/org.md" "$TEST_TMP/org"
  merge_rule_layer "$TEST_TMP/core" "코어" "$TEST_TMP/merged"
  merge_rule_layer "$TEST_TMP/org" "조직: acme" "$TEST_TMP/merged"
  local output
  output="$(print_merged_sections "$TEST_TMP/merged" "코어")"
  assert_contains "$output" "## [alpha] 코어 알파 (코어)
코어 요약 문단
요약 둘째 줄
" "요약 대상 출처는 첫 문단 전체(여러 줄)"
  assert_not_contains "$output" "코어 세부 목록" "요약 대상의 나머지 본문은 빠짐"
  assert_not_contains "$output" "코어 이유" "요약 대상의 Why는 빠짐"
  assert_contains "$output" "**Why:** 조직 이유" "다른 출처는 본문 전체"
}

run_test test_extracts_only_id_sections
run_test test_warns_when_frontmatter_is_not_closed
run_test test_warns_on_heading_that_is_not_a_valid_id
run_test test_merges_layers_in_place
run_test test_prints_heading_without_title
run_test test_prints_first_paragraph_for_summary_source
finish_tests

# README에 나열한 코어 규칙 id가 코어 스킬과 같은지 확인
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"

REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd -P)"

# 백틱으로 감싼 id만 골라낸다. `(코어)` 같은 다른 백틱 값은 문자 집합이 달라 걸리지 않는다
list_backticked_ids() {
  grep -m 1 "$2" "$1" | tr ',' '\n' | sed -n 's/.*`\([a-z0-9-]\{1,\}\)`.*/\1/p'
}

test_readme_core_ids_match_skill() {
  local expected
  expected="$(sed -n 's/^## \[\([a-z0-9-]\{1,\}\)\].*/\1/p' "$PLUGIN_ROOT/skills/brownfield-navigator/SKILL.md")"
  assert_contains "$expected" "guide-stance" "코어 스킬에서 id를 읽음"
  assert_equals "$expected" "$(list_backticked_ids "$REPO_ROOT/README.md" '코어 규칙의 id는')" "한국어 README의 코어 id 목록"
  assert_equals "$expected" "$(list_backticked_ids "$REPO_ROOT/README.en.md" 'core rule ids')" "영어 README의 코어 id 목록"
}

run_test test_readme_core_ids_match_skill
finish_tests

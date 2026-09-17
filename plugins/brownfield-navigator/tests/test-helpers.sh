# 테스트 공용 도구: 단언, 테스트 실행, 픽스처 작성
# bash 3.2 호환

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd -P)"
TEST_COUNT=0
FAILED_TEST_COUNT=0
CURRENT_TEST=""
CURRENT_TEST_FAILED=0
TEST_TMP=""

fail_assertion() {
  CURRENT_TEST_FAILED=1
  printf 'FAIL %s\n     %s\n' "$CURRENT_TEST" "$1"
}

assert_equals() {
  local expected="$1" actual="$2" label="$3"
  [ "$expected" = "$actual" ] && return 0
  fail_assertion "$label
     기대: [$expected]
     실제: [$actual]"
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in
    *"$needle"*) return 0 ;;
  esac
  fail_assertion "$label
     포함되어야 함: [$needle]
     실제 출력:
$haystack"
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in
    *"$needle"*) fail_assertion "$label
     포함되면 안 됨: [$needle]
     실제 출력:
$haystack" ;;
  esac
  return 0
}

assert_empty() {
  local actual="$1" label="$2"
  [ -z "$actual" ] && return 0
  fail_assertion "$label
     비어 있어야 함, 실제 출력:
$actual"
}

# needle 이 haystack 에 정확히 expected_count 번 나오는지 확인
assert_occurrence_count() {
  local haystack="$1" needle="$2" expected_count="$3" label="$4"
  local rest="$haystack" actual_count=0
  while :; do
    case "$rest" in
      *"$needle"*)
        actual_count=$((actual_count + 1))
        rest="${rest#*"$needle"}"
        ;;
      *) break ;;
    esac
  done
  assert_equals "$expected_count" "$actual_count" "$label"
}

# first 가 second 보다 앞에 나오는지 확인
assert_order() {
  local haystack="$1" first="$2" second="$3" label="$4"
  local before_first="${haystack%%"$first"*}"
  local before_second="${haystack%%"$second"*}"
  if [ "$before_first" = "$haystack" ] || [ "$before_second" = "$haystack" ]; then
    fail_assertion "$label (둘 중 하나가 출력에 없음: [$first] [$second])"
    return 0
  fi
  [ "${#before_first}" -lt "${#before_second}" ] && return 0
  fail_assertion "$label ([$first] 가 [$second] 보다 앞에 있어야 함)"
}

# 테스트 함수 하나를 새 임시 디렉터리에서 실행
run_test() {
  CURRENT_TEST="$1"
  CURRENT_TEST_FAILED=0
  TEST_COUNT=$((TEST_COUNT + 1))
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/bn-test.XXXXXX")"
  TEST_TMP="$(cd "$TEST_TMP" && pwd -P)"
  "$1"
  rm -rf "$TEST_TMP"
  if [ "$CURRENT_TEST_FAILED" = 0 ]; then
    printf 'ok   %s\n' "$1"
  else
    FAILED_TEST_COUNT=$((FAILED_TEST_COUNT + 1))
  fi
}

finish_tests() {
  printf '\n%s: %d개 중 %d개 실패\n' "$(basename "$0")" "$TEST_COUNT" "$FAILED_TEST_COUNT"
  [ "$FAILED_TEST_COUNT" = 0 ]
}

# 인자 한 개를 한 줄로 파일에 씀 (상위 디렉터리 자동 생성)
write_lines() {
  local file_path="$1"
  shift
  mkdir -p "$(dirname "$file_path")"
  printf '%s\n' "$@" > "$file_path"
}

# origin remote가 설정된 빈 git 레포를 만듦
make_git_repo() {
  local repo_dir="$1" remote_url="$2"
  mkdir -p "$repo_dir"
  git -C "$repo_dir" init -q
  git -C "$repo_dir" remote add origin "$remote_url"
}

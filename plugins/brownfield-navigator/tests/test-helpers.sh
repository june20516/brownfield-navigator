# 테스트 공용 도구: 단언, 테스트 실행, 픽스처 작성
# bash 3.2 호환
#
# 테스트 파일은 이 파일을 source 한 뒤 run_test 로 테스트 함수를 실행하고, 마지막에 finish_tests 를 호출한다
# 출력이 비어 있어야 하는 대상은 2>&1 로 실행한다. stderr 에만 오류를 내고 끝나는 경우가 빈 출력으로 통과하지 않게 하기 위함

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd -P)"
TEST_COUNT=0
FAILED_TEST_COUNT=0
CURRENT_TEST=""
CURRENT_TEST_FAILED=0
TEST_TMP=""
TESTS_FINISHED=0

# 픽스처 git 레포가 호출 환경의 레포 지정 변수와 사용자 git 설정을 따르지 않게 격리
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null

# finish_tests 에 도달하기 전에 셸이 끝나면(테스트 안의 exit 등) 남은 테스트가 실행되지 않았으므로 실패로 종료
trap '[ "$TESTS_FINISHED" = 1 ] || { printf "FAIL finish_tests 전에 종료됨 (마지막 테스트: %s)\n" "$CURRENT_TEST"; exit 1; }' EXIT

abort_tests() {
  printf 'FAIL %s\n' "$1"
  TESTS_FINISHED=1
  exit 1
}

# 현재 테스트를 실패로 표시. 테스트 함수에서 직접 호출해도 됨
fail_assertion() {
  CURRENT_TEST_FAILED=1
  printf 'FAIL %s\n     %s\n' "$CURRENT_TEST" "$1"
}

# 찾을 문자열이 비면 어떤 출력에도 포함된 것으로 판정되므로 단언 작성 실수로 처리
reject_empty_needle() {
  local needle="$1" label="$2"
  [ -n "$needle" ] && return 0
  fail_assertion "$label (찾을 문자열이 비어 있음)"
  return 1
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
  reject_empty_needle "$needle" "$label" || return 0
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
  reject_empty_needle "$needle" "$label" || return 0
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

# needle 이 haystack 에 정확히 expected_count 번 나오는지 확인 (겹치지 않게 셈)
assert_occurrence_count() {
  local haystack="$1" needle="$2" expected_count="$3" label="$4"
  local rest="$haystack" actual_count=0
  reject_empty_needle "$needle" "$label" || return 0
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

# first 가 second 보다 앞에 나오는지 확인 (각 문자열의 첫 등장 위치를 비교)
assert_order() {
  local haystack="$1" first="$2" second="$3" label="$4"
  reject_empty_needle "$first" "$label" || return 0
  reject_empty_needle "$second" "$label" || return 0
  local before_first="${haystack%%"$first"*}"
  local before_second="${haystack%%"$second"*}"
  if [ "$before_first" = "$haystack" ] || [ "$before_second" = "$haystack" ]; then
    fail_assertion "$label (둘 중 하나가 출력에 없음: [$first] [$second])"
    return 0
  fi
  [ "${#before_first}" -lt "${#before_second}" ] && return 0
  fail_assertion "$label ([$first] 가 [$second] 보다 앞에 있어야 함)"
}

# 테스트 함수 하나를 실행하고, 새 임시 디렉터리 경로를 TEST_TMP 로 제공
# 테스트 함수는 같은 셸에서 실행되므로 cd 와 전역 변수 대입을 하지 않는다
run_test() {
  CURRENT_TEST="$1"
  CURRENT_TEST_FAILED=0
  TEST_COUNT=$((TEST_COUNT + 1))
  # mktemp 가 실패한 채 진행하면 cd "" 가 현재 디렉터리로 해석되어, 뒤의 rm -rf 가 작업 디렉터리를 지우므로 중단
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/bn-test.XXXXXX")" || abort_tests "임시 디렉터리를 만들 수 없음"
  TEST_TMP="$(cd "$TEST_TMP" && pwd -P)" || abort_tests "임시 디렉터리 경로를 확인할 수 없음"
  if declare -F "$1" >/dev/null; then
    "$1"
  else
    fail_assertion "테스트 함수가 정의되지 않음"
  fi
  case "$TEST_TMP" in
    */bn-test.*) rm -rf "$TEST_TMP" ;;
  esac
  if [ "$CURRENT_TEST_FAILED" = 0 ]; then
    printf 'ok   %s\n' "$1"
  else
    FAILED_TEST_COUNT=$((FAILED_TEST_COUNT + 1))
  fi
}

finish_tests() {
  TESTS_FINISHED=1
  printf '\n%s: %d개 중 %d개 실패\n' "$(basename "$0")" "$TEST_COUNT" "$FAILED_TEST_COUNT"
  [ "$FAILED_TEST_COUNT" = 0 ]
}

# 인자 한 개를 한 줄로 파일에 씀 (상위 디렉터리 자동 생성). 인자가 없으면 빈 줄 하나를 쓰므로 빈 파일은 ": > 파일" 로 만든다
write_lines() {
  local file_path="$1"
  shift
  mkdir -p "$(dirname "$file_path")"
  printf '%s\n' "$@" > "$file_path"
}

# origin remote 가 설정된 빈 git 레포를 만듦
make_git_repo() {
  local repo_dir="$1" remote_url="$2"
  mkdir -p "$repo_dir"
  git -C "$repo_dir" init -q || fail_assertion "픽스처 git 레포 생성 실패: $repo_dir"
  git -C "$repo_dir" remote add origin "$remote_url" || fail_assertion "픽스처 remote 설정 실패: $repo_dir"
}

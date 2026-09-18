# Brownfield Navigator Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 조직, 개인, 프로젝트 프로필을 병합해 세션 시작 때 레거시 작업 가이드로 주입하는 Claude Code 플러그인 `brownfield-navigator`를 만들고, 첫 사용자(bran) 프로필을 작성해 실제 레포에서 검증한다.

**Architecture:** 매칭과 병합은 bash 스크립트 `bin/compose-guide`가 담당하고, 파싱, 매칭, 섹션 병합 함수는 `lib/`에 나눈다. SessionStart 훅과 코어 스킬이 같은 `compose-guide`를 호출한다. 규칙은 `## [id] 제목` 섹션 단위로 코어, 조직, 개인, 프로젝트 순으로 병합하며, 사용자 프로필은 플러그인 바깥 `~/.claude/brownfield-navigator/`에 둔다.

**Tech Stack:** bash 3.2 호환 셸 스크립트, awk/sed/grep (BSD와 GNU 공통 옵션), Claude Code 플러그인 (hooks, skills, marketplace), python3 (테스트의 JSON 검증에만 사용)

**Spec:** `docs/suberpowers/specs/2026-09-17-brownfield-navigator-design.md`

---

## 공통 사항

- 모든 명령은 레포 루트 `~/personal/brownfield-navigator`에서 실행한다
- 스크립트와 테스트는 bash 3.2에서 동작해야 한다. 연관 배열(`declare -A`), `mapfile`, `${var,,}`를 쓰지 않고, 픽스처는 heredoc 대신 `printf`로 만든다
- macOS의 `bash`는 `/bin/bash` 3.2다. 테스트는 `bash plugins/brownfield-navigator/tests/<이름>.test.sh`, 전체는 `bash plugins/brownfield-navigator/tests/run-all.sh`로 실행한다
- 파일 내용은 이 계획의 코드 블록과 **정확히 같게** 쓴다. 모든 코드 블록은 스크래치 시제품에서 bash 3.2로 전체 테스트(53개)와 `claude plugin validate` 통과를 확인한 내용이다
- 이 레포는 개인 레포이므로 커밋 메시지는 `type: 한국어 설명` 형식에 attribution trailer 두 줄을 붙인다. 각 Task의 Commit step에 들어 있는 trailer는 계획 작성 세션 기준이므로, 실행 세션의 attribution 안내가 다르면 그 안내를 따른다
- 테스트가 실패하면 코드 블록과 파일이 같은지부터 확인한다 (`diff`)

## 파일 구조

| 파일 | 책임 |
|---|---|
| `.claude-plugin/marketplace.json` | 레포를 마켓플레이스로 등록 |
| `README.md` | 설치, 처음 설정, 프로필 형식, 수동 호출, 주의 사항 (한국어) |
| `README.en.md` | `README.md`의 영어판 |
| `.gitattributes` | bash가 읽는 파일과 마크다운의 LF 줄바꿈 고정 |
| `plugins/brownfield-navigator/.claude-plugin/plugin.json` | 플러그인 매니페스트 |
| `plugins/brownfield-navigator/lib/profile.sh` | 조직·프로젝트 파일 frontmatter 파싱, 참고 파일 description 추출 |
| `plugins/brownfield-navigator/lib/match.sh` | remote URL 정규화, 경로(상위 디렉터리 포함)와 remote 매칭, 매칭 근거 출력 |
| `plugins/brownfield-navigator/lib/sections.sh` | `## [id]` 섹션 추출, 층 병합(같은 id 제자리 교체), 출처 표기 출력 |
| `plugins/brownfield-navigator/bin/compose-guide` | 대상 디렉터리에 맞는 조직·프로젝트를 찾아 가이드 텍스트 출력 (`--manual` 지원) |
| `plugins/brownfield-navigator/hooks/hooks.json` | SessionStart 훅 등록 |
| `plugins/brownfield-navigator/hooks/run-hook.cmd` | Windows와 Unix 공용 훅 실행 래퍼 (suberpower와 같은 파일) |
| `plugins/brownfield-navigator/hooks/session-start` | 훅 입력에서 cwd를 얻어 compose-guide 출력을 JSON으로 감싸 주입 |
| `plugins/brownfield-navigator/skills/brownfield-navigator/SKILL.md` | 코어 규칙 16개와 수동 호출 절차 |
| `plugins/brownfield-navigator/skills/harvest-profile/SKILL.md` | 프로젝트 메모리를 모아 프로필 초안을 만드는 절차 |
| `plugins/brownfield-navigator/templates/*.md` | 조직, 개인, 프로젝트, 참고 파일 템플릿 |
| `plugins/brownfield-navigator/tests/test-helpers.sh` | 단언, 테스트 실행, 픽스처 작성 도구 |
| `plugins/brownfield-navigator/tests/run-all.sh` | 전체 테스트 실행 |
| `plugins/brownfield-navigator/tests/*.test.sh` | lib, compose-guide, 훅, 템플릿, README 테스트 |

spec과 달라진 점: 플러그인 스킬은 `/<플러그인>:<스킬>`로 호출되므로 안내문과 문서의 호출 이름을 `/brownfield-navigator:brownfield-navigator`, `/brownfield-navigator:harvest-profile`로 쓴다 (spec에도 반영됨).

---

### Task 1: 마켓플레이스와 플러그인 매니페스트

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/brownfield-navigator/.claude-plugin/plugin.json`

- [ ] **Step 1: 마켓플레이스 매니페스트 작성**

`.claude-plugin/marketplace.json`

````json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "brownfield-navigator",
  "description": "레거시 코드베이스에서 회사 컨벤션과 기존 흐름을 따르는 작업 가이드 플러그인",
  "owner": {
    "name": "june20516"
  },
  "plugins": [
    {
      "name": "brownfield-navigator",
      "source": "./plugins/brownfield-navigator",
      "description": "레거시 코드베이스에서 회사 컨벤션과 기존 코드의 흐름을 따르는 작업 가이드. 조직, 개인, 프로젝트 프로필을 세션 시작 때 병합해 주입한다",
      "version": "0.1.0",
      "author": {
        "name": "june20516"
      },
      "category": "development",
      "homepage": "https://github.com/june20516/brownfield-navigator"
    }
  ]
}
````

- [ ] **Step 2: 플러그인 매니페스트 작성**

`plugins/brownfield-navigator/.claude-plugin/plugin.json`

````json
{
  "name": "brownfield-navigator",
  "description": "레거시 코드베이스에서 회사 컨벤션과 기존 코드의 흐름을 따르는 작업 가이드. 조직, 개인, 프로젝트 프로필을 세션 시작 때 병합해 주입한다",
  "version": "0.1.0",
  "author": {
    "name": "june20516"
  },
  "homepage": "https://github.com/june20516/brownfield-navigator",
  "repository": "https://github.com/june20516/brownfield-navigator",
  "keywords": [
    "brownfield",
    "legacy",
    "conventions",
    "skills",
    "hooks",
    "korean"
  ]
}
````

- [ ] **Step 3: 매니페스트 검증**

실행: `claude plugin validate . && claude plugin validate plugins/brownfield-navigator`
기대: 두 번 모두 `✔ Validation passed`

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json plugins/brownfield-navigator/.claude-plugin/plugin.json
git commit -F - <<'EOF'
chore: 마켓플레이스와 플러그인 매니페스트 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 2: 테스트 도구

**Files:**
- Create: `plugins/brownfield-navigator/tests/test-helpers.sh`
- Create: `plugins/brownfield-navigator/tests/run-all.sh`

- [ ] **Step 1: 테스트 공용 도구 작성**

`plugins/brownfield-navigator/tests/test-helpers.sh`

````bash
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
````

- [ ] **Step 2: 전체 실행 스크립트 작성**

`plugins/brownfield-navigator/tests/run-all.sh`

````bash
#!/usr/bin/env bash
# 모든 테스트 파일을 실행. 하나라도 실패하면 종료 코드 1
# 사용법: bash plugins/brownfield-navigator/tests/run-all.sh
# 첫 줄에 실행한 bash 버전을 출력. macOS 에서는 /bin/bash(3.2)로 실행해야 3.2 호환을 확인할 수 있음

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)"
test_file_count=0
failed_files=""

printf 'bash %s (%s)\n\n' "$BASH_VERSION" "$BASH"
for test_file in "$TESTS_DIR"/*.test.sh; do
  [ -f "$test_file" ] || continue
  test_file_count=$((test_file_count + 1))
  "$BASH" "$test_file" || failed_files="$failed_files $(basename "$test_file")"
  printf '\n'
done

if [ "$test_file_count" = 0 ]; then
  printf '테스트 파일 없음\n'
elif [ -z "$failed_files" ]; then
  printf '테스트 파일 %d개 모두 통과\n' "$test_file_count"
else
  printf '실패한 테스트 파일:%s\n' "$failed_files"
  exit 1
fi
````

- [ ] **Step 3: 실행 권한 부여와 빈 실행 확인**

실행: `chmod +x plugins/brownfield-navigator/tests/run-all.sh && bash plugins/brownfield-navigator/tests/run-all.sh; echo "exit=$?"`
기대: 아래 출력. 첫 줄은 실행한 bash 버전이며 macOS 기본 bash 기준

```
bash 3.2.57(1)-release (/bin/bash)

테스트 파일 없음
exit=0
```

- [ ] **Step 4: Commit**

```bash
git add plugins/brownfield-navigator/tests/test-helpers.sh plugins/brownfield-navigator/tests/run-all.sh
git commit -F - <<'EOF'
test: bash 3.2 호환 테스트 도구 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 3: frontmatter 파싱 (`lib/profile.sh`)

**Files:**
- Create: `plugins/brownfield-navigator/lib/profile.sh`
- Test: `plugins/brownfield-navigator/tests/profile.test.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/brownfield-navigator/tests/profile.test.sh`

````bash
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
    "  - '*acme-legacy/*'" \
    "match-paths:" \
    "- ~/work/acme" \
    '  - "~/work/acme #1/*"  # 따옴표 안의 #은 값' \
    "---" \
    "apply: always" \
    "## [rule] 본문"
  local parsed
  parsed="$(parse_profile_frontmatter "$TEST_TMP/profile.md")"
  assert_equals "apply=suggest
remote=*acme/*
remote=*acme-mirror/*
remote=*acme-legacy/*
path=~/work/acme
path=~/work/acme #1/*" "$parsed" "apply와 블록 리스트 항목을 따옴표, 주석 없이 출력하고 닫는 --- 뒤 본문은 읽지 않음"
}

test_accepts_empty_list_comments_and_spaced_keys() {
  write_lines "$TEST_TMP/profile.md" \
    "---" \
    "# 매칭 조건" \
    "" \
    "apply : off" \
    "match-remotes: []" \
    "match-paths :  # 경로 목록" \
    '  - "~/work/*"' \
    "  - # 나중에 추가" \
    "---"
  write_lines "$TEST_TMP/quoted-apply.md" "---" "apply: 'suggest'" "---"
  assert_equals "apply=off
path=~/work/*" "$(parse_profile_frontmatter "$TEST_TMP/profile.md")" "빈 리스트, 주석 줄, 키 뒤 주석, 주석만 있는 항목, 콜론 앞 공백 처리"
  assert_equals "apply=suggest" "$(parse_profile_frontmatter "$TEST_TMP/quoted-apply.md")" "따옴표로 감싼 apply 값"
}

test_fails_without_frontmatter() {
  write_lines "$TEST_TMP/profile.md" "## [rule] 본문"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/profile.md")" "error=frontmatter 없음" "첫 줄이 --- 가 아니면 실패"
}

test_fails_on_empty_file() {
  : > "$TEST_TMP/profile.md"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/profile.md")" "error=frontmatter 없음" "빈 파일은 실패"
}

test_fails_when_file_unreadable() {
  mkdir -p "$TEST_TMP/directory.md"
  assert_equals "error=파일을 읽을 수 없음" "$(parse_profile_frontmatter "$TEST_TMP/missing.md" 2>&1)" "없는 파일은 실패"
  assert_equals "error=파일을 읽을 수 없음" "$(parse_profile_frontmatter "$TEST_TMP/directory.md" 2>&1)" "디렉터리는 실패"
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

test_fails_on_stray_or_unparseable_lines() {
  write_lines "$TEST_TMP/stray-item.md" "---" "apply: auto" "  - stray" "---"
  write_lines "$TEST_TMP/nested-under-list.md" "---" "match-paths:" "  - ~/a" "    extra: x" "---"
  write_lines "$TEST_TMP/unclosed-quote.md" "---" "match-remotes:" '  - "*acme/*' "---"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/stray-item.md")" "error=어느 키의 리스트 항목인지 알 수 없음" "리스트 키가 아닌 키 뒤의 항목은 실패"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/nested-under-list.md")" "error=해석할 수 없는 줄" "리스트 항목 아래 들여쓴 키는 실패"
  assert_contains "$(parse_profile_frontmatter "$TEST_TMP/unclosed-quote.md")" "error=따옴표가 닫히지 않음" "닫히지 않은 따옴표는 실패"
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
    "- flat" \
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
  write_lines "$TEST_TMP/spaced.md" "---" "title: 규약" "description : '웹뷰 규약'" "---"
  assert_equals "레포 지도" "$(read_reference_description "$TEST_TMP/ref.md")" "description 값 추출"
  assert_equals "웹뷰 규약" "$(read_reference_description "$TEST_TMP/spaced.md")" "콜론 앞 공백과 작은따옴표 처리"
}

test_reference_description_only_from_frontmatter() {
  write_lines "$TEST_TMP/body-only.md" "---" "title: x" "---" "description: 본문 안 문장"
  write_lines "$TEST_TMP/no-frontmatter.md" "# 제목" "description: 본문 안 문장"
  assert_empty "$(read_reference_description "$TEST_TMP/body-only.md" 2>&1)" "frontmatter에 없고 본문에만 있으면 빈 출력"
  assert_empty "$(read_reference_description "$TEST_TMP/no-frontmatter.md" 2>&1)" "frontmatter가 없으면 빈 출력"
  assert_empty "$(read_reference_description "$TEST_TMP/missing.md" 2>&1)" "없는 파일은 빈 출력"
}

run_test test_parses_apply_and_block_lists
run_test test_accepts_empty_list_comments_and_spaced_keys
run_test test_fails_without_frontmatter
run_test test_fails_on_empty_file
run_test test_fails_when_file_unreadable
run_test test_fails_without_closing_delimiter
run_test test_fails_on_invalid_apply
run_test test_fails_on_flow_list
run_test test_fails_on_stray_or_unparseable_lines
run_test test_warns_on_unsupported_key
run_test test_ignores_nested_values_of_unsupported_keys
run_test test_fails_on_list_key_without_items
run_test test_reads_reference_description
run_test test_reference_description_only_from_frontmatter
finish_tests
````

- [ ] **Step 2: 테스트를 실행해 실패 확인**

실행: `bash plugins/brownfield-navigator/tests/profile.test.sh; echo "exit=$?"`
기대: `lib/profile.sh: No such file or directory`, 마지막 줄 `profile.test.sh: 14개 중 14개 실패`, `exit=1`

- [ ] **Step 3: 구현 작성**

`plugins/brownfield-navigator/lib/profile.sh`

````bash
# 프로필 파일 읽기: frontmatter 파싱, 참고 파일 description 추출
# bash 3.2 호환

# 조직 프로필과 프로젝트 파일의 frontmatter를 한 줄에 하나씩 출력
#   apply=<auto|suggest|off>
#   remote=<패턴>
#   path=<패턴>
#   warning=<메시지>  파일은 계속 사용
#   error=<메시지>    파싱 실패. 많아야 한 줄이고 항상 마지막 줄이며, 있으면 앞선 줄도 모두 버린다
# 종료 코드는 항상 0
parse_profile_frontmatter() {
  local profile_file="$1"
  if [ ! -f "$profile_file" ] || [ ! -r "$profile_file" ]; then
    printf 'error=파일을 읽을 수 없음\n'
    return 0
  fi
  awk -v squote="'" '
    function trim(text) {
      sub(/^[[:space:]]+/, "", text)
      sub(/[[:space:]]+$/, "", text)
      return text
    }
    function fail(message) {
      print "error=" message
      failed = 1
      exit
    }
    # 값을 읽음. 따옴표로 시작하면 닫는 따옴표까지가 값이고 그 뒤에는 주석만 올 수 있음. 아니면 " #" 뒤가 주석
    function read_value(text,    quote, closing_position, rest) {
      if (text ~ /^[[:space:]]+#/) return ""
      text = trim(text)
      quote = substr(text, 1, 1)
      if (quote == "\"" || quote == squote) {
        closing_position = index(substr(text, 2), quote)
        if (closing_position == 0) fail("따옴표가 닫히지 않음: " text)
        rest = substr(text, closing_position + 2)
        if (rest !~ /^([[:space:]]+#.*)?[[:space:]]*$/) fail("따옴표 뒤에 알 수 없는 내용: " text)
        return substr(text, 2, closing_position - 1)
      }
      sub(/[[:space:]]+#.*$/, "", text)
      return text
    }
    # 값을 비워 둔 리스트 키에 블록 항목이 하나도 없으면 실패 (빈 리스트는 [] 로 적어야 함)
    function close_list() {
      if (list_key != "" && list_item_count == 0) fail(list_key " 에 항목이 없음 (빈 리스트는 [] 로 적음)")
      list_key = ""
      list_output_name = ""
      list_item_count = 0
    }
    NR == 1 {
      if ($0 != "---") fail("frontmatter 없음 (첫 줄이 ---가 아님)")
      next
    }
    # 닫는 --- 를 만나거나 실패하면 곧바로 끝나므로, 2행부터 여기에 오는 줄은 모두 frontmatter 안
    {
      if ($0 == "---") { close_list(); closed = 1; exit }
      if ($0 ~ /^[[:space:]]*(#.*)?$/) next
      # 지원하지 않는 키 아래의 값(들여쓴 줄, "- " 항목)은 그 키와 함께 무시
      if (ignoring_unsupported_key && $0 ~ /^([[:space:]]|-[[:space:]])/) next
      if ($0 ~ /^[[:space:]]*-[[:space:]]/) {
        if (list_key == "") fail("어느 키의 리스트 항목인지 알 수 없음: " trim($0))
        list_item_count++
        item = $0
        sub(/^[[:space:]]*-/, "", item)
        item = read_value(item)
        if (item != "") print list_output_name "=" item
        next
      }
      # 들여쓰지 않았고 - 나 # 로 시작하지 않는 "이름:" 줄을 키로 봄 (한글, 점, 따옴표가 들어간 키도 경고 대상)
      if (match($0, /^[^[:space:]#-][^:]*:/)) {
        key = trim(substr($0, 1, RLENGTH - 1))
        raw_value = substr($0, RLENGTH + 1)
        close_list()
        ignoring_unsupported_key = 0
        if (key == "apply") {
          value = read_value(raw_value)
          if (value !~ /^(auto|suggest|off)$/) fail("apply 값은 auto, suggest, off 중 하나여야 함: " value)
          print "apply=" value
        } else if (key == "match-remotes" || key == "match-paths") {
          value = read_value(raw_value)
          if (value == "") {
            list_key = key
            list_output_name = (key == "match-remotes") ? "remote" : "path"
          } else if (value != "[]") {
            fail(key " 는 블록 리스트만 지원함: " value)
          }
        } else {
          print "warning=지원하지 않는 키 무시: " key
          ignoring_unsupported_key = 1
        }
        next
      }
      fail("해석할 수 없는 줄: " trim($0))
    }
    END {
      if (failed || closed) exit
      if (NR == 0) print "error=frontmatter 없음 (빈 파일)"
      else print "error=닫는 --- 없음"
    }
  ' "$profile_file"
}

# 참고 파일 frontmatter의 description 값을 출력 (frontmatter에 없거나 파일을 읽을 수 없으면 빈 출력)
read_reference_description() {
  local reference_file="$1"
  [ -f "$reference_file" ] && [ -r "$reference_file" ] || return 0
  awk -v squote="'" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    match($0, /^description[[:space:]]*:/) {
      value = substr($0, RLENGTH + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      first_character = substr(value, 1, 1)
      if (length(value) >= 2 && (first_character == "\"" || first_character == squote) && substr(value, length(value), 1) == first_character) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit
    }
  ' "$reference_file"
}
````

- [ ] **Step 4: 테스트를 실행해 통과 확인**

실행: `bash plugins/brownfield-navigator/tests/profile.test.sh; echo "exit=$?"`
기대: `ok` 14줄, `profile.test.sh: 14개 중 0개 실패`, `exit=0`

- [ ] **Step 5: Commit**

```bash
git add plugins/brownfield-navigator/lib/profile.sh plugins/brownfield-navigator/tests/profile.test.sh
git commit -F - <<'EOF'
feat: 프로필 frontmatter 파싱 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 4: 매칭 (`lib/match.sh`)

**Files:**
- Create: `plugins/brownfield-navigator/lib/match.sh`
- Test: `plugins/brownfield-navigator/tests/match.test.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/brownfield-navigator/tests/match.test.sh`

````bash
# lib/match.sh 테스트
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"
. "$PLUGIN_ROOT/lib/match.sh"

test_normalizes_remote_url() {
  assert_equals "git@github.com:acme/app" "$(normalize_remote_url "git@github.com:acme/app.git")" ".git 제거"
  assert_equals "https://github.com/acme/app" "$(normalize_remote_url "https://github.com/acme/app/")" "끝 / 제거"
  assert_equals "https://github.com/acme/app" "$(normalize_remote_url "https://github.com/acme/app.git/")" ".git/ 제거"
  assert_equals "https://github.com/acme/app" "$(normalize_remote_url "https://user:secret-token@github.com/acme/app.git")" "URL의 인증 정보 제거"
  assert_equals "ssh://github.com/acme/app" "$(normalize_remote_url "ssh://git@github.com/acme/app.git")" "ssh URL의 사용자 제거"
  assert_equals "https://github.com/acme/app@v1" "$(normalize_remote_url "https://github.com/acme/app@v1")" "경로의 @ 는 유지"
}

test_lists_normalized_remotes() {
  make_git_repo "$TEST_TMP/repo" "git@github.com:acme/app.git"
  git -C "$TEST_TMP/repo" remote add mirror "https://github.com/acme/app"
  assert_equals "git@github.com:acme/app
https://github.com/acme/app" "$(list_remote_urls "$TEST_TMP/repo")" "모든 remote를 정규화해 출력"
}

test_lists_nothing_outside_git() {
  mkdir -p "$TEST_TMP/plain"
  assert_empty "$(list_remote_urls "$TEST_TMP/plain" 2>&1)" "git 레포가 아니면 빈 출력"
}

test_expands_home_prefix() {
  assert_equals "$HOME/work/*" "$(expand_home_prefix "~/work/*")" "~/ 확장"
  assert_equals "$HOME" "$(expand_home_prefix "~")" "~ 단독 확장"
  assert_equals "/opt/*" "$(expand_home_prefix "/opt/*")" "~ 없으면 그대로"
}

test_path_matches_self_and_ancestors() {
  path_or_ancestor_matches "/work/acme/app" "/work/acme/app" || fail_assertion "자기 자신과 일치"
  path_or_ancestor_matches "/work/acme/app/src/deep" "/work/acme/app" || fail_assertion "하위 디렉터리에서 상위 경로와 일치"
  path_or_ancestor_matches "/work/acme/app" "/work/acme/*" || fail_assertion "글롭이 레포 디렉터리와 일치"
  if path_or_ancestor_matches "/work/acme" "/work/acme/*"; then fail_assertion "상위 디렉터리 자체는 /* 글롭과 불일치"; fi
  if path_or_ancestor_matches "/work/other/app" "/work/acme/*"; then fail_assertion "다른 경로는 불일치"; fi
}

test_match_reason_by_remote() {
  printf '%s\n' "path=/nowhere" "remote=*acme/*" > "$TEST_TMP/parsed"
  printf '%s\n' "git@github.com:acme/app" > "$TEST_TMP/remotes"
  assert_equals "remote git@github.com:acme/app" \
    "$(print_match_reason "$TEST_TMP/parsed" "$TEST_TMP/remotes" "$TEST_TMP")" "remote 조건 근거 출력"
}

test_match_reason_by_path() {
  mkdir -p "$TEST_TMP/work/app/src"
  printf '%s\n' "path=$TEST_TMP/work/*" > "$TEST_TMP/parsed"
  : > "$TEST_TMP/remotes"
  assert_equals "path $TEST_TMP/work/*" \
    "$(print_match_reason "$TEST_TMP/parsed" "$TEST_TMP/remotes" "$TEST_TMP/work/app/src")" "경로 조건 근거 출력"
}

test_no_match_returns_failure() {
  printf '%s\n' "remote=*acme/*" > "$TEST_TMP/parsed"
  printf '%s\n' "git@github.com:other/app" > "$TEST_TMP/remotes"
  print_match_reason "$TEST_TMP/parsed" "$TEST_TMP/remotes" "$TEST_TMP" >/dev/null 2>&1
  assert_equals 1 "$?" "조건이 맞지 않으면 종료 코드 1"
}

run_test test_normalizes_remote_url
run_test test_lists_normalized_remotes
run_test test_lists_nothing_outside_git
run_test test_expands_home_prefix
run_test test_path_matches_self_and_ancestors
run_test test_match_reason_by_remote
run_test test_match_reason_by_path
run_test test_no_match_returns_failure
finish_tests
````

- [ ] **Step 2: 테스트를 실행해 실패 확인**

실행: `bash plugins/brownfield-navigator/tests/match.test.sh; echo "exit=$?"`
기대: `lib/match.sh: No such file or directory`, 마지막 줄 `match.test.sh: 8개 중 8개 실패`, `exit=1`

- [ ] **Step 3: 구현 작성**

`plugins/brownfield-navigator/lib/match.sh`

````bash
# 대상 디렉터리와 프로필 매칭 조건 비교
# bash 3.2 호환

# remote URL을 비교할 수 있는 형태로 만듦
#   끝의 / 와 .git 제거
#   https://user:token@host 형식의 인증 정보 제거 (가이드와 세션 컨텍스트에 토큰이 들어가지 않게)
normalize_remote_url() {
  local url="$1" scheme address host_part path_part
  url="${url%/}"
  url="${url%.git}"
  case "$url" in
    *://*)
      scheme="${url%%://*}"
      address="${url#*://}"
      host_part="${address%%/*}"
      path_part="${address#"$host_part"}"
      url="$scheme://${host_part##*@}$path_part"
      ;;
  esac
  printf '%s\n' "$url"
}

# 대상 디렉터리의 git remote URL을 정규화해 한 줄에 하나씩 출력 (git이 없거나 레포가 아니면 빈 출력)
list_remote_urls() {
  local target_dir="$1" url
  command -v git >/dev/null 2>&1 || return 0
  git -C "$target_dir" remote -v 2>/dev/null | awk '{ print $2 }' | sort -u |
    while IFS= read -r url; do
      normalize_remote_url "$url"
    done
}

# 패턴 앞머리의 ~ 를 홈 경로로 바꿈
expand_home_prefix() {
  local pattern="$1"
  case "$pattern" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${pattern#"~/"}" ;;
    *) printf '%s\n' "$pattern" ;;
  esac
}

# 대상 경로 또는 그 상위 디렉터리 중 하나가 패턴과 일치하면 성공
path_or_ancestor_matches() {
  local candidate="$1" pattern="$2"
  while :; do
    [[ "$candidate" == $pattern ]] && return 0
    [ "$candidate" = "/" ] && return 1
    candidate="$(dirname "$candidate")"
  done
}

# 파싱 결과의 remote, path 조건으로 매칭을 판정하고 매칭되면 근거를 출력
#   $1 파싱 결과 파일  $2 remote URL 목록 파일  $3 대상 디렉터리
print_match_reason() {
  local parsed_file="$1" remotes_file="$2" target_dir="$3"
  local kind pattern remote_url
  while IFS='=' read -r kind pattern; do
    case "$kind" in
      remote)
        while IFS= read -r remote_url; do
          if [[ "$remote_url" == $pattern ]]; then
            printf 'remote %s\n' "$remote_url"
            return 0
          fi
        done < "$remotes_file"
        ;;
      path)
        if path_or_ancestor_matches "$target_dir" "$(expand_home_prefix "$pattern")"; then
          printf 'path %s\n' "$pattern"
          return 0
        fi
        ;;
    esac
  done < "$parsed_file"
  return 1
}
````

- [ ] **Step 4: 테스트를 실행해 통과 확인**

실행: `bash plugins/brownfield-navigator/tests/match.test.sh; echo "exit=$?"`
기대: `match.test.sh: 8개 중 0개 실패`, `exit=0`

- [ ] **Step 5: Commit**

```bash
git add plugins/brownfield-navigator/lib/match.sh plugins/brownfield-navigator/tests/match.test.sh
git commit -F - <<'EOF'
feat: remote와 경로 조건 매칭 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 5: 규칙 섹션 병합 (`lib/sections.sh`)

**Files:**
- Create: `plugins/brownfield-navigator/lib/sections.sh`
- Test: `plugins/brownfield-navigator/tests/sections.test.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/brownfield-navigator/tests/sections.test.sh`

````bash
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
run_test test_merges_layers_in_place
run_test test_prints_heading_without_title
run_test test_prints_first_paragraph_for_summary_source
finish_tests
````

- [ ] **Step 2: 테스트를 실행해 실패 확인**

실행: `bash plugins/brownfield-navigator/tests/sections.test.sh; echo "exit=$?"`
기대: `lib/sections.sh: No such file or directory`, 마지막 줄 `sections.test.sh: 4개 중 4개 실패`, `exit=1`

- [ ] **Step 3: 구현 작성**

`plugins/brownfield-navigator/lib/sections.sh`

````bash
# 규칙 섹션(## [id] 제목) 추출, 층 병합, 출력
# bash 3.2 호환 (연관 배열 대신 id별 파일 사용)

# 마크다운 파일의 ## [id] 섹션을 id별 파일로 나눔
#   <출력 디렉터리>/ids          등장 순서대로 id 목록
#   <출력 디렉터리>/<id>.title   헤딩의 제목 부분
#   <출력 디렉터리>/<id>.body    헤딩 다음 줄부터 다음 ## 헤딩 전까지
# frontmatter, id 없는 ## 섹션, 첫 ## 헤딩 이전 내용은 건너뜀
# 코드 블록 안의 ## 줄은 헤딩으로 보지 않음
extract_rule_sections() {
  local markdown_file="$1" output_dir="$2"
  mkdir -p "$output_dir"
  : > "$output_dir/ids"
  awk -v output_dir="$output_dir" '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter { if ($0 == "---") in_frontmatter = 0; next }
    /^[[:space:]]*```/ { in_code_block = !in_code_block }
    !in_code_block && /^## / {
      if (body_file != "") close(body_file)
      body_file = ""
      if (match($0, /^## \[[a-z0-9-]+\]/)) {
        section_id = substr($0, 5, RLENGTH - 5)
        title = substr($0, RLENGTH + 1)
        sub(/^[[:space:]]+/, "", title)
        title_file = output_dir "/" section_id ".title"
        print title > title_file
        close(title_file)
        body_file = output_dir "/" section_id ".body"
        printf "" > body_file
        close(body_file)
        if (!(section_id in seen)) {
          seen[section_id] = 1
          print section_id >> (output_dir "/ids")
        }
      }
      next
    }
    body_file != "" { print >> body_file }
  ' "$markdown_file"
}

# 한 층의 섹션을 병합 결과에 반영. 같은 id는 제자리에서 교체하고 새 id는 끝에 추가
#   $1 층 디렉터리 (extract_rule_sections 결과)  $2 출처 표기  $3 병합 디렉터리
merge_rule_layer() {
  local layer_dir="$1" source_label="$2" merged_dir="$3" section_id
  mkdir -p "$merged_dir"
  touch "$merged_dir/order"
  while IFS= read -r section_id; do
    grep -qx -- "$section_id" "$merged_dir/order" || printf '%s\n' "$section_id" >> "$merged_dir/order"
    cp "$layer_dir/$section_id.title" "$merged_dir/$section_id.title"
    cp "$layer_dir/$section_id.body" "$merged_dir/$section_id.body"
    printf '%s\n' "$source_label" > "$merged_dir/$section_id.source"
  done < "$layer_dir/ids"
}

# 병합 결과를 병합 순서대로 출력. 헤딩 끝에 최종 출처를 붙임
# summary_source 를 주면 최종 출처가 그 값인 섹션은 본문의 첫 문단만 출력
print_merged_sections() {
  local merged_dir="$1" summary_source="${2:-}" section_id title source_label
  [ -f "$merged_dir/order" ] || return 0
  while IFS= read -r section_id; do
    title="$(cat "$merged_dir/$section_id.title")"
    source_label="$(cat "$merged_dir/$section_id.source")"
    if [ -n "$title" ]; then
      printf '## [%s] %s (%s)\n' "$section_id" "$title" "$source_label"
    else
      printf '## [%s] (%s)\n' "$section_id" "$source_label"
    fi
    if [ -n "$summary_source" ] && [ "$source_label" = "$summary_source" ]; then
      print_first_paragraph "$merged_dir/$section_id.body"
    else
      print_without_trailing_blank_lines "$merged_dir/$section_id.body"
    fi
    printf '\n'
  done < "$merged_dir/order"
}

# 앞쪽 빈 줄을 건너뛰고 첫 문단(다음 빈 줄 전까지)만 출력
print_first_paragraph() {
  awk '
    /^[[:space:]]*$/ { if (started) exit; next }
    { started = 1; print }
  ' "$1"
}

print_without_trailing_blank_lines() {
  awk '
    { lines[NR] = $0 }
    END {
      last = NR
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
      for (i = 1; i <= last; i++) print lines[i]
    }
  ' "$1"
}
````

- [ ] **Step 4: 테스트를 실행해 통과 확인**

실행: `bash plugins/brownfield-navigator/tests/sections.test.sh; echo "exit=$?"`
기대: `sections.test.sh: 4개 중 0개 실패`, `exit=0`

- [ ] **Step 5: Commit**

```bash
git add plugins/brownfield-navigator/lib/sections.sh plugins/brownfield-navigator/tests/sections.test.sh
git commit -F - <<'EOF'
feat: 규칙 섹션 추출과 층 병합 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 6: 코어 스킬 (`skills/brownfield-navigator/SKILL.md`)

Task 7의 compose-guide 테스트가 이 파일의 실제 코어 규칙(`guide-stance`, `comment-density`, `preserve-vs-decide`, `team-boundary`)을 기준으로 검증하므로 먼저 작성한다.

**Files:**
- Create: `plugins/brownfield-navigator/skills/brownfield-navigator/SKILL.md`

- [ ] **Step 1: 코어 스킬 작성**

`plugins/brownfield-navigator/skills/brownfield-navigator/SKILL.md`

````markdown
---
name: brownfield-navigator
description: "회사 레포에서 조직 컨벤션과 기존 코드의 흐름을 따르는 brownfield-navigator 가이드를 불러온다. 사용자가 이 가이드나 회사 컨벤션 적용을 요청할 때, 또는 세션을 시작한 디렉터리가 아닌 다른 레포에서 작업하는데 컨텍스트에 그 레포 기준의 brownfield-navigator 가이드가 없을 때 사용한다."
argument-hint: "[레포 경로 또는 이름]"
---

# Brownfield Navigator

## 이 스킬이 하는 일

기존 코드 위에서 기능을 넓히거나 유지보수할 때, 그 코드베이스와 조직이 이미 쌓아 온 방식을 따르도록 돕는 가이드다. 규칙은 네 층으로 나뉜다.

| 층 | 내용 | 위치 |
|---|---|---|
| 코어 | 회사와 도구에 무관한 레거시 작업 원칙 | 이 파일의 `## [id]` 섹션 |
| 조직 | 회사 컨벤션 | `~/.claude/brownfield-navigator/orgs/<조직>/profile.md` |
| 개인 | Claude와 일하는 방식에 대한 개인 선호 | `~/.claude/brownfield-navigator/personal.md` |
| 프로젝트 | 특정 레포에서만 달라지는 규칙 | `~/.claude/brownfield-navigator/orgs/<조직>/projects/<이름>.md` |

같은 id의 규칙은 코어, 조직, 개인, 프로젝트 순으로 뒤의 층이 대체한다. 세션 시작 훅이 작업 디렉터리에 맞는 프로필을 찾아 병합한 가이드를 주입한다.

강제 장치가 아니라 가이드다. 사용자의 현재 지시, CLAUDE.md, 프로젝트 메모리가 가이드보다 우선한다.

## 호출되었을 때

1. 작업 대상 경로를 정한다. 사용자가 경로를 말했으면 그 경로, 레포 이름만 말했으면 그 이름으로 찾은 경로, 아니면 현재 작업 디렉터리다
2. 세션 컨텍스트에 `# brownfield-navigator 가이드`로 시작하는 병합된 가이드가 이미 있고 머리말의 `- 대상:` 경로가 작업 대상과 같은 레포면 추가로 할 일은 없다. 그 가이드대로 작업을 계속한다. 매칭 근거 줄은 경로 패턴이면 여러 레포에 함께 맞으므로 이 판단에 쓰지 않는다. 가이드가 길어 앞부분만 보이고 저장된 파일 경로가 함께 표시되어 있으면 그 파일을 Read한 뒤 판단한다. 불러올 수 있다는 한 줄 안내만 있거나 다른 레포 기준의 가이드라면 다음 단계로 간다. 사용자가 직접 호출했으면 어느 조직의 가이드가 적용 중인지와 그 가이드 끝의 경고를 한 줄로 알린다
3. 아래 명령 중 하나를 실행한다. `--manual`은 `apply`가 `suggest`나 `off`인 설정도 적용하므로 사용자가 요청했을 때만 붙인다

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/compose-guide" "<작업 대상 경로>"
   "${CLAUDE_PLUGIN_ROOT}/bin/compose-guide" --manual "<작업 대상 경로>"
   ```

   첫 줄은 스스로 판단해 호출했을 때, 둘째 줄은 사용자가 가이드 적용을 요청했을 때 쓴다

4. 출력에 따라 진행한다. 병합된 가이드를 적용할 때는 그 가이드의 규칙을 따르고, 병합된 가이드가 없으면 사용자가 아래의 "코어 규칙만 적용하기"를 고른 경우에만 이 파일의 규칙 섹션을 적용한다
   - `# brownfield-navigator 가이드`로 시작하면 어느 조직의 가이드를 적용하는지 한 줄로 알리고 이후 작업에 적용한다. 앞서 다른 레포 기준의 가이드가 있었으면 이 레포를 작업하는 동안에는 새 가이드만 따르고, 앞의 레포로 돌아가면 그 레포 기준의 가이드를 따른다. 출력 끝에 경고가 있으면 함께 전달한다
   - `# brownfield-navigator 안내`로 시작하면 그 안내를 사용자에게 전하고, 사용자가 원할 때만 `--manual`을 붙여 다시 실행한다
   - 사용자가 요청해 호출했는데 병합된 가이드가 없으면, 매칭되는 프로필이 없다고 알리고(경고가 있으면 함께 전달) 아래 두 가지를 제안한다
     - 이번 세션에 이 파일의 코어 규칙만 적용하기
     - `/brownfield-navigator:harvest-profile`로 프로젝트 메모리를 모아 이 레포를 프로필에 등록하기
   - 스스로 판단해 호출했는데 병합된 가이드가 없으면 알리지 않고 하던 작업을 계속한다. 출력에 경고가 있으면 세션에서 한 번만 한 줄로 전달한다
5. 4단계에서 병합된 가이드를 적용했는데 대화가 압축된 뒤 컨텍스트에서 보이지 않으면, 같은 대상 경로와 옵션으로 명령을 다시 실행해 적용한다. 사용자가 가이드를 끈 뒤라면 다시 실행하지 않는다

## [guide-stance] 가이드를 대하는 태도

이 가이드는 기존 흐름을 이어가는 확장·유지보수 작업의 기본값이다. 사용자가 다른 방식을 원하면 따르고 어긋나는 지점만 한 번 짧게 알리며, "가이드 끄기"를 요청하면 그 세션에서는 대화가 압축되어 이 가이드가 다시 주입되더라도 적용하지 않는다.

- 사용자가 새 구조, 실험, 컨벤션에서 벗어나는 작업을 원하면 그대로 따른다. 가이드와 어긋나는 지점만 한 번, 한 줄로 알리고 반복해서 권하지 않는다
- 사용자가 "가이드 끄기"처럼 적용 중단을 요청하면 그 세션에서는 대화가 압축되어 가이드가 다시 주입되더라도 적용하지 않는다

**Why:** 컨벤션을 따르고 싶은 사용자를 돕는 도구이지, 모든 작업에 컨벤션을 강제하는 장치가 아니다.

## [workflow-skill-conflict] 워크플로우 스킬과 부딪힐 때

TDD, 계획 작성·실행 같은 워크플로우 스킬의 단계(커밋, 테스트 파일 작성, 문서 산출물 커밋)가 레포 관례나 이 가이드와 부딪히면 관례를 따른다. 건너뛰거나 바꾼 단계는 보고한다.

**Why:** 범용 워크플로우는 레포 사정을 모른다. 테스트를 두지 않는 레포에 테스트 파일을 만들거나, 사용자가 직접 커밋하는 레포에서 자동으로 커밋하는 일이 생긴다.

## [delegate-with-guide] 서브에이전트에 위임할 때

서브에이전트에 작업을 맡길 때는 적용 중인 가이드 가운데 그 작업과 관련된 규칙(커밋 여부, 테스트 관례, 주석 형식, 네이밍 등)을 프롬프트에 함께 적는다.

**Why:** 서브에이전트는 세션 시작 때 주입된 가이드를 받지 않는다.

## [actual-tooling] 선언된 도구와 실제 도구

`package.json` 스크립트나 설정 파일이 있어도 그 도구가 실제로 동작한다고 보지 않는다. 실제로 쓸 수 있는 검증 수단(타입체크, 빌드, 포매터, 테스트 실행)을 먼저 확인하고, 동작하지 않는 도구는 설치하거나 고치는 데 시간을 쓰지 않고 그 사실과 대신 쓴 검증 수단을 알린다.

**Why:** lint 스크립트는 있는데 도구가 설치되어 있지 않거나, 테스트 설정은 있는데 테스트를 쓰지 않는 레거시 레포가 흔하다.

## [existing-pattern-first] 기존 사례 먼저

에러 처리, 파일 위치, 네이밍, 디렉터리 구성, 상태 관리 방식은 코드베이스에서 기존 사례를 먼저 찾아 따른다. 코드베이스에 없는 추상화(새 에러 클래스, 새 레이어, 새 라이브러리)는 들이지 않고, 필요하다고 판단되면 먼저 제안한다.

**Why:** 한 코드베이스에 같은 일을 하는 방식이 두 가지 생기면 다음 사람이 어느 쪽을 따라야 할지 모른다.

## [existing-vocabulary] 기존 어휘 사용

용어, 디자인 토큰 이름, 타입과 변수 이름은 코드베이스, 같은 백엔드나 디자인 시스템을 쓰는 자매 프로젝트, 팀 용어집에서 먼저 찾아 쓰고 없는 어휘를 새로 만들지 않는다. 표준 용어인지보다 이 팀이 아는 말인지가 기준이며, 확신이 없으면 명사를 만들지 말고 하는 일을 풀어 쓴다.

- 전문용어를 다른 전문용어로 바꾸는 것은 해결이 아니다

**Why:** 읽는 사람이 모르는 단어는 이름값을 못 한다. 자매 프로젝트끼리 이름이 갈라지면 대조와 유지보수가 어려워진다.

## [comment-density] 주석의 양과 어조

주석의 밀도와 어조는 주변 코드에 맞춘다. 코드가 이미 말하는 내용은 반복하지 않고, 고치는 사람이 실제로 빠질 함정과 코드만 봐서는 알 수 없는 이유만 남긴다.

- 설계 배경 설명은 문서에 두고, 코드에는 필요한 "왜"만 한두 문장으로 둔다

**Why:** 주변 톤과 어긋나는 장황한 주석은 리뷰에서 대부분 지워지고, 남으면 코드와 함께 낡는다.

## [preserve-vs-decide] 보존과 결정을 구분

기존 동작을 보존하는 수정과 새 동작을 정하는 수정을 구분한다. 요청, 명세, 기존 코드 어디에도 정해지지 않은 동작을 새로 정해야 하면 구현 전에 "현재 동작 / 문제 지점 / 선택지"로 정리해 먼저 묻는다. 작성 의도가 코드에서 분명한 버그는 버그가 만든 동작이 아니라 의도를 보존하고, 실제 동작과 달라진 점을 보고한다.

- 대상 예: 에러를 무시할지 재시도할지 중단할지, 모달을 띄울지와 그 문구, 기본값, 부분 실패 시 성공분을 유지할지
- 성격이 같은 결정은 묶어서 묻는다
- 의도가 분명한 버그의 예는 조건식 뒤바뀜(`||`와 `&&`)이다. 의도가 애매하면 두 해석을 보여 주고 묻는다

**Why:** 고장을 고치는 변경에 제품 결정이 조용히 섞이면 리뷰에서 걸러지지 않는다. 버그가 만든 동작을 보존하면 그 버그를 새 코드에 굳히게 된다.

## [stage-boundary] 단계를 섞지 않기

여러 단계로 나눈 작업에서는 항목마다 "이번 변경이 현재 동작을 바꾸는가"를 먼저 따진다. 동작을 바꾸지 않는 준비는 이번 단계에서 하고, 다음 단계에서야 의미가 생기는 판단은 넣지도 묻지도 않고 미룬다. `[preserve-vs-decide]`로 물을 결정을 고를 때도 이 기준으로 거른다.

**Why:** 근거가 생기기 전에 미래 동작을 확정하게 되고, 리뷰 범위도 흐려진다.

## [ideal-vs-current] 이상적인 구조와 현재 구조

리팩토링이나 재설계 요청을 받으면 명세 기준으로 독립적이고 완결된 이상적인 구조, 기존 코드에 얹는 방식, 두 방식의 비용과 이득을 함께 제시하고 선택은 사용자에게 맡긴다. 최소 수정을 고르더라도 이상적인 구조와의 차이는 명시한다. 새로 추가하는 코드는 바뀌는 이유가 다른 것(서버 계약과 화면 판정 규칙 등)끼리 한 파일에 섞지 않고, 이미 섞여 있는 기존 파일은 나누자고 제안만 한다.

**Why:** 기존 구조에 맞추는 것만 목표로 하면 우회 코드가 쌓여 의도가 흐려지고, 기존 구조를 무시하면 회귀 위험이 커진다.

## [respect-user-edits] 사용자의 수정 존중

사용자가 고친 코드, 주석, 이름은 되돌리지 않고 현재 파일을 기준으로 삼는다. 사용자의 수정 때문에 사실과 달라진 부분(없어진 함수를 가리키는 주석 등)만 지적하고 고친다.

- 계획이나 spec 문서의 코드는 실제 파일에 맞춰 갱신한다. 반대 방향으로 고치지 않는다

**Why:** 사용자는 코드를 직접 다듬으며 이해하고 정리한다. 원래 문구를 되살리면 그 과정을 되돌리게 된다.

## [verify-premise] 구조 변경 전 전제 검증

구조를 바꾸자고 권하기 전에 그 권고의 전제를 소스, 실제 스택 재현, 변경 이력으로 검증한다. 부수적인 목적의 작업이 구조 변경을 요구하면 전제가 틀렸다는 신호로 보고 멈춘다. 호출하는 곳이 없는 API는 의도가 아니라 흔적일 수 있고, 테스트 통과는 요구사항이 맞다는 증거가 아니다.

- 문서나 인수인계의 결론만 믿지 않고, 그 결론을 뒷받침하는 동작 원리를 소스에서 확인한다
- 타이밍이나 순서 실험은 실제 스택 그대로(상태 라이브러리, 빌드 모드 포함) 재현한다. 부품 하나를 빼면 결론이 뒤집힐 수 있다
- 변경 이력(git log, git blame, 없으면 문서나 담당자)으로 원래 의도를 확인한다. 호출하는 곳이 없는 API는 의도가 아니라 흔적일 수 있다
- 관측이나 로깅처럼 부수적인 목적의 작업이 구조 변경을 요구하면 전제가 틀렸다는 신호로 보고 멈춘 뒤, 현재 구조로 되는지부터 확인한다
- 테스트 통과는 요구사항이 맞다는 증거가 아니다

**Why:** 틀린 전제 하나가 설계, 구현, 문서 수정으로 번진다. 멈추는 계기가 검증이 아니라 사용자의 질문이 되기 쉽다.

## [structural-evidence] 구조적 근거로 판정

간헐적으로 나타나는 현상은 조건을 바꿔 가며 표본을 늘리지 않고, 원인이 되는 구조가 제거됐는지를 직접 확인해 판정한다. 구조 확인과 함께 같은 조건에서 비교 대상이 실제로 반응한 A/B 측정이 1회 있으면 충분하다.

1. 원인이 되는 구조가 제거됐는지 직접 측정한다
2. 같은 조건(같은 입력, 같은 검출 방법)에서 비교 대상이 실제로 반응한 A/B 측정이 1회 있으면 1과 함께 판정 근거로 충분하다
3. 이후 측정에서 비교 대상이 반응하지 않아도 앞의 A/B는 약해지지 않는다. 그 사실을 그대로 보고한다
4. 결정론적인 증상과 타이밍에 의존하는 증상을 구분하고, 반복 측정은 결정론적인 증상에만 쓴다

**Why:** 확률적인 현상은 표본을 늘려도 "이번엔 안 났다"만 반복되어 끝나지 않는다.

## [doc-conflict] 문서끼리 어긋날 때

문서끼리 어긋나면 프로필의 우선순위 규칙, 문서 성격(계약 문서가 정본), 최종 수정일, 실제 응답과 코드 확인 순으로 판정한다. 그래도 판정이 서지 않으면 양쪽 해석에서 같은 결과를 내는 구현을 먼저 찾고, 없으면 사용자에게 묻는다.

1. 이 가이드에 그 주제의 우선순위 규칙이 있으면 따른다
2. 문서의 성격을 구분한다. 계약 문서(API 스펙 등)는 주고받는 형태의 정본이고, 설계·기획 문서는 의도를 파악하고 미리 작업하기 위한 참고 자료다
3. 성격이 같은 문서끼리는 최종 수정일이 늦은 쪽을 따른다. 취소선이나 남아 있는 옛 서술은 폐기된 내용일 수 있다
4. 실제 응답, 코드, 데이터로 확인할 수 있으면 확인하고 그 결과를 따른다
5. 그래도 판정이 서지 않으면 양쪽 해석에서 같은 결과를 내는 구현이 있는지 먼저 찾고, 없으면 사용자에게 확인한다

**Why:** 설계 확정과 스펙 갱신 사이의 시차 때문에 문서 간 역전이 반복된다. 한쪽 문서만 보면 구현을 넣었다 뺐다 하게 된다.

## [spec-import] 필드와 타입 반영

다른 코드베이스에 이미 정의된 계약을 옮길 때는 필요한 부분만 추리지 않고 전체를 그대로 옮기되, 같은 이름이 이미 있으면 덮어쓰지 않고 비교해 보완하며 값이 다르면 임의로 합치지 않고 알린다. 문서를 보고 새로 정의할 때는 쓰는 곳이 있는지로 판단해, 쓰는 곳이 있으면 문서나 응답에 아직 없어도 optional로 넣고 쓰는 곳도 의미도 모르는 필드는 넣지 않는다.

- 옮기는 대상: enum 멤버, 인터페이스 필드, 주석, 의존 타입
- optional로 미리 넣은 필드는 응답에 오지 않으면 undefined라 동작이 바뀌지 않는다

**Why:** 일부만 옮긴 타입은 다음 사람에게 "왜 일부만 있지?"라는 혼란을 준다. 근거 없는 필드는 자동완성에 떠서 잘못 쓰인다.

## [team-boundary] 다른 팀과의 경계

- 다른 팀에 보내는 글에는 우리 쪽이 실제로 막힌 것만 적는다
- 상대 팀의 설계, 마이그레이션 절차, 배포 순서는 우리 설계의 근거로 삼지 않고 훈수 대상으로도 삼지 않는다. 정착한 뒤의 결과 형태만 본다

**Why:** 다른 팀의 내부 사정에 관여하면 소통 비용이 커지고, 그 팀의 중간 단계에 맞춘 구현은 금방 틀어진다.
````

- [ ] **Step 2: 규칙 id 추출 확인**

실행:

```bash
bash -c '. plugins/brownfield-navigator/lib/sections.sh; d="$(mktemp -d)"; extract_rule_sections plugins/brownfield-navigator/skills/brownfield-navigator/SKILL.md "$d"; cat "$d/ids"; rm -rf "$d"'
```

기대: 아래 16줄이 이 순서로 출력 (`이 스킬이 하는 일`, `호출되었을 때`는 id가 없어 제외)

```
guide-stance
workflow-skill-conflict
delegate-with-guide
actual-tooling
existing-pattern-first
existing-vocabulary
comment-density
preserve-vs-decide
stage-boundary
ideal-vs-current
respect-user-edits
verify-premise
structural-evidence
doc-conflict
spec-import
team-boundary
```

- [ ] **Step 3: 플러그인 검증**

실행: `claude plugin validate plugins/brownfield-navigator`
기대: `✔ Validation passed`

- [ ] **Step 4: Commit**

```bash
git add plugins/brownfield-navigator/skills/brownfield-navigator/SKILL.md
git commit -F - <<'EOF'
feat: 코어 규칙과 수동 호출 절차를 담은 brownfield-navigator 스킬 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 7: 가이드 합성 (`bin/compose-guide`)

**Files:**
- Create: `plugins/brownfield-navigator/bin/compose-guide`
- Test: `plugins/brownfield-navigator/tests/compose-guide.test.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/brownfield-navigator/tests/compose-guide.test.sh`

````bash
# bin/compose-guide 시나리오 테스트
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"

run_compose_guide() {
  BROWNFIELD_NAVIGATOR_HOME="$TEST_TMP/profiles" "$BASH" "$PLUGIN_ROOT/bin/compose-guide" "$@" 2>&1
}

# 조직 프로필: frontmatter 줄을 인자로 받고, <조직>-rule 섹션 하나를 함께 작성
write_org_profile() {
  local org_name="$1"
  shift
  write_lines "$TEST_TMP/profiles/orgs/$org_name/profile.md" \
    "---" "$@" "---" "" \
    "## [$org_name-rule] $org_name 규칙" "$org_name 규칙 본문"
}

# 프로젝트 파일: frontmatter 줄 다음에 오는 인자는 "--" 뒤에 본문 줄로 받음
write_project_file() {
  local org_name="$1" project_name="$2" arg
  shift 2
  local file_path="$TEST_TMP/profiles/orgs/$org_name/projects/$project_name.md"
  mkdir -p "$(dirname "$file_path")"
  printf '%s\n' "---" > "$file_path"
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    printf '%s\n' "$1" >> "$file_path"
    shift
  done
  printf '%s\n' "---" >> "$file_path"
  [ "$#" -gt 0 ] && shift
  for arg in "$@"; do
    printf '%s\n' "$arg" >> "$file_path"
  done
}

test_empty_without_profile_home() {
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  assert_empty "$(run_compose_guide "$TEST_TMP/app")" "프로필 홈이 없으면 빈 출력"
}

test_empty_when_nothing_matches() {
  write_org_profile acme "match-remotes:" '  - "*acme/*"'
  make_git_repo "$TEST_TMP/app" "git@github.com:other/app.git"
  assert_empty "$(run_compose_guide "$TEST_TMP/app")" "매칭되는 조직이 없으면 빈 출력"
}

test_merges_core_and_org_on_ssh_remote() {
  write_org_profile acme "apply: auto" "match-remotes:" '  - "*acme/*"'
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "# brownfield-navigator 가이드" "머리말"
  assert_contains "$output" "- 조직: acme (근거: remote git@github.com:acme/app)" "매칭 근거"
  assert_contains "$output" "- 대상: $TEST_TMP/app" "머리말에 가이드를 만든 대상 경로"
  assert_contains "$output" "## [guide-stance] 가이드를 대하는 태도 (코어)" "코어 섹션"
  assert_contains "$output" "## [acme-rule] acme 규칙 (조직: acme)" "조직 섹션"
  assert_order "$output" "## [team-boundary]" "## [acme-rule]" "조직의 새 id는 코어 뒤에 추가"
  assert_not_contains "$output" "## 호출되었을 때" "코어의 id 없는 섹션은 제외"
}

test_core_sections_are_summarized() {
  write_lines "$TEST_TMP/profiles/orgs/acme/profile.md" \
    "---" "match-remotes:" '  - "*acme/*"' "---" \
    "## [acme-rule] 조직 규칙" "조직 규칙 문단" "" "**Why:** 조직 규칙의 이유"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "## [guide-stance] 가이드를 대하는 태도 (코어)
이 가이드는 기존 흐름을 이어가는 확장·유지보수 작업의 기본값이다." "코어 규칙은 첫 문단을 출력"
  assert_not_contains "$output" "**Why:** 컨벤션을 따르고 싶은 사용자를 돕는 도구이지" "코어 규칙의 Why는 빠짐"
  assert_contains "$output" "$PLUGIN_ROOT/skills/brownfield-navigator/SKILL.md 의 같은 id 섹션" "머리말에 코어 전문 위치 안내"
  assert_contains "$output" "**Why:** 조직 규칙의 이유" "조직 규칙은 전문"
  assert_not_contains "$output" "> 이 가이드는" "예산 안이면 길이 안내 없음"
}

test_notice_when_guide_exceeds_budget() {
  local long_body
  long_body="$(awk 'BEGIN { for (i = 0; i < 9000; i++) printf "가" }')"
  write_lines "$TEST_TMP/profiles/orgs/acme/profile.md" \
    "---" "match-remotes:" '  - "*acme/*"' "---" \
    "## [long-rule] 긴 규칙" "$long_body"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "# brownfield-navigator 가이드

> 이 가이드는" "예산을 넘으면 제목 바로 아래에 안내"
  assert_contains "$output" "그 파일을 Read해 전체를 읽고 따른다" "안내에 전체를 읽으라는 지시"
  assert_order "$output" "> 이 가이드는" "- 조직: acme" "안내는 머리말보다 앞"
  assert_contains "$output" "## [long-rule] 긴 규칙 (조직: acme)" "가이드 본문은 그대로 출력"

  local medium_body
  medium_body="$(awk 'BEGIN { for (i = 0; i < 4000; i++) printf "가" }')"
  write_lines "$TEST_TMP/profiles/orgs/beta/profile.md" \
    "---" "match-remotes:" '  - "*beta/*"' "---" \
    "## [medium-rule] 중간 규칙" "$medium_body"
  make_git_repo "$TEST_TMP/beta-app" "git@github.com:beta/app.git"
  assert_not_contains "$(run_compose_guide "$TEST_TMP/beta-app")" "> 이 가이드는" "바이트가 아니라 문자 수로 셈 (한글 4,000자 규칙은 예산 안)"
}

test_project_matching_and_layer_precedence() {
  write_org_profile acme "match-remotes:" '  - "*acme/*"'
  write_lines "$TEST_TMP/profiles/personal.md" \
    "## [acme-rule] 개인이 바꾼 규칙" "개인 본문" \
    "## [shared] 개인 공유 규칙" "개인 공유 본문"
  write_project_file acme app "match-remotes:" '  - "*acme/app"' -- "## [shared] 앱 공유 규칙" "앱 공유 본문"
  write_project_file acme other "match-remotes:" '  - "*acme/other"' -- "## [shared] 다른 공유 규칙" "다른 공유 본문" "## [other-only] 다른 레포 전용" "다른 본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "- 프로젝트 파일: app
" "매칭된 프로젝트 파일만 표시"
  assert_contains "$output" "## [shared] 앱 공유 규칙 (프로젝트: app)" "프로젝트가 개인보다 우선"
  assert_contains "$output" "## [acme-rule] 개인이 바꾼 규칙 (개인)" "개인이 조직보다 우선"
  assert_not_contains "$output" "other-only" "매칭되지 않은 프로젝트 규칙은 빠짐"
  assert_not_contains "$output" "다른 공유 본문" "매칭되지 않은 프로젝트의 같은 id도 빠짐"
  assert_not_contains "$output" "## brownfield-navigator 경고" "매칭되지 않은 프로젝트는 경고 없음"
}

test_matches_https_remote_with_trailing_slash() {
  write_org_profile acme "match-remotes:" '  - "*acme/app"'
  make_git_repo "$TEST_TMP/app" "https://github.com/acme/app.git/"
  assert_contains "$(run_compose_guide "$TEST_TMP/app")" "근거: remote https://github.com/acme/app" "https remote 정규화 후 매칭"
}

test_matches_path_without_git_from_subdirectory() {
  mkdir -p "$TEST_TMP/home/work/acme/app/src"
  write_org_profile acme "match-paths:" '  - "~/work/acme/*"'
  local output
  output="$(HOME="$TEST_TMP/home" run_compose_guide "$TEST_TMP/home/work/acme/app/src")"
  assert_contains "$output" "근거: path ~/work/acme/*" "git 없이 ~ 경로 조건으로 하위 디렉터리에서 매칭"
}

test_project_replaces_core_section_in_place() {
  write_org_profile acme "match-remotes:" '  - "*acme/*"'
  write_project_file acme app "match-remotes:" '  - "*acme/app"' -- \
    "## [comment-density] 이 레포의 주석" "주석은 명사형으로 끝냄" "" "**Why:** 이 레포 주석 관례" \
    "## [app-only] 앱 전용 규칙" "앱 전용 본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "- 프로젝트 파일: app" "머리말에 프로젝트 파일 표시"
  assert_contains "$output" "## [comment-density] 이 레포의 주석 (프로젝트: app)" "같은 id는 프로젝트 제목과 출처로 교체"
  assert_occurrence_count "$output" "## [comment-density]" 1 "교체된 id는 한 번만 출력"
  assert_not_contains "$output" "주석의 밀도와 어조는 주변 코드에 맞춘다" "교체된 코어 본문은 빠짐"
  assert_contains "$output" "**Why:** 이 레포 주석 관례" "다른 층이 교체한 코어 id는 요약하지 않고 전문 출력"
  assert_order "$output" "## [comment-density]" "## [preserve-vs-decide]" "교체된 섹션은 코어 자리 유지"
  assert_order "$output" "## [acme-rule]" "## [app-only]" "프로젝트의 새 id는 끝에 추가"
}

test_personal_profile_only_when_merged() {
  write_lines "$TEST_TMP/profiles/personal.md" "## [my-habit] 내 습관" "습관 본문"
  write_org_profile acme "match-remotes:" '  - "*acme/*"'
  write_org_profile beta "apply: suggest" "match-remotes:" '  - "*beta/*"'
  make_git_repo "$TEST_TMP/acme-app" "git@github.com:acme/app.git"
  make_git_repo "$TEST_TMP/beta-app" "git@github.com:beta/app.git"
  assert_contains "$(run_compose_guide "$TEST_TMP/acme-app")" "## [my-habit] 내 습관 (개인)" "병합이 있으면 개인 프로필 포함"
  assert_not_contains "$(run_compose_guide "$TEST_TMP/beta-app")" "my-habit" "suggest만 있으면 개인 프로필 제외"
}

test_suggest_and_off() {
  write_org_profile beta "apply: suggest" "match-remotes:" '  - "*beta/*"'
  write_org_profile gamma "apply: off" "match-remotes:" '  - "*gamma/*"'
  make_git_repo "$TEST_TMP/beta-app" "git@github.com:beta/app.git"
  make_git_repo "$TEST_TMP/gamma-app" "git@github.com:gamma/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/beta-app")"
  assert_contains "$output" "# brownfield-navigator 안내" "suggest는 안내 제목"
  assert_contains "$output" "- beta 가이드를 적용할 수 있음. /brownfield-navigator:brownfield-navigator 로 불러오기" "suggest 안내문"
  assert_not_contains "$output" "## [guide-stance]" "suggest는 규칙을 병합하지 않음"
  assert_empty "$(run_compose_guide "$TEST_TMP/gamma-app")" "off는 출력 없음"
}

test_project_apply_overrides_org_apply() {
  write_org_profile acme "apply: off" "match-remotes:" '  - "*acme/*"'
  write_project_file acme app "apply: auto" "match-remotes:" '  - "*acme/app"'
  write_org_profile beta "match-remotes:" '  - "*beta/*"'
  write_project_file beta app "apply: off" "match-remotes:" '  - "*beta/app"'
  make_git_repo "$TEST_TMP/acme-app" "git@github.com:acme/app.git"
  make_git_repo "$TEST_TMP/beta-app" "git@github.com:beta/app.git"
  assert_contains "$(run_compose_guide "$TEST_TMP/acme-app")" "# brownfield-navigator 가이드" "조직 off라도 프로젝트 auto면 병합"
  assert_empty "$(run_compose_guide "$TEST_TMP/beta-app")" "조직 auto라도 프로젝트 off면 출력 없음"
}

test_multiple_projects_use_last_apply_and_warn() {
  write_org_profile acme "match-remotes:" '  - "*acme/*"'
  write_project_file acme a-first "apply: off" "match-remotes:" '  - "*acme/app"' -- "## [first-rule] 첫째" "본문"
  write_project_file acme b-second "apply: auto" "match-remotes:" '  - "*acme/*"' -- "## [second-rule] 둘째" "본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "# brownfield-navigator 가이드" "이름순 마지막 프로젝트의 apply(auto) 사용"
  assert_order "$output" "## [first-rule]" "## [second-rule]" "프로젝트 파일은 이름순으로 병합"
  assert_contains "$output" "acme: 프로젝트 파일 2개가 함께 매칭됨" "여러 프로젝트 매칭 경고"
}

test_manual_mode_merges_suggest_and_off() {
  write_org_profile beta "apply: suggest" "match-remotes:" '  - "*beta/*"'
  write_org_profile gamma "apply: off" "match-remotes:" '  - "*gamma/*"'
  make_git_repo "$TEST_TMP/beta-app" "git@github.com:beta/app.git"
  make_git_repo "$TEST_TMP/gamma-app" "git@github.com:gamma/app.git"
  assert_contains "$(run_compose_guide --manual "$TEST_TMP/beta-app")" "## [beta-rule] beta 규칙 (조직: beta)" "--manual은 suggest도 병합"
  assert_contains "$(run_compose_guide --manual "$TEST_TMP/gamma-app")" "## [gamma-rule] gamma 규칙 (조직: gamma)" "--manual은 off도 병합"
}

test_warnings_only_when_nothing_matches() {
  write_lines "$TEST_TMP/profiles/orgs/broken/profile.md" "apply: auto"
  mkdir -p "$TEST_TMP/plain"
  local output
  output="$(run_compose_guide "$TEST_TMP/plain")"
  assert_contains "$output" "## brownfield-navigator 경고" "경고 제목"
  assert_contains "$output" "건너뜀 $TEST_TMP/profiles/orgs/broken/profile.md: frontmatter 없음" "파싱 실패 경고"
  assert_not_contains "$output" "# brownfield-navigator 가이드" "매칭이 없으면 가이드 없음"
}

test_warns_on_unreadable_profile_files() {
  mkdir -p "$TEST_TMP/profiles/orgs/folder/profile.md"
  write_org_profile acme "match-remotes:" '  - "*acme/*"'
  mkdir -p "$TEST_TMP/profiles/orgs/acme/projects"
  ln -s "$TEST_TMP/missing-target.md" "$TEST_TMP/profiles/orgs/acme/projects/linked.md"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "건너뜀 $TEST_TMP/profiles/orgs/folder/profile.md: 파일을 읽을 수 없음" "디렉터리인 조직 프로필은 경고"
  assert_contains "$output" "건너뜀 $TEST_TMP/profiles/orgs/acme/projects/linked.md: 파일을 읽을 수 없음" "깨진 링크인 프로젝트 파일은 경고"
  assert_contains "$output" "## [acme-rule]" "읽을 수 있는 조직 프로필은 계속 병합"
}

test_invalid_utf8_in_profile_keeps_full_guide() {
  write_lines "$TEST_TMP/profiles/orgs/acme/profile.md" \
    "---" "match-remotes:" '  - "*acme/*"' "---" \
    "## [first-rule] 첫 규칙" "잘못된 바이트 $(printf '\261\333') 포함" \
    "## [second-rule] 둘째 규칙" "둘째 본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(LC_ALL=en_US.UTF-8 run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "## [second-rule] 둘째 규칙 (조직: acme)" "잘못된 UTF-8 뒤의 규칙도 빠지지 않음"
  assert_not_contains "$output" "towc" "awk 변환 오류가 없음"
}

test_unsupported_key_warning_with_guide() {
  write_org_profile acme "name: acme" "match-remotes:" '  - "*acme/*"'
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "## [acme-rule]" "지원하지 않는 키가 있어도 병합"
  assert_contains "$output" "profile.md: 지원하지 않는 키 무시: name" "지원하지 않는 키 경고"
}

test_two_auto_orgs_apply_first_only() {
  write_org_profile acme "match-remotes:" '  - "*shared/*"'
  write_org_profile beta "match-remotes:" '  - "*shared/*"'
  make_git_repo "$TEST_TMP/app" "git@github.com:shared/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "## [acme-rule]" "이름순 첫 조직 병합"
  assert_not_contains "$output" "## [beta-rule]" "두 번째 조직은 병합하지 않음"
  assert_contains "$output" "여러 조직이 매칭됨: acme, beta. acme 만 적용함" "여러 조직 매칭 경고"
}

test_lists_references() {
  write_org_profile acme "match-remotes:" '  - "*acme/*"'
  write_lines "$TEST_TMP/profiles/orgs/acme/references/repos.md" "---" "description: 레포 지도" "---" "본문"
  write_lines "$TEST_TMP/profiles/orgs/acme/references/plain.md" "설명 없는 참고 파일"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "## 참고 파일" "참고 파일 제목"
  assert_contains "$output" "- $TEST_TMP/profiles/orgs/acme/references/repos.md: 레포 지도" "description이 있는 참고 파일"
  assert_contains "$output" "- $TEST_TMP/profiles/orgs/acme/references/plain.md
" "description이 없으면 경로만"
}

run_test test_empty_without_profile_home
run_test test_empty_when_nothing_matches
run_test test_merges_core_and_org_on_ssh_remote
run_test test_core_sections_are_summarized
run_test test_notice_when_guide_exceeds_budget
run_test test_project_matching_and_layer_precedence
run_test test_matches_https_remote_with_trailing_slash
run_test test_matches_path_without_git_from_subdirectory
run_test test_project_replaces_core_section_in_place
run_test test_personal_profile_only_when_merged
run_test test_suggest_and_off
run_test test_project_apply_overrides_org_apply
run_test test_multiple_projects_use_last_apply_and_warn
run_test test_manual_mode_merges_suggest_and_off
run_test test_warnings_only_when_nothing_matches
run_test test_warns_on_unreadable_profile_files
run_test test_invalid_utf8_in_profile_keeps_full_guide
run_test test_unsupported_key_warning_with_guide
run_test test_two_auto_orgs_apply_first_only
run_test test_lists_references
finish_tests
````

- [ ] **Step 2: 테스트를 실행해 실패 확인**

실행: `bash plugins/brownfield-navigator/tests/compose-guide.test.sh; echo "exit=$?"`
기대: `bin/compose-guide: No such file or directory`, 마지막 줄 `compose-guide.test.sh: 20개 중 20개 실패`, `exit=1`

- [ ] **Step 3: 구현 작성**

`plugins/brownfield-navigator/bin/compose-guide`

````bash
#!/usr/bin/env bash
# 대상 디렉터리에 맞는 조직·프로젝트 프로필을 찾아 brownfield-navigator 가이드를 출력
#
# 사용법: compose-guide [--manual] [대상 디렉터리]
#   --manual  수동 호출용. apply 가 suggest, off 인 조직과 프로젝트도 병합
#
# 출력할 것이 없으면 빈 출력, 종료 코드는 항상 0
# bash 3.2 호환 (macOS 기본 /bin/bash)

set -u
# 프로필에 잘못된 UTF-8 바이트(예: 다른 인코딩으로 저장한 파일)가 섞여도 awk, sed가 중간에 멈춰
# 뒤쪽 규칙이 조용히 빠지지 않게 바이트 단위로 처리
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CORE_SKILL_FILE="$PLUGIN_ROOT/skills/brownfield-navigator/SKILL.md"
PROFILE_HOME="${BROWNFIELD_NAVIGATOR_HOME:-$HOME/.claude/brownfield-navigator}"
SKILL_COMMAND="/brownfield-navigator:brownfield-navigator"
# 훅 출력은 10,000자를 넘으면 앞부분 미리보기만 전달되므로 여유를 두고 잡은 예산
GUIDE_CHARACTER_BUDGET=9000

. "$PLUGIN_ROOT/lib/profile.sh"
. "$PLUGIN_ROOT/lib/match.sh"
. "$PLUGIN_ROOT/lib/sections.sh"

WORK_DIR=""
TARGET_DIR=""

add_warning() {
  printf '%s\n' "$1" >> "$WORK_DIR/warnings"
}

# 프로필 파일을 파싱해 결과 파일에 저장. 실패하면 경고를 남기고 실패 반환
parse_or_warn() {
  local profile_file="$1" parsed_file="$2" error_message warning_message
  parse_profile_frontmatter "$profile_file" > "$parsed_file"
  error_message="$(sed -n 's/^error=//p' "$parsed_file" | head -n 1)"
  if [ -n "$error_message" ]; then
    add_warning "건너뜀 $profile_file: $error_message"
    return 1
  fi
  sed -n 's/^warning=//p' "$parsed_file" | while IFS= read -r warning_message; do
    add_warning "$profile_file: $warning_message"
  done
  return 0
}

read_apply_value() {
  sed -n 's/^apply=//p' "$1" | tail -n 1
}

# 조직 하나를 매칭하고 적용 값에 따라 분류
#   auto    $WORK_DIR/auto-orgs 에 "조직<TAB>매칭 근거" 추가
#   suggest $WORK_DIR/suggest-orgs 에 조직 이름 추가
# 매칭된 프로젝트 파일 경로는 $WORK_DIR/projects-<조직> 에 이름순으로 기록
evaluate_org() {
  local org_profile="$1" manual_mode="$2"
  local org_dir org_name org_parsed match_reason matched_projects_file
  local project_file project_name project_parsed project_apply apply_value matched_project_count

  org_dir="$(dirname "$org_profile")"
  org_name="$(basename "$org_dir")"
  org_parsed="$WORK_DIR/org-$org_name.parsed"
  parse_or_warn "$org_profile" "$org_parsed" || return 0
  match_reason="$(print_match_reason "$org_parsed" "$WORK_DIR/remotes" "$TARGET_DIR")" || return 0

  matched_projects_file="$WORK_DIR/projects-$org_name"
  : > "$matched_projects_file"
  project_apply=""
  for project_file in "$org_dir"/projects/*.md; do
    # glob 에 걸린 것이 없을 때만 건너뜀. 디렉터리나 깨진 링크는 파싱 단계에서 경고로 드러남
    [ -e "$project_file" ] || [ -L "$project_file" ] || continue
    project_name="$(basename "$project_file" .md)"
    project_parsed="$WORK_DIR/project-$org_name-$project_name.parsed"
    parse_or_warn "$project_file" "$project_parsed" || continue
    print_match_reason "$project_parsed" "$WORK_DIR/remotes" "$TARGET_DIR" >/dev/null || continue
    printf '%s\n' "$project_file" >> "$matched_projects_file"
    apply_value="$(read_apply_value "$project_parsed")"
    if [ -n "$apply_value" ]; then
      project_apply="$apply_value"
    fi
  done

  matched_project_count="$(wc -l < "$matched_projects_file" | tr -d ' ')"
  if [ "$matched_project_count" -ge 2 ]; then
    add_warning "$org_name: 프로젝트 파일 ${matched_project_count}개가 함께 매칭됨. 이름순으로 모두 적용함"
  fi

  apply_value="$project_apply"
  if [ -z "$apply_value" ]; then
    apply_value="$(read_apply_value "$org_parsed")"
  fi
  if [ -z "$apply_value" ] || [ "$manual_mode" = 1 ]; then
    apply_value="auto"
  fi

  case "$apply_value" in
    auto) printf '%s\t%s\n' "$org_name" "$match_reason" >> "$WORK_DIR/auto-orgs" ;;
    suggest) printf '%s\n' "$org_name" >> "$WORK_DIR/suggest-orgs" ;;
  esac
}

# 파일의 줄들을 ", " 로 이어 한 줄로 출력
join_lines() {
  awk 'NR > 1 { printf ", " } { printf "%s", $0 } END { if (NR > 0) printf "\n" }' "$1"
}

print_header() {
  local org_name="$1" match_reason="$2"
  local matched_projects_file="$WORK_DIR/projects-$org_name"
  printf '# brownfield-navigator 가이드\n\n'
  printf -- '- 조직: %s (근거: %s)\n' "$org_name" "$match_reason"
  printf -- '- 대상: %s\n' "$TARGET_DIR"
  if [ -s "$matched_projects_file" ]; then
    printf -- '- 프로젝트 파일: %s\n' "$(sed 's#^.*/##; s#\.md$##' "$matched_projects_file" | join_lines /dev/stdin)"
  fi
  printf '\n'
  printf '%s\n\n' "기존 코드의 흐름과 조직 컨벤션을 따르는 작업을 위한 기본 가이드다. 사용자가 다른 방식을 원하면 그쪽을 따르고, 가이드와 어긋나는 지점만 한 번 짧게 알린다."
  printf '%s\n\n' "우선순위: 현재 사용자 지시 > CLAUDE.md > 프로젝트(프로젝트 파일, 프로젝트 메모리) > 개인 > 조직 > 코어. 같은 id의 규칙은 아래에 이미 이 순서로 병합되어 있다."
  printf '%s\n\n' "(코어) 규칙은 핵심 문단만 담았다. 세부 기준과 이유는 $CORE_SKILL_FILE 의 같은 id 섹션에 있으니 해당 상황에서 필요하면 읽는다."
}

print_suggestions() {
  local org_name
  while IFS= read -r org_name; do
    printf -- '- %s 가이드를 적용할 수 있음. %s 로 불러오기\n' "$org_name" "$SKILL_COMMAND"
  done < "$WORK_DIR/suggest-orgs"
  printf '\n'
}

print_rule_sections() {
  local org_name="$1" project_file merged_dir="$WORK_DIR/merged"
  extract_rule_sections "$CORE_SKILL_FILE" "$WORK_DIR/layer-core"
  merge_rule_layer "$WORK_DIR/layer-core" "코어" "$merged_dir"
  extract_rule_sections "$PROFILE_HOME/orgs/$org_name/profile.md" "$WORK_DIR/layer-org"
  merge_rule_layer "$WORK_DIR/layer-org" "조직: $org_name" "$merged_dir"
  if [ -f "$PROFILE_HOME/personal.md" ]; then
    extract_rule_sections "$PROFILE_HOME/personal.md" "$WORK_DIR/layer-personal"
    merge_rule_layer "$WORK_DIR/layer-personal" "개인" "$merged_dir"
  fi
  while IFS= read -r project_file; do
    rm -rf "$WORK_DIR/layer-project"
    extract_rule_sections "$project_file" "$WORK_DIR/layer-project"
    merge_rule_layer "$WORK_DIR/layer-project" "프로젝트: $(basename "$project_file" .md)" "$merged_dir"
  done < "$WORK_DIR/projects-$org_name"
  print_merged_sections "$merged_dir" "코어"
}

print_references() {
  local org_name="$1" reference_file description has_reference=0
  for reference_file in "$PROFILE_HOME/orgs/$org_name"/references/*.md; do
    [ -f "$reference_file" ] || continue
    if [ "$has_reference" = 0 ]; then
      printf '## 참고 파일\n\n관련 작업을 할 때 필요한 파일만 Read한다.\n\n'
      has_reference=1
    fi
    description="$(read_reference_description "$reference_file")"
    if [ -n "$description" ]; then
      printf -- '- %s: %s\n' "$reference_file" "$description"
    else
      printf -- '- %s\n' "$reference_file"
    fi
  done
  if [ "$has_reference" = 1 ]; then
    printf '\n'
  fi
}

# UTF-8 문자 수. 이어지는 바이트(0x80~0xBF)를 빼고 세므로 로캘과 무관
count_characters() {
  LC_ALL=C tr -d '\200-\277' < "$1" | wc -c | tr -d ' '
}

# 예산을 넘으면 첫 줄 제목 바로 아래에 전체를 읽으라는 안내를 넣어 출력. 안내가 미리보기 안에 들어가야 함
print_with_budget_notice() {
  local output_file="$1" character_count
  character_count="$(count_characters "$output_file")"
  if [ "$character_count" -le "$GUIDE_CHARACTER_BUDGET" ]; then
    cat "$output_file"
    return 0
  fi
  sed -n '1p' "$output_file"
  printf '\n> 이 가이드는 %s자로 훅 출력 한도에 가깝다. 앞부분만 보이고 저장된 파일 경로가 함께 표시되어 있으면, 그 파일을 Read해 전체를 읽고 따른다.\n' "$character_count"
  sed -n '2,$p' "$output_file"
}

print_warnings() {
  local warning_message
  printf '## brownfield-navigator 경고\n\n'
  while IFS= read -r warning_message; do
    printf -- '- %s\n' "$warning_message"
  done < "$WORK_DIR/warnings"
}

main() {
  local manual_mode=0 org_profile selected_org="" selected_reason="" auto_org_count

  if [ "${1:-}" = "--manual" ]; then
    manual_mode=1
    shift
  fi
  TARGET_DIR="$(cd "${1:-.}" 2>/dev/null && pwd -P)" || return 0
  [ -d "$PROFILE_HOME/orgs" ] || return 0

  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/brownfield-navigator.XXXXXX")" || return 0
  trap 'rm -rf "$WORK_DIR"' EXIT
  : > "$WORK_DIR/warnings"
  : > "$WORK_DIR/auto-orgs"
  : > "$WORK_DIR/suggest-orgs"
  list_remote_urls "$TARGET_DIR" > "$WORK_DIR/remotes"

  for org_profile in "$PROFILE_HOME"/orgs/*/profile.md; do
    [ -e "$org_profile" ] || [ -L "$org_profile" ] || continue
    evaluate_org "$org_profile" "$manual_mode"
  done

  auto_org_count="$(wc -l < "$WORK_DIR/auto-orgs" | tr -d ' ')"
  if [ "$auto_org_count" -ge 1 ]; then
    IFS="$(printf '\t')" read -r selected_org selected_reason < "$WORK_DIR/auto-orgs"
  fi
  if [ "$auto_org_count" -ge 2 ]; then
    add_warning "여러 조직이 매칭됨: $(cut -f1 "$WORK_DIR/auto-orgs" | join_lines /dev/stdin). $selected_org 만 적용함. 매칭 조건을 좁힐 것"
  fi

  {
    if [ -n "$selected_org" ]; then
      print_header "$selected_org" "$selected_reason"
    elif [ -s "$WORK_DIR/suggest-orgs" ]; then
      printf '# brownfield-navigator 안내\n\n'
    fi
    if [ -s "$WORK_DIR/suggest-orgs" ]; then
      print_suggestions
    fi
    if [ -n "$selected_org" ]; then
      print_rule_sections "$selected_org"
      print_references "$selected_org"
    fi
    if [ -s "$WORK_DIR/warnings" ]; then
      print_warnings
    fi
  } > "$WORK_DIR/output"
  print_with_budget_notice "$WORK_DIR/output"
}

main "$@"
exit 0
````

- [ ] **Step 4: 실행 권한 부여 후 테스트를 실행해 통과 확인**

실행: `chmod +x plugins/brownfield-navigator/bin/compose-guide && bash plugins/brownfield-navigator/tests/compose-guide.test.sh; echo "exit=$?"`
기대: `compose-guide.test.sh: 20개 중 0개 실패`, `exit=0`

- [ ] **Step 5: 전체 테스트 확인**

실행: `bash plugins/brownfield-navigator/tests/run-all.sh; echo "exit=$?"`
기대: compose-guide 20개, match 8개, profile 14개, sections 4개 모두 `0개 실패`, 마지막 줄 `테스트 파일 4개 모두 통과`, `exit=0`

- [ ] **Step 6: Commit**

```bash
git add plugins/brownfield-navigator/bin/compose-guide plugins/brownfield-navigator/tests/compose-guide.test.sh
git commit -F - <<'EOF'
feat: 조직, 개인, 프로젝트 프로필을 병합하는 compose-guide 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 8: SessionStart 훅

**Files:**
- Create: `plugins/brownfield-navigator/hooks/hooks.json`
- Create: `plugins/brownfield-navigator/hooks/run-hook.cmd`
- Create: `plugins/brownfield-navigator/hooks/session-start`
- Test: `plugins/brownfield-navigator/tests/session-start.test.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/brownfield-navigator/tests/session-start.test.sh`

````bash
# hooks/session-start 테스트 (JSON 검증에 python3 사용)
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"

run_session_start() {
  local hook_input="$1"
  printf '%s' "$hook_input" | BROWNFIELD_NAVIGATOR_HOME="$TEST_TMP/profiles" "$BASH" "$PLUGIN_ROOT/hooks/session-start" 2>&1
}

# 훅 출력 JSON을 파싱해 additionalContext 값을 출력. JSON이 올바르지 않으면 INVALID_JSON 출력
# Claude Code처럼 잘못된 UTF-8 바이트는 대체 문자로 읽음
read_additional_context() {
  python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
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
run_test test_keeps_guide_after_invalid_utf8
run_test test_outputs_nothing_without_match
run_test test_falls_back_to_project_dir_env
run_test test_prefers_cwd_over_project_dir_env
finish_tests
````

- [ ] **Step 2: 테스트를 실행해 실패 확인**

실행: `bash plugins/brownfield-navigator/tests/session-start.test.sh; echo "exit=$?"`
기대: `hooks/session-start: No such file or directory`, 마지막 줄 `session-start.test.sh: 5개 중 5개 실패`, `exit=1`

- [ ] **Step 3: 훅 스크립트 작성**

`plugins/brownfield-navigator/hooks/session-start`

````bash
#!/usr/bin/env bash
# SessionStart 훅: 훅 입력의 작업 디렉터리(cwd)에 맞는 brownfield-navigator 가이드를 컨텍스트로 주입
# startup, clear, compact 때 실행되므로 그 시점의 작업 디렉터리 기준
# 어떤 경우에도 세션을 막지 않음 (항상 exit 0)
# bash 3.2 호환

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
COMPOSE_GUIDE="$SCRIPT_DIR/../bin/compose-guide"

# 훅 입력 JSON에서 cwd 값을 꺼냄. 경로 안의 JSON 이스케이프(\" 나 \u)는 지원하지 않음
extract_cwd() {
  local hook_input="$1"
  local cwd_pattern='"cwd"[[:space:]]*:[[:space:]]*"([^"]*)"'
  if [[ "$hook_input" =~ $cwd_pattern ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

resolve_target_dir() {
  local cwd_from_input="$1"
  if [ -n "$cwd_from_input" ] && [ -d "$cwd_from_input" ]; then
    printf '%s\n' "$cwd_from_input"
  elif [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
    printf '%s\n' "$CLAUDE_PROJECT_DIR"
  else
    pwd
  fi
}

# JSON 문자열 값으로 쓸 수 있게 이스케이프. 탭, 줄바꿈, CR 이외의 제어문자는 제거
# bash 3.2의 ${var//a/b} 치환은 입력이 길수록 급격히 느려져(20KB에 약 2초) awk로 처리
# 백슬래시는 "&&"(매칭 텍스트 반복)로 두 배로 만들어 awk 구현마다 다른 치환 문자열 해석을 피함
# awk는 LC_ALL=C 로 실행. UTF-8 로캘에서는 잘못된 바이트를 만나면 멈춰 가이드 뒷부분이 빠짐
escape_for_json() {
  printf '%s' "$1" | LC_ALL=C tr -d '\001-\010\013\014\016-\037' | LC_ALL=C awk '
    BEGIN { ORS = "" }
    {
      gsub(/\\/, "&&")
      gsub(/"/, "\\\"")
      gsub(/\t/, "\\t")
      gsub(/\r/, "\\r")
      if (NR > 1) printf "\\n"
      printf "%s", $0
    }
  '
}

main() {
  local hook_input="" target_dir guide_text
  if [ ! -t 0 ]; then
    hook_input="$(cat)"
  fi
  target_dir="$(resolve_target_dir "$(extract_cwd "$hook_input")")"
  guide_text="$(bash "$COMPOSE_GUIDE" "$target_dir" 2>/dev/null)"
  [ -n "$guide_text" ] || return 0
  printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' \
    "$(escape_for_json "$guide_text")"
}

main
exit 0
````

- [ ] **Step 4: 훅 실행 래퍼 작성**

suberpower의 `run-hook.cmd`와 같은 파일이다. `cp ~/.claude/plugins/cache/suberpower/suberpower/1.3.0/hooks/run-hook.cmd plugins/brownfield-navigator/hooks/run-hook.cmd`로 복사하거나 아래 내용으로 작성한다.

`plugins/brownfield-navigator/hooks/run-hook.cmd`

````bash
: << 'CMDBLOCK'
@echo off
REM Cross-platform polyglot wrapper for hook scripts.
REM On Windows: cmd.exe runs the batch portion, which finds and calls bash.
REM On Unix: the shell interprets this as a script (: is a no-op in bash).
REM
REM Hook scripts use extensionless filenames (e.g. "session-start" not
REM "session-start.sh") so Claude Code's Windows auto-detection -- which
REM prepends "bash" to any command containing .sh -- doesn't interfere.
REM
REM Usage: run-hook.cmd <script-name> [args...]

if "%~1"=="" (
    echo run-hook.cmd: missing script name >&2
    exit /b 1
)

set "HOOK_DIR=%~dp0"

REM Try Git for Windows bash in standard locations
if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

REM Try bash on PATH (e.g. user-installed Git Bash, MSYS2, Cygwin)
where bash >nul 2>nul
if %ERRORLEVEL% equ 0 (
    bash "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

REM No bash found - exit silently rather than error
REM (plugin still works, just without SessionStart context injection)
exit /b 0
CMDBLOCK

# Unix: run the named script directly
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$1"
shift
exec bash "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
````

- [ ] **Step 5: 훅 등록 파일 작성**

`plugins/brownfield-navigator/hooks/hooks.json`

````json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  }
}
````

- [ ] **Step 6: 실행 권한 부여 후 테스트를 실행해 통과 확인**

실행: `chmod +x plugins/brownfield-navigator/hooks/session-start plugins/brownfield-navigator/hooks/run-hook.cmd && bash plugins/brownfield-navigator/tests/session-start.test.sh; echo "exit=$?"`
기대: `session-start.test.sh: 5개 중 0개 실패`, `exit=0`

- [ ] **Step 7: 플러그인 검증**

실행: `claude plugin validate plugins/brownfield-navigator`
기대: `✔ Validation passed`

- [ ] **Step 8: Commit**

```bash
git add plugins/brownfield-navigator/hooks plugins/brownfield-navigator/tests/session-start.test.sh
git commit -F - <<'EOF'
feat: 세션 시작 때 가이드를 주입하는 SessionStart 훅 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 9: 프로필 템플릿

**Files:**
- Create: `plugins/brownfield-navigator/templates/org-profile.md`
- Create: `plugins/brownfield-navigator/templates/project.md`
- Create: `plugins/brownfield-navigator/templates/personal.md`
- Create: `plugins/brownfield-navigator/templates/reference.md`
- Test: `plugins/brownfield-navigator/tests/templates.test.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/brownfield-navigator/tests/templates.test.sh`

````bash
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
  assert_occurrence_count "$output" "(조직: sample)" 1 "조직 템플릿의 규칙은 예시 하나뿐"
  assert_occurrence_count "$output" "(개인)" 1 "개인 템플릿의 규칙은 예시 하나뿐"
  assert_occurrence_count "$output" "(프로젝트: your-repo)" 1 "프로젝트 템플릿의 규칙은 예시 하나뿐"
}

run_test test_templates_compose_without_warnings
finish_tests
````

- [ ] **Step 2: 테스트를 실행해 실패 확인**

실행: `bash plugins/brownfield-navigator/tests/templates.test.sh; echo "exit=$?"`
기대: `templates/org-profile.md: No such file or directory`, 마지막 줄 `templates.test.sh: 1개 중 1개 실패`, `exit=1`

- [ ] **Step 3: 조직 프로필 템플릿 작성**

`plugins/brownfield-navigator/templates/org-profile.md`

````markdown
---
# 적용 강도: auto(규칙 주입) | suggest(한 줄 안내만) | off(주입 안 함). 생략하면 auto
apply: auto
# git remote URL 패턴 (bash glob). URL 끝의 / 와 .git 은 떼고 비교하고, 대소문자를 구분한다
# 앞의 [:/] 는 owner 앞에 다른 글자가 붙은 이름(not-your-org)까지 맞는 것을 막는다
match-remotes:
  - "*[:/]your-org/*"
# 경로 패턴 (bash glob). 대상 디렉터리나 그 상위 디렉터리와 비교, 앞머리 ~ 는 홈으로 확장
# 대상 경로는 심볼릭 링크를 따라간 실제 경로다. 홈을 포함해 경로 중간에 링크가 있으면 ~ 대신 실제 경로를 쓴다
# 디렉터리 패턴 끝에 / 를 붙이면 매칭되지 않는다
match-paths: []
---

# 조직 프로필

위치: `~/.claude/brownfield-navigator/orgs/<조직 이름>/profile.md` (조직 이름은 디렉터리 이름)

- `## [id] 제목` 섹션만 규칙으로 병합된다. id는 소문자, 숫자, `-`만 쓰고, 섹션 안의 소제목은 `###` 이하로 쓴다
- 코어 규칙과 같은 id를 쓰면 그 규칙을 대체하고, 새 id는 뒤에 추가된다
- 규칙마다 짧은 `**Why:**`를 적으면 Claude가 적용 여부를 스스로 판단할 수 있다
- 리스트는 블록 형식만 지원한다. `["a", "b"]` 형식을 쓰면 이 파일 전체를 건너뛰고 경고를 남긴다
- 아래 `## [id]` 섹션은 예시다. 자기 규칙으로 바꾸거나 섹션째 지운다. HTML 주석으로 감싸도 규칙으로 읽힌다

## [commit-message] 커밋 메시지

커밋 메시지는 `type: 설명 TICKET-123` 형식으로 쓴다. 티켓 번호는 브랜치 이름에서 확인한다.

**Why:** 레포 이력의 기존 형식과 맞추기 위함
````

- [ ] **Step 4: 프로젝트 파일 템플릿 작성**

`plugins/brownfield-navigator/templates/project.md`

````markdown
---
# apply 를 생략하면 조직 프로필의 값을 따른다
# apply: auto
# 키와 패턴 규칙은 조직 프로필과 같다. 단, 조직 프로필이 먼저 매칭된 레포에서만 이 파일을 검사한다
match-remotes:
  - "*[:/]your-org/your-repo"
match-paths: []
---

# 프로젝트 파일

위치: `~/.claude/brownfield-navigator/orgs/<조직 이름>/projects/<프로젝트 이름>.md`

상위 층(코어, 조직, 개인)과 달라지는 규칙, 또는 이 레포에만 항상 적용할 규칙만 둔다. 설정값이나 함정 같은 사실 정보는 Claude Code 프로젝트 메모리에 둔다.

- `## [id] 제목` 섹션만 규칙으로 병합된다. id는 소문자, 숫자, `-`만 쓰고, 섹션 안의 소제목은 `###` 이하로 쓴다
- 아래 `## [id]` 섹션은 예시다. 자기 규칙으로 바꾸거나 섹션째 지운다. HTML 주석으로 감싸도 규칙으로 읽힌다

## [tests] 테스트 코드

이 레포는 테스트 파일을 만들지 않는다. 타입체크와 빌드로 검증한다.

**Why:** 조직 기본값과 다른 이 레포의 관례
````

- [ ] **Step 5: 개인 프로필 템플릿 작성**

`plugins/brownfield-navigator/templates/personal.md`

````markdown
# 개인 프로필

위치: `~/.claude/brownfield-navigator/personal.md`

조직 프로필이 매칭되어 가이드가 병합될 때만 적용된다. Claude와 일하는 방식에 대한 선호를 둔다. frontmatter는 쓰지 않는다.

- `## [id] 제목` 섹션만 규칙으로 병합된다. id는 소문자, 숫자, `-`만 쓰고, 섹션 안의 소제목은 `###` 이하로 쓴다
- 아래 `## [id]` 섹션은 예시다. 자기 규칙으로 바꾸거나 섹션째 지운다. HTML 주석으로 감싸도 규칙으로 읽힌다

## [commit-by-user] 커밋은 직접

요청하지 않으면 커밋하지 않는다. 변경을 마치면 변경 파일과 요지만 보고한다.

**Why:** 변경 내용을 직접 확인한 뒤 커밋 단위와 메시지를 정하기 위함
````

- [ ] **Step 6: 참고 파일 템플릿 작성**

`plugins/brownfield-navigator/templates/reference.md`

````markdown
---
description: 이 참고 파일이 담은 내용을 한 줄로
---

# 참고 파일

위치: `~/.claude/brownfield-navigator/orgs/<조직 이름>/references/<주제>.md`

세션에는 경로와 위 description 한 줄만 주입되고, Claude가 관련 작업을 할 때 이 파일을 읽는다. 여러 레포에 걸친 긴 참고 정보(레포 지도, 외부 규약 등)를 둔다. 본문 형식은 자유다.
````

- [ ] **Step 7: 테스트를 실행해 통과 확인**

실행: `bash plugins/brownfield-navigator/tests/templates.test.sh; echo "exit=$?"`
기대: `templates.test.sh: 1개 중 0개 실패`, `exit=0`

- [ ] **Step 8: Commit**

```bash
git add plugins/brownfield-navigator/templates plugins/brownfield-navigator/tests/templates.test.sh
git commit -F - <<'EOF'
feat: 조직, 프로젝트, 개인, 참고 파일 템플릿 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 10: 수집 스킬 (`skills/harvest-profile/SKILL.md`)

**Files:**
- Create: `plugins/brownfield-navigator/skills/harvest-profile/SKILL.md`

- [ ] **Step 1: 수집 스킬 작성**

`plugins/brownfield-navigator/skills/harvest-profile/SKILL.md`

````markdown
---
name: harvest-profile
description: "Claude Code 프로젝트 메모리를 모아 brownfield-navigator 프로필(조직, 개인, 프로젝트 파일)의 초안을 만들고, 승인을 받아 기록한다. 처음 설정할 때나 메모리가 쌓인 뒤 프로필을 보완할 때 사용자가 직접 호출한다."
disable-model-invocation: true
argument-hint: "[조직 이름 또는 메모리 경로]"
---

# 프로필 수집

프로젝트 메모리(`~/.claude/projects/*/memory/`)에 흩어진 지침을 모아 brownfield-navigator 프로필로 정리한다.

- 파일을 쓰기 전에 반드시 사용자 승인을 받는다
- 메모리를 삭제하거나 수정하지 않는다

인자(`$ARGUMENTS`)가 조직 이름이면 그 조직 후보만, 메모리 경로면 그 경로만 다룬다. 인자가 없으면 전체를 다룬다.

## 경로

- 프로필 홈: 환경변수 `BROWNFIELD_NAVIGATOR_HOME`, 없으면 `~/.claude/brownfield-navigator`
- 파일 형식과 예시: `${CLAUDE_PLUGIN_ROOT}/templates/`의 `org-profile.md`, `personal.md`, `project.md`, `reference.md`
- 코어 규칙: `${CLAUDE_PLUGIN_ROOT}/skills/brownfield-navigator/SKILL.md`의 `## [id]` 섹션
- 미리보기: `"${CLAUDE_PLUGIN_ROOT}/bin/compose-guide" "<레포 경로>"`
- 중복 판정 기준: 전역 `~/.claude/CLAUDE.md`와 각 레포 루트의 `CLAUDE.md`

## 1. 수집

1. `~/.claude/projects/*/memory/*.md` 목록을 만든다. `MEMORY.md`는 색인이므로 제외한다
2. 프로젝트 디렉터리마다 원래 작업 경로를 복원한다
   - 같은 디렉터리의 `*.jsonl` 트랜스크립트에서 첫 `"cwd"` 값을 읽는다: `grep -o -m 1 '"cwd":"[^"]*"' <jsonl 파일>`
   - jsonl이 없으면 디렉터리 이름의 `-`를 `/`로 바꾼 후보 중 실제로 존재하는 경로를 쓴다. 후보가 여럿이거나 없으면 사용자에게 묻는다
3. 복원한 경로마다 `git -C <경로> remote -v`로 remote를 조회한다. fork처럼 owner가 다른 remote가 둘 이상이면 어느 쪽을 조직 기준으로 삼을지 2단계에서 함께 묻는다
4. 조직 후보로 묶는다. remote가 있으면 owner(예: `git@github.com:acme/app.git`의 `acme`)가 기준이고, 없으면 상위 디렉터리가 기준이다. owner가 여럿이면 양쪽 후보에 모두 올린다

메모리가 하나도 없으면 수집을 건너뛴다. 조직 이름과 대상 레포 경로를 사용자에게 직접 묻고, `templates/`에서 예시 섹션을 지운 최소 조직 프로필(매칭 조건만 있는 `profile.md`)을 제안한다. 작성은 5단계 2~4항과 "이미 프로필이 있을 때" 절을 그대로 따르고, 6단계 보고까지 진행한다. 메모리가 쌓인 뒤 이 스킬을 다시 호출하면 규칙을 채울 수 있다고 알린다.

## 2. 범위 확인

조직 후보별로 프로젝트 목록과 메모리 개수를 표로 보여주고 묻는다.

- 어떤 후보를 조직으로 등록할지, 조직 이름(프로필 디렉터리 이름)을 무엇으로 할지
- 각 조직에 포함할 프로젝트. 개인 프로젝트나 실험용 레포를 뺄지는 사용자가 정한다
- owner가 여러 개인 레포는 어느 owner를 조직 기준으로 삼을지

사용자가 정한 범위의 메모리만 다음 단계에서 읽는다.

## 3. 분류

분류 전에 전역 `~/.claude/CLAUDE.md`와 범위에 든 레포의 `CLAUDE.md`를 읽어 중복 판정 기준으로 쓴다. 이 파일들은 수정하지 않는다.

메모리 본문을 모두 읽고 항목마다 아래 표로 분류한다. 한 메모리에 여러 규칙이 섞여 있으면 나눠서 분류한다.

| 조건 | 분류 |
|---|---|
| 코어 규칙과 같은 내용 | 생략. 어느 코어 id와 겹치는지 기록 |
| 레포에 남는 산출물에 대한 규약 (커밋 메시지 형식, 주석 형식, 네이밍, 문구 출처 등) | 조직 프로필 |
| Claude와 일하는 방식 (커밋 여부, 보고 방식, 산출물 보관 등) | 개인 프로필 |
| 같은 주제인데 레포마다 다름 | 조직 기본값과, 달라지는 레포의 프로젝트 파일 (같은 id) |
| 한 레포에서만 나온 규칙 | 적용 범위를 사용자에게 질문. 넓히지 않으면 그 레포의 프로젝트 파일 |
| 설정값, 함정, 문서 위치, 진행 중인 작업 기록 같은 사실 | 메모리에 유지 (프로필에 넣지 않음) |
| 여러 레포에 걸친 긴 참고 정보 (레포 지도, 외부 규약) | 조직 `references/` |
| 전역 또는 레포 CLAUDE.md와 같은 내용 | 생략. 어느 파일과 겹치는지 기록 |

같은 규칙이 여러 레포에 복제되어 있으면 하나로 합치고 출처 레포를 모두 기록한다.

## 4. 충돌 정리

서로 부딪히는 규칙은 나란히 보여주고, 아래 둘 중 하나로 정리안을 제시한다.

- **적용 상황으로 구분:** 두 규칙이 서로 다른 상황을 다루면 한 규칙 안에서 상황별로 나눠 적는다
- **조직 기본값과 프로젝트 대체:** 레포마다 관례가 다르면 조직에 기본값을 두고, 다른 레포는 같은 id로 대체한다

사용자가 고른 정리안을 초안에 반영한다.

## 5. 초안과 작성

1. 층별 초안을 보여준다. 규칙마다 id, 제목, 본문, `**Why:**`, 출처 메모리를 적는다. 참고 파일은 규칙이 아니므로 `description:` 한 줄과 본문 요지를 따로 보여준다
2. 매칭 조건을 제안한다
   - 조직: remote가 있으면 `"*[:/]<owner>/*"`, 없으면 `"<공통 상위 경로>/*"`
   - 프로젝트: remote가 있으면 `"*[:/]<owner>/<레포 이름>"`, 없으면 레포 경로
   - 경로 패턴은 `cd "<레포 경로>" && pwd -P` 결과로 만든다. `$HOME` 값이 `cd ~ && pwd -P` 결과와 같을 때만 앞을 `~/`로 줄이고, 다르면 `pwd -P` 결과를 그대로 쓴다
   - 조직의 `apply`를 함께 묻는다. `auto`는 규칙 주입, `suggest`는 한 줄 안내, `off`는 주입 안 함이고, 생략하면 `auto`다
3. 사용자 승인을 받는다. 승인 전에는 파일을 쓰지 않는다
4. `templates/`의 형식대로 파일을 쓴다
   - frontmatter 리스트는 블록 형식(`  - "패턴"`)만 쓴다. `["패턴"]` 형식은 파싱 실패로 무시된다
   - id는 소문자, 숫자, `-`만 쓴다
   - 규칙 본문의 소제목은 `###` 이하로 쓴다. 메모리 원문에 `##` 헤딩이 있으면 `###`로 낮춘다. `##`가 남으면 그 아래 본문이 경고 없이 버려진다

### 이미 프로필이 있을 때

기존 파일을 덮어쓰지 않는다. 기존 규칙과 비교해 추가할 규칙과 바꿀 규칙을 diff 형태로 보여주고, 승인받은 부분만 반영한다.

## 6. 보고

1. 생성하거나 수정한 파일 목록
2. 포함한 레포마다 `compose-guide` 미리보기. 매칭 근거 줄과 경고 절을 보여주고, 경고가 있으면 고친다. 다시 고칠 때도 5단계 3항의 승인 원칙을 따른다
3. 정리 후보 메모리 목록: 프로필로 옮겨진 메모리, CLAUDE.md(전역·레포)와 중복인 메모리. **삭제하지 않고 목록만 보고한다.** 정리는 사용자가 직접 한다
4. 프로필 홈은 플러그인 바깥의 사용자 파일이므로, 다른 기기에서 쓰려면 따로 백업하거나 동기화해야 한다고 한 줄로 알린다
````

- [ ] **Step 2: 플러그인 검증**

실행: `claude plugin validate plugins/brownfield-navigator`
기대: `✔ Validation passed`

- [ ] **Step 3: Commit**

```bash
git add plugins/brownfield-navigator/skills/harvest-profile/SKILL.md
git commit -F - <<'EOF'
feat: 프로젝트 메모리로 프로필 초안을 만드는 harvest-profile 스킬 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 11: README (한국어, 영어)와 줄바꿈 속성

**Files:**
- Create: `README.md`
- Create: `README.en.md`
- Create: `.gitattributes`
- Create: `plugins/brownfield-navigator/tests/readme.test.sh`

- [ ] **Step 1: 한국어 README 작성**

`README.md`

````markdown
# brownfield-navigator

한국어 | [English](README.en.md)

레거시(brownfield) 코드베이스에서 기능을 넓히거나 유지보수할 때, **회사 컨벤션과 기존 코드의 흐름을 따르고 싶은 사용자를 위한** Claude Code 플러그인입니다.

프로젝트 메모리에 흩어진 지침을 조직, 개인, 프로젝트 프로필로 정리해 두면, 세션을 시작할 때 작업 디렉터리에 맞는 가이드를 병합해 주입합니다. 개인 프로젝트처럼 프로필에 맞지 않는 곳에서는 아무것도 하지 않습니다.

강제 장치가 아니라 가이드입니다. 사용자가 다른 방식을 원하면 Claude는 그쪽을 따릅니다.

## 동작 방식

| 층 | 내용 | 위치 |
|---|---|---|
| 코어 | 회사와 도구에 무관한 레거시 작업 원칙 | 플러그인 `skills/brownfield-navigator/SKILL.md` |
| 조직 | 회사 컨벤션 | `~/.claude/brownfield-navigator/orgs/<조직>/profile.md` |
| 개인 | Claude와 일하는 방식에 대한 개인 선호 | `~/.claude/brownfield-navigator/personal.md` |
| 프로젝트 | 특정 레포에서만 달라지는 규칙 | `~/.claude/brownfield-navigator/orgs/<조직>/projects/<이름>.md` |

1. 세션이 시작되면 훅이 작업 디렉터리의 git remote와 경로를 조직 프로필의 매칭 조건과 비교합니다
2. 매칭되면 `## [id] 제목` 섹션을 코어, 조직, 개인, 프로젝트 순으로 병합합니다. 같은 id는 뒤의 층이 대체합니다
3. 병합된 가이드와 참고 파일 목록이 세션 컨텍스트에 들어갑니다

설정값이나 함정 같은 프로젝트 고유의 사실은 지금처럼 Claude Code 프로젝트 메모리에 둡니다.

## 설치

```
/plugin marketplace add june20516/brownfield-navigator
/plugin install brownfield-navigator@brownfield-navigator
```

요구 사항: Claude Code, bash 3.2 이상. git은 remote 조건을 쓸 때만 필요합니다.

## 처음 설정

수집 스킬을 호출합니다.

```
/brownfield-navigator:harvest-profile
```

프로젝트 메모리가 쌓여 있으면 그 내용을 모아 조직 후보를 보여주고, 분류와 충돌 정리를 거쳐 초안을 만듭니다. 메모리가 없으면 조직 이름과 레포 경로를 물어 매칭 조건만 담은 최소 프로필을 만듭니다. 어느 쪽이든 승인한 내용만 파일로 쓰고, 메모리는 삭제하거나 수정하지 않습니다.

형식을 보고 직접 쓰고 싶다면 아래 [프로필 형식](#프로필-형식)의 예시를 옮겨 써도 됩니다.

## 동작 확인

훅은 세션이 시작될 때만 실행됩니다. 그래서 프로필을 만들거나 고친 뒤에는 새 세션을 시작하거나 `/clear` 해야 반영됩니다.

가이드는 Claude의 컨텍스트로만 들어가고 화면에는 보이지 않습니다. 잘 들어갔는지 보려면 대상 레포에서 세션을 시작한 뒤 스킬을 호출합니다. 어느 조직의 가이드를 적용하는지, 프로필을 읽다 생긴 경고가 있는지 Claude가 알려 줍니다.

```
/brownfield-navigator:brownfield-navigator
```

## 프로필 형식

### 조직 프로필과 프로젝트 파일

```markdown
---
apply: auto
match-remotes:
  - "*[:/]your-org/*"
match-paths:
  - "~/work/your-org/*"
---

## [commit-message] 커밋 메시지

커밋 메시지는 `type: 설명 TICKET-123` 형식으로 쓴다.

**Why:** 레포 이력의 기존 형식과 맞추기 위함
```

- `apply`: `auto`(규칙 주입), `suggest`(한 줄 안내만), `off`(주입 안 함). 생략하면 `auto`이고, 프로젝트 파일에서 생략하면 조직 값을 따릅니다
- `match-remotes`: git remote URL과 비교하는 bash glob입니다. URL 끝의 `/`와 `.git`, `https://user:token@host` 형식의 인증 정보는 떼고 비교하고, 대소문자를 구분합니다. `*your-org/*`는 `not-your-org`에도 맞으므로, 예시처럼 앞에 `[:/]`를 두어 owner 경계를 고정합니다
- `match-paths`: 작업 디렉터리나 그 상위 디렉터리와 비교하는 bash glob입니다. 앞머리 `~`는 홈으로 확장하고, 대상 경로는 심볼릭 링크를 따라간 실제 경로입니다. 홈을 포함해 경로 중간에 링크가 있으면 `~` 대신 실제 경로를 씁니다. 비교는 바이트 단위라 `?`와 `[...]`는 한글처럼 ASCII가 아닌 문자 한 글자에 맞지 않으니 그 자리에는 `*`를 씁니다. 디렉터리 패턴 끝에 `/`를 붙이면 매칭되지 않습니다(`"~/work/your-org/"`가 아니라 `"~/work/your-org/*"`). git을 쓰지 않는다면 이 조건을 씁니다
- 두 키의 패턴 중 **하나라도** 맞으면 매칭입니다. 둘을 모두 만족해야 하는 방식은 지원하지 않으므로, 범위를 좁히려면 패턴 자체를 좁힙니다
- 리스트는 블록 형식만 지원합니다. `["a", "b"]` 형식을 쓰면 그 파일 전체를 건너뛰고 경고가 남습니다. 한쪽 조건만 쓸 때 다른 키는 값을 비워 두지 말고 `match-paths: []`처럼 빈 리스트로 적습니다. 값 없이 두면 역시 파일 전체를 건너뜁니다
- 조직 이름은 `orgs/` 아래 디렉터리 이름, 프로젝트 이름은 파일 이름입니다. 프로젝트 파일은 조직 프로필이 먼저 매칭된 레포에서만 검사합니다

### 규칙 섹션

- `## [id] 제목`부터 다음 `## ` 헤딩 전까지가 규칙 하나입니다. id는 소문자, 숫자, `-`만 씁니다. 코드 블록 안의 `## ` 줄은 헤딩으로 세지 않으므로, 규칙 본문에 마크다운 예시를 넣어도 섹션이 쪼개지지 않습니다
- 같은 id는 대체, 새 id는 추가입니다. 코어 규칙의 id는 `guide-stance`, `workflow-skill-conflict`, `delegate-with-guide`, `actual-tooling`, `existing-pattern-first`, `existing-vocabulary`, `comment-density`, `preserve-vs-decide`, `stage-boundary`, `ideal-vs-current`, `respect-user-edits`, `verify-premise`, `structural-evidence`, `doc-conflict`, `spec-import`, `team-boundary` 열여섯 개입니다. 병합된 가이드에서는 섹션 제목 끝에 `(코어)`, `(조직: your-org)`처럼 최종 출처가 붙습니다
- id가 없는 `## ` 섹션은 설명으로 보고 병합하지 않습니다
- 규칙을 끄려면 섹션을 지웁니다. HTML 주석(`<!-- -->`)으로 감싸도 규칙으로 읽힙니다

### 개인 프로필

`personal.md`에는 frontmatter 없이 규칙 섹션만 둡니다. 조직 프로필이 매칭되어 가이드가 병합될 때만 적용됩니다.

### 참고 파일

`orgs/<조직>/references/<주제>.md`에 frontmatter `description:` 한 줄을 둡니다. 세션에는 경로와 설명만 들어가고, Claude가 관련 작업을 할 때 읽습니다.

## 수동으로 불러오기

여러 레포를 오가는 디렉터리에서 세션을 시작했거나, `apply`가 `suggest` 또는 `off`인 레포에서 가이드를 쓰려면 호출합니다. 수동 호출은 `off`로 꺼 둔 설정까지 되살리므로, Claude는 사용자가 요청했을 때만 그렇게 동작합니다.

```
/brownfield-navigator:brownfield-navigator
```

이 레포를 받아 두었다면 스크립트를 직접 실행해도 됩니다.

```bash
plugins/brownfield-navigator/bin/compose-guide --manual ~/work/your-org/your-repo
```

## 가이드가 나오지 않을 때

1. 대상 레포에서 세션을 시작한 뒤 `/brownfield-navigator:brownfield-navigator`를 호출합니다. 매칭되는 프로필이 없으면 없다고 알려 주고, 프로필을 읽다 실패했으면 그 경고를 보여 줍니다
2. 매칭 조건을 봅니다. `match-remotes`와 `match-paths`에 패턴이 **하나도 없는** 프로필은 어디에도 매칭되지 않고, 이때는 경고도 나오지 않습니다. 경로 패턴 끝에 `/`가 붙은 경우도 마찬가지로 조용히 실패합니다
3. `match-paths`는 심볼릭 링크를 따라간 실제 경로와 비교합니다. 대상 레포에서 `pwd -P`로 실제 경로를 확인해 패턴과 맞춰 보세요
4. frontmatter의 키 이름을 봅니다. 지원하지 않는 키는 무시하고 경고를 남기므로, `match-remote`처럼 오타가 난 키는 1번에서 경고로 드러납니다

## 주의

- 프로필은 `~/.claude/brownfield-navigator/`에 있는 사용자 파일입니다. 플러그인을 업데이트해도 지워지지 않지만, 다른 기기에서 쓰려면 따로 백업하거나 동기화해야 합니다. 위치는 환경변수 `BROWNFIELD_NAVIGATOR_HOME`으로 바꿀 수 있습니다
- 서브에이전트는 세션 시작 주입을 받지 않습니다. 코어 규칙 `[delegate-with-guide]`에 따라 Claude가 관련 규칙을 위임 프롬프트에 함께 적습니다
- 한 레포에 `auto` 조직이 둘 이상 매칭되면 이름순 첫 조직만 적용하고 경고합니다
- 한 조직에서 프로젝트 파일이 둘 이상 매칭되면 조직과 달리 하나를 고르지 않고 이름순으로 모두 병합하며, 경고합니다. `apply`는 값을 가진 마지막 파일의 값을 쓰므로, 파일 하나를 더했을 뿐인데 적용 강도가 바뀔 수 있습니다
- Claude Code는 훅 출력을 10,000자로 제한합니다. 그래서 세션에 주입하는 가이드에는 코어 규칙의 핵심 문단만 넣고(전문은 SKILL.md), 조직·개인·프로젝트 규칙은 전문을 넣습니다. 합쳐서 9,000자를 넘으면 제목 바로 아래에 "잘린 뒤에도 전체를 읽을 수 있으면 읽으라"는 조건부 안내가 붙지만, 잘린 출력이 파일로 남는지는 Claude Code에 달려 있으므로 9,000자 아래로 유지하는 편이 안전합니다. 조직 규칙이 길어지면 긴 설명은 참고 파일(`references/`)로 옮기세요

## 개발

```bash
bash plugins/brownfield-navigator/tests/run-all.sh
claude plugin validate plugins/brownfield-navigator
claude --plugin-dir plugins/brownfield-navigator
```

코어 규칙을 더하거나 id를 바꿨다면 두 README의 id 목록도 함께 고칩니다.
````

- [ ] **Step 2: 영어 README 작성**

`README.en.md`

````markdown
# brownfield-navigator

[한국어](README.md) | English

A Claude Code plugin for people who want Claude to **follow their company's conventions and the existing flow of the code** when extending or maintaining a legacy (brownfield) codebase.

Organize the guidance scattered across your project memories into organization, personal, and project profiles. When a session starts, the plugin merges the guide that matches the working directory and injects it. In places that match no profile, such as personal projects, it does nothing.

It is a guide, not an enforcement mechanism. If you want a different approach, Claude follows your lead.

The bundled core rules and the profile templates the harvest skill starts from are written in Korean. Rules are plain Markdown sections, so you can write your own profiles in any language.

## How it works

| Layer | Contents | Location |
|---|---|---|
| Core | Principles for legacy work, independent of company or tools | plugin `skills/brownfield-navigator/SKILL.md` |
| Organization | Company conventions | `~/.claude/brownfield-navigator/orgs/<org>/profile.md` |
| Personal | Your preferences for how Claude works with you | `~/.claude/brownfield-navigator/personal.md` |
| Project | Rules that differ only in a specific repository | `~/.claude/brownfield-navigator/orgs/<org>/projects/<name>.md` |

1. When a session starts, a hook compares the working directory's git remotes and path with each organization profile's match conditions
2. On a match, it merges `## [id] title` sections in the order core, organization, personal, project. A later layer replaces a section with the same id
3. The merged guide and a list of reference files are added to the session context

Keep project-specific facts, such as configuration values and pitfalls, in Claude Code project memory, where you keep them today.

## Installation

```
/plugin marketplace add june20516/brownfield-navigator
/plugin install brownfield-navigator@brownfield-navigator
```

Requirements: Claude Code and bash 3.2 or later. git is needed only for remote conditions.

## First-time setup

Invoke the harvest skill.

```
/brownfield-navigator:harvest-profile
```

If you have accumulated project memories, it collects them, shows organization candidates, walks through classification and conflict resolution, and drafts your profiles. If you have no memories, it asks for an organization name and a repository path and creates a minimal profile that holds just the match conditions. Either way, it writes only what you approve, and it never deletes or edits your memories.

If you would rather write a profile by hand, copy the example in [Profile format](#profile-format) below.

## Verifying it works

The hook runs only when a session starts. So after you create or edit a profile, start a new session or run `/clear` before it takes effect.

The guide goes into Claude's context only; nothing appears on your screen. To check that it arrived, start a session in the target repository and invoke the skill. Claude tells you which organization's guide is in effect and reports any warnings raised while reading your profiles.

```
/brownfield-navigator:brownfield-navigator
```

## Profile format

### Organization profile and project file

```markdown
---
apply: auto
match-remotes:
  - "*[:/]your-org/*"
match-paths:
  - "~/work/your-org/*"
---

## [commit-message] Commit messages

Write commit messages as `type: description TICKET-123`.

**Why:** Matches the existing format of the repository history
```

- `apply`: `auto` (inject rules), `suggest` (one-line hint only), or `off` (inject nothing). It defaults to `auto`, and a project file without it uses the organization's value
- `match-remotes`: bash globs compared with git remote URLs. A trailing `/`, a trailing `.git`, and credentials such as `https://user:token@host` are removed before comparing, and the comparison is case-sensitive. `*your-org/*` also matches `not-your-org`, so put `[:/]` in front as in the example to pin the owner boundary
- `match-paths`: bash globs compared with the working directory or any of its parent directories. A leading `~` expands to your home directory, and the target path is the real path with symbolic links resolved. If any part of the path is a symlink, including your home directory itself, write the real path instead of `~`. Matching is byte-wise, so `?` and `[...]` do not match a single non-ASCII character such as a Korean syllable; use `*` there. A directory pattern with a trailing `/` never matches (`"~/work/your-org/*"`, not `"~/work/your-org/"`). Use this condition if you don't use git
- A profile matches if **any** one pattern in either list matches; the two keys are not combined with AND. To narrow the scope, narrow the patterns themselves
- Lists must use block style. Flow style such as `["a", "b"]` fails to parse, and the file is skipped with a warning. When you use only one of the two keys, write the other as an empty list, `match-paths: []`, rather than leaving it without a value; a key left empty also skips the whole file
- The organization name is the directory name under `orgs/`, and the project name is the file name. Project files are examined only in repositories where an organization profile matched first

### Rule sections

- A rule runs from `## [id] title` to the next `## ` heading. Ids use lowercase letters, digits, and `-`. A `## ` line inside a fenced code block does not count as a heading, so a Markdown example inside a rule won't split the section
- A section with the same id replaces the earlier one, and a new id is added. There are sixteen core rule ids: `guide-stance`, `workflow-skill-conflict`, `delegate-with-guide`, `actual-tooling`, `existing-pattern-first`, `existing-vocabulary`, `comment-density`, `preserve-vs-decide`, `stage-boundary`, `ideal-vs-current`, `respect-user-edits`, `verify-premise`, `structural-evidence`, `doc-conflict`, `spec-import`, `team-boundary`. In the merged guide, each section title ends with its final source, such as `(코어)` for core or `(조직: your-org)` for an organization
- `## ` sections without an id are treated as descriptions and are not merged
- To turn a rule off, delete its section. Wrapping it in an HTML comment (`<!-- -->`) does not disable it

### Personal profile

`personal.md` contains only rule sections, without frontmatter. It applies only when an organization profile matches and a guide is merged.

### Reference files

Put a one-line `description:` in the frontmatter of `orgs/<org>/references/<topic>.md`. Only the path and description go into the session, and Claude reads the file when working on something related.

## Loading the guide manually

Invoke the skill if you started the session in a directory that contains several repositories, or if you want the guide in a repository whose `apply` is `suggest` or `off`. A manual load revives settings you turned off with `off`, so Claude does this only when you ask for it.

```
/brownfield-navigator:brownfield-navigator
```

If you have cloned this repository, you can also run the script directly.

```bash
plugins/brownfield-navigator/bin/compose-guide --manual ~/work/your-org/your-repo
```

## When no guide appears

1. Start a session in the target repository and invoke `/brownfield-navigator:brownfield-navigator`. If no profile matches, Claude says so, and if a profile failed to parse, it shows that warning
2. Check the match conditions. A profile with **no** patterns at all in `match-remotes` and `match-paths` matches nothing, and no warning is raised. A path pattern with a trailing `/` fails just as quietly
3. `match-paths` is compared with the real path, with symbolic links resolved. Run `pwd -P` in the target repository and check it against your pattern
4. Check your frontmatter key names. Unsupported keys are ignored with a warning, so a typo such as `match-remote` shows up as a warning in step 1

## Notes

- Profiles are your own files in `~/.claude/brownfield-navigator/`. Plugin updates don't remove them, but to use them on another machine you need to back them up or sync them yourself. Set the `BROWNFIELD_NAVIGATOR_HOME` environment variable to use a different location
- Subagents don't receive the session-start injection. Following the core rule `[delegate-with-guide]`, Claude includes the relevant rules in its delegation prompts
- If two or more `auto` organizations match one repository, only the first one by name is applied, with a warning
- If two or more project files in one organization match, they are not narrowed down to one the way organizations are: all of them are merged in name order, with a warning. The `apply` value comes from the last file that sets one, so adding a single file can change how the guide is applied
- Claude Code caps hook output at 10,000 characters. The injected guide therefore contains only the key paragraph of each core rule (the full text stays in SKILL.md) and the full text of organization, personal, and project rules. If the total exceeds 9,000 characters, a conditional notice right under the title tells Claude to read the full text if it is still reachable after truncation — but whether the truncated output is saved to a file is up to Claude Code, so staying under 9,000 characters is the safe course. When organization rules grow long, move the detailed explanations into reference files (`references/`)

## Development

```bash
bash plugins/brownfield-navigator/tests/run-all.sh
claude plugin validate plugins/brownfield-navigator
claude --plugin-dir plugins/brownfield-navigator
```

If you add a core rule or rename an id, update the id list in both READMEs as well.
````

- [ ] **Step 3: 줄바꿈 속성 작성**

Windows에서 `core.autocrlf`로 받아도 bash가 읽는 파일이 CRLF로 바뀌지 않게 한다. `run-hook.cmd`는 Windows에서 cmd.exe가 실행하므로 지정하지 않는다.

`.gitattributes`

````gitattributes
# Windows에서 core.autocrlf로 받아도 bash가 읽는 파일은 LF 줄바꿈을 유지
# (CRLF면 스크립트가 실행되지 않고, 규칙 제목 끝에 \r이 남음)
# 훅 스크립트는 Windows 자동 감지를 피하려고 확장자 없는 이름을 쓴다. 새 훅이 추가돼도 덮이도록
# hooks/ 전체를 지정하고, Windows에서 cmd.exe가 실행해야 하는 .cmd 만 git 기본값(autocrlf)에 맡김
plugins/brownfield-navigator/bin/* text eol=lf
plugins/brownfield-navigator/hooks/** text eol=lf
plugins/brownfield-navigator/hooks/**/*.cmd !text !eol
plugins/brownfield-navigator/lib/*.sh text eol=lf
plugins/brownfield-navigator/tests/*.sh text eol=lf
*.md text eol=lf
````

- [ ] **Step 4: README의 코어 규칙 id 목록을 지키는 테스트 작성**

README는 코어 규칙 id 16개를 직접 나열한다. 코어 스킬에서 id가 늘거나 바뀌면 두 README가 조용히 틀린 문서가 되므로 테스트로 막는다.

`plugins/brownfield-navigator/tests/readme.test.sh`

````bash
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
````

- [ ] **Step 5: 전체 테스트와 검증**

실행: `bash plugins/brownfield-navigator/tests/run-all.sh; echo "exit=$?"; claude plugin validate . && claude plugin validate plugins/brownfield-navigator; git check-attr eol -- plugins/brownfield-navigator/bin/compose-guide plugins/brownfield-navigator/hooks/run-hook.cmd README.md`
기대: 테스트 파일 7개 모두 `0개 실패`, 마지막 줄 `테스트 파일 7개 모두 통과`, `exit=0`, 검증 두 번 모두 `✔ Validation passed`, 속성은 `compose-guide: eol: lf`, `run-hook.cmd: eol: unspecified`, `README.md: eol: lf`

- [ ] **Step 6: Commit**

```bash
git add README.md README.en.md .gitattributes plugins/brownfield-navigator/tests/readme.test.sh
git commit -F - <<'EOF'
docs: 설치, 프로필 형식, 사용법을 담은 README(한국어, 영어)와 줄바꿈 속성 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hpd4mB4Q7hB6xWvD76iD5k
EOF
```

---

### Task 12: bran 프로필 작성 (레포 밖, 커밋 없음)

spec 9장 내용이다. 파일은 `~/.claude/brownfield-navigator/`에 쓰며 레포에 커밋하지 않는다.

spec 14장 확인 결과: claude-sync의 동기화 대상은 `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/CLAUDE.md`, 플러그인 목록, MCP 설정뿐이라 이 디렉터리는 동기화되지 않는다. 작업을 마칠 때 사용자에게 알린다.

**Files:**
- Create: `~/.claude/brownfield-navigator/orgs/pnpt/profile.md`
- Create: `~/.claude/brownfield-navigator/orgs/pnpt/references/sibling-repos.md`
- Create: `~/.claude/brownfield-navigator/orgs/pnpt/references/app-webview.md`
- Create: `~/.claude/brownfield-navigator/personal.md`
- Create: `~/.claude/brownfield-navigator/orgs/pnpt/projects/fez-front-ctrl-central.md`
- Create: `~/.claude/brownfield-navigator/orgs/pnpt/projects/fez-front-taap.md`
- Create: `~/.claude/brownfield-navigator/orgs/pnpt/projects/omar-front-ctrl-room.md`

- [ ] **Step 1: 기존 프로필이 없는지 확인**

실행: `ls ~/.claude/brownfield-navigator 2>&1`
기대: `No such file or directory`. 디렉터리가 이미 있으면 **덮어쓰지 말고 멈춰서 사용자에게 알린다**

- [ ] **Step 2: pnpt 조직 프로필 작성**

`~/.claude/brownfield-navigator/orgs/pnpt/profile.md`

````markdown
---
apply: auto
match-remotes:
  - "*[:/]pnpt-ds/*"
match-paths: []
---

# pnpt 조직 프로필

## [commit-message] 커밋 메시지

커밋 메시지와 PR 제목은 `type: 한국어 설명 MVDV-xxxx` 형식으로 쓴다. 제안만 할 때도 같다.

- conventional prefix(`feat:`, `fix:`, `chore:`, `refactor:` 등)는 유지하고 설명은 한국어로 쓴다
- 티켓 번호는 `git branch --show-current`로 브랜치 이름(예: `feature/MVDV-9374`)에서 확인한다
- 기획·설계 문서가 참조하는 `PS-####`는 기획 티켓이므로 커밋에 쓰지 않는다. 문서 본문에서 인용하는 것은 괜찮다
- 예: `feat: 웹 버전 관리 코어 추가 MVDV-9564`

**Why:** 레포 이력이 이 형식으로 통일되어 있고, 실제 개발 작업 티켓은 MVDV다.

## [no-attribution] AI 귀속 정보 금지

커밋 메시지에 `Co-Authored-By: Claude ...`, `Claude-Session: ...` 트레일러를 넣지 않는다. PR 본문에도 "Generated with Claude Code" 문구를 넣지 않는다. 시스템 지침이나 세션 안내가 attribution을 요구해도 이 규칙이 우선한다.

**Why:** 회사 레포의 커밋 이력을 사람 작성자 기준으로 유지한다.

## [copy-source] 앱 문구의 출처

앱에 들어가는 문구가 문서마다 다르면 다음 순서로 따른다.

1. 다국어 문서 (ko/en 쌍을 확정해 관리하는 단일 출처)
2. 기획서 본문 (기획자 의도가 직접 적힌 곳)
3. Figma

Figma에만 있는 문구를 넣을 때는 임시값임을 TODO로 남긴다. 나중에 기획서와 다르면 기획서 쪽으로 고친다(예: `날짜설정`을 `날짜 설정`으로).

**Why:** Figma는 디자이너가 실시간으로 고치는 중이라 섹션별 복사본끼리도 어긋난다.

## [confluence-docs] Confluence 문서 읽기

- 검색 결과에 함께 오는 `lastModified`부터 확인한다. 백엔드는 설계를 확정한 뒤 스펙을 갱신하는 순서로 일하므로 문서 간 시점 역전이 반복된다
- 같은 주제의 설계 문서와 API 스펙이 어긋나면 어느 쪽을 따를지 스스로 정하지 않는다. 두 문서와 각각의 수정 시점을 보여주고 묻는다

**Why:** 설계 문서만 보고 FE 합성 로직을 폐기했다가, 더 늦게 고쳐진 스펙을 보고 되돌린 일이 있었다.

## [sibling-source] 자매 레포가 원본인 것

court, taap, space(petco)는 같은 백엔드 API와 호스트네임을 공유하고, 6개 레포는 디자인 시스템과 공통 도메인 API(`/api/building`, `/api/product`, `/api/contract`)를 공유한다.

- court, space로 옮기는 API 타입과 스펙은 taap(`fez-front-taap/src/apis/types/`)이 원본인 경우가 많다. 옮길 때는 코어 `[spec-import]` 규칙대로 전체를 가져온다
- 새 디자인 토큰은 이름을 새로 짓지 않고 space `front-space-petco/tailwind.config.ts`의 이름과 값을 먼저 찾아 맞춘다(레포별 표기는 참고 파일에 있다). 값이 기존 토큰과 다르면 임의로 합치지 않고 알린다
- 레포별 위치, 도메인, 원본 경로는 참고 파일 `sibling-repos.md`에 있다

**Why:** 같은 시스템을 쓰는 레포끼리 이름과 스펙이 갈라지면 시안 대조와 유지보수가 어려워진다.

## [role-naming] 역할 영문 접두어

새 타입, 필드, 변수에 역할을 붙일 때 다음 접두어를 쓴다 (2026-08-04 확정, PNPT 프로덕트 용어 대사전 등재).

| 역할 | 접두어 |
|---|---|
| 회원 | `member_` |
| 이용자, 재실자 | `user_` |
| 이용자 마스터, 입주사 관리자 | `tenant_manager_` |
| Ctrl.room 파트너 회원, 빌딩 관리자 | `partner_manager` |

표는 용어 기준이고, 코드에서는 그 레포의 케이싱 관례를 따른다(TS 필드는 `tenantManagerApprovalStatus`처럼). 기존 이름은 전 계층을 동시에 바꾸는 비용 때문에 그대로 두고, 신규 필드와 바꿀 수 있는 것부터 적용한다.

**Why:** 기존 `member_`가 회원과 이용자를 섞어 가리켜 승인 주체 이름이 모호했다.

## [file-naming] 파일 이름

파일 이름에 디자인 스타일 이름(Material 등)이나 구현 기술 이름을 넣지 않고, 하는 일을 서술하는 이름을 쓴다(`MaterialSpinner` → `SpinnerRenderer`).

**Why:** 구현을 바꾸면 기술 이름이 먼저 낡는다.

## [tests] 테스트 코드

테스트 코드를 커밋하는 관례가 없다. 테스트 파일을 새로 만들지는 이 가이드의 프로젝트 규칙을 따르고, 그 레포 규칙이 없으면 만들기 전에 묻는다.

**Why:** 테스트 설정이 있어 보여도 실제로는 테스트를 유지하지 않는 레포가 대부분이다.

## [comment-style] 주석 형식

- 명사형으로 끝낸다(`~고정`, `~필요`, `~없음`, `~함`). `~한다`, `~합니다` 같은 서술형으로 끝내지 않는다
- 끝에 마침표를 찍지 않는다
- 장식용 특수문자(`—`, `→`, `·`, `✓`)를 쓰지 않고 쉼표나 괄호로 처리한다
- 설계 근거는 문서가 폐기돼도 필요한 "왜"만 한두 문장으로 코드에 남긴다. 배경 설명이나 규칙 절은 spec, plan 문서의 몫이다
- 예: `호출 전에 lastTickAt을 갱신해야 한다.`는 `호출 전 lastTickAt 갱신 필요`로, `잔여 ms — 예약 없으면 -1`은 `잔여 ms (예약 없으면 -1)`로 쓴다

**Why:** 기존 주석이 이 형식으로 통일되어 있어 서술형 문장과 마침표가 섞이면 톤이 어긋난다.

## [korean-wording] 한국어 어휘

주석, 토스트, 라벨, 문서에서 은유와 음차 외래어를 피하고 프로젝트가 이미 쓰는 평이한 말을 쓴다. 영어 식별자(`promoteIfStarter` 등)는 괜찮다.

| 쓰지 않음 | 대신 |
|---|---|
| 무장, arming | 발동 대기 |
| 게이트, gating | 필수 조건 |
| 부착 | 첨부 |
| 승격, 승급 | 하는 일을 그대로 서술 (`STARTER => MEMBER 처리`) |
| 봉투 (응답 구조 비유) | "응답에 meta가 있다"처럼 그대로 서술 |
| 계측 | 관측, 수집, 또는 하는 일을 서술 |

**Why:** 군사 은유나 음차 외래어는 팀의 다른 용어와 톤이 맞지 않고, 표준 번역어라도 팀이 모르면 이름값을 못 한다.
````

- [ ] **Step 3: 참고 파일 작성 (자매 레포 지도)**

`~/.claude/brownfield-navigator/orgs/pnpt/references/sibling-repos.md`

````markdown
---
description: pnpt 자매 레포의 역할, 공유 백엔드와 호스트, 환경별 도메인, 타입과 토큰의 원본 경로
---

# pnpt 자매 레포 지도

## 레포

| 레포 | 경로 | 역할 |
|---|---|---|
| fez-front-court | `~/repositories/fez-front-court` | 웹. CRA 기반 React, `react-router-dom`, Recoil과 `useApiOperation` 훅(react-query 미사용). 경로는 `/front/court/...`. 단일 코드베이스를 hostname에 따라 appType(Taap, STPM, IFC)별로 나눠 배포 |
| fez-front-taap | `~/repositories/fez-front-taap` | React Native(Expo) 모바일 앱. 셀프 방문 등록, 방문자 승인 등을 WebView로 court와 space 페이지에 위임. 타입과 API 스펙의 원본인 경우가 많음 |
| front-space-petco | `~/repositories/front-space-petco` | Next.js 14 App Router 웹. `NEXT_PUBLIC_BASE_PATH='/front/space'`로 court와 같은 호스트에서 경로로 분리. 디자인 토큰 네이밍의 원본(`tailwind.config.ts`) |
| front-taap-stpm | `~/repositories/front-taap-stpm` | STPM(삼성전자) 전용 모바일 앱. STPM 약관 코드와 링크의 원본 |
| omar-front-ctrl-room | `~/repositories/omar-front-ctrl-room` | Ctrl.room 웹 |
| fez-front-ctrl-central | `~/repositories/fez-front-ctrl-central` | Ctrl.central 웹 (CRA) |

court, taap, space는 같은 백엔드 API(`/api/court/...`)와 호스트네임을 공유한다.

## 원본 경로

- taap 타입 정의: `src/apis/types/{contractType,partnerType,commonType,fileStorage}.ts`
- taap API 함수: `src/apis/{contract,partner,visitor}.ts`
- space 셀프 방문 승인 화면: `src/app/visitor/selfRegist/`. court에서 이동할 때는 같은 도메인이므로 `window.location.href = '/front/space/visitor/selfRegist'`
- space 디자인 토큰: `tailwind.config.ts`의 colors (`system-blue-01`, `system-blue-01-bg`(7%), `system-blue-01-border`(20%) 형태). taap은 snake_case라 `system_blue_01_bg`로 옮긴다

## 환경별 도메인

| 환경 | 도메인 |
|---|---|
| dev | `dev-court.pnpt.net` (court는 `/front/court/...`, space는 `/front/space/...`) |
| stg | `stg-court.pnpt.net` |
| prod Taap | `taapspace.kr` |
| prod STPM | `stpm.pnpt.space` |
| prod IFC | `ifc.pnpt.space` |
````

- [ ] **Step 4: 참고 파일 작성 (앱과 웹뷰 규약)**

`~/.claude/brownfield-navigator/orgs/pnpt/references/app-webview.md`

````markdown
---
description: taap 앱과 웹뷰(court, space) 사이의 규약. lang 쿼리 파라미터, window.taap.canGoBack 동기화 함정
---

# 앱과 웹뷰 사이의 규약

## 언어 전달: `lang=ko|en` 쿼리 파라미터

- fez-front-taap 앱이 웹뷰에 사용 언어를 넘기는 규약은 `lang=ko|en` 쿼리 파라미터다. 값은 `useI18n().locale`(`resolveAvailableLocale`로 정규화된 `ko` 또는 `en`)
- 선례: My 계약 웹뷰 4곳(`MyContractListScreen`, `MyContractDetailScreen`, `MyContractUserScreen`, `MyContractBillDetailScreen`), 커밋 `b9b21573`(MVDV-9056)
- 예외: 인증(로그인) 웹뷰만 `locale=<기기 원본 languageCode>`(`src/functions/auth.ts`). OAuth 서버로 가는 별개 경로이므로 따라가지 않는다
- 앱은 기기 OS locale만 본다. 앱 안에 언어 선택 UI는 없고, 지원하지 않는 언어는 `en`으로 대체한다
- 웹의 `useLang`은 파라미터가 없으면 `ko`이므로 구버전 앱에서는 국문이 나온다. front-space-petco의 `useLang`은 이미 `?lang=`을 읽는다

## `window.taap.canGoBack` 동기화

taap의 `src/components/WebViewCommon.tsx`가 주입하는 `PageHistoryInjectCode`는 `history.back()`을 패치한다. `window.taap.canGoBack`이 falsy면 native로 goBack을 보내 웹뷰 자체를 닫는다. 아래 세 갱신 경로가 모두 살아 있어야 딥링크 진입, SPA 내비게이션, Android 조합에서 깨지지 않는다.

1. 주입 시점 초기화: `window.taap.canGoBack = window.history.length > 1`. 진입 페이지의 useEffect가 주입보다 먼저 pushState를 끝내는 경우를 잡는다
2. native `onNavigationStateChange`: 전체 페이지 이동과 iOS SPA pushState에는 발화하지만 Android SPA pushState에는 믿을 수 없다
3. 주입 코드가 보내는 `type: "navigationStateChange"` postMessage를 native 메시지 핸들러에서 처리할 때도 주입: Android SPA 경로의 유일한 후속 동기화 통로

**함정:** iOS만 테스트하면 2번 경로가 가려 줘서 통과하고, Android에서만 "뒤로가기를 누르면 웹뷰가 바로 닫힘"으로 나타난다. 웹뷰 콘텐츠 쪽(space 등)에서는 우회가 어렵고 taap 쪽 수정이 필요하다.
````

- [ ] **Step 5: 개인 프로필 작성**

`~/.claude/brownfield-navigator/personal.md`

````markdown
# bran 개인 프로필

## [commit-by-user] 커밋은 직접

- 사용자가 명시적으로 요청하지 않으면 `git commit`을 실행하지 않는다. 계획 실행 중이나 task 완료 시점처럼 커밋이 자연스러워 보여도 하지 않는다
- 커밋할지 묻지도 않는다
- 서브에이전트 프롬프트에 커밋 단계를 넣지 않는다
- 커밋 메시지는 제안만 한다

**Why:** 변경을 직접 검토한 뒤 커밋 단위와 메시지를 정한다.

## [workflow-docs] 워크플로우 산출물

`docs/suberpowers/specs/`, `docs/suberpowers/plans/` 같은 spec, plan 문서는 작성하되 커밋하지 않는다. 커밋 단위를 제안할 때 `docs/`를 빼고, `git status`에 `?? docs/`가 남아 있어도 누락으로 보고하지 않는다.

**Why:** 작업을 진행하기 위한 문서이지 레포에 남길 자산이 아니다.

## [one-task-then-report] 한 작업씩 보고

작업 단위 하나를 끝내면 변경 파일과 요지를 보고하고 멈춘다. 다음 작업으로 넘어가지 않는다.

작업 트리에 커밋하지 않은 이전 작업의 변경이 남아 있으면, 새 작업은 가능한 한 다른 파일에서 하고 보고할 때 "이번 작업 파일 목록"을 따로 적는다.

**Why:** 한 단위씩 리뷰하고 스테이징하기 위함이다.

## [capture-location] 화면 캡처 저장 위치

작업 결과 화면 캡처는 `~/Desktop/test screen/<티켓번호>/`(예: `MVDV-9736`) 하위 디렉터리를 만들어 저장한다. 스크래치 디렉터리에 두지 않는다. 해당 화면의 데이터가 없으면 mock으로 상황을 만들어 캡처해도 된다.

**Why:** 티켓 번호별로 모아 두어야 나중에 찾는다.

## [simple-git-guidance] git 명령 안내

사용자가 직접 실행할 git 명령을 안내할 때 지킨다.

- 가장 단순한 선택지를 먼저 주고, 이력 재작성은 두 번째 안으로 둔다. 손으로 파일을 옮기게 하지 않고 불가피하면 스크립트 하나로 준다
- rebase, reset, fixup은 스크래치에 복제한 레포를 같은 상태(미커밋 변경, 미추적 파일, `user.email`과 `user.signingkey`까지)로 만들어 끝까지 실행해 보고, 커밋 diff와 작업 트리 상태를 확인한 뒤 안내한다

**Why:** 검증 없이 안내한 리베이스가 실패했고, 파일을 손으로 옮기는 단계에서 테스트 파일 이름이 뒤바뀌었다.
````

- [ ] **Step 6: 프로젝트 파일 작성 (fez-front-ctrl-central)**

`~/.claude/brownfield-navigator/orgs/pnpt/projects/fez-front-ctrl-central.md`

````markdown
---
match-remotes:
  - "*[:/]pnpt-ds/fez-front-ctrl-central"
---

# fez-front-ctrl-central

## [tests] 테스트 코드

테스트 파일을 새로 만들지 않는다. TDD 스킬이 테스트를 요구해도 구현과 `tsc --noEmit`, CRA 빌드 검증으로 대신한다.

**Why:** `package.json`에 `@testing-library/*`와 `react-scripts test`가 있지만 실제로는 테스트를 쓰지 않는 레포다.
````

- [ ] **Step 7: 프로젝트 파일 작성 (fez-front-taap)**

`~/.claude/brownfield-navigator/orgs/pnpt/projects/fez-front-taap.md`

````markdown
---
match-remotes:
  - "*[:/]pnpt-ds/fez-front-taap"
---

# fez-front-taap

## [tests] 테스트 코드

테스트 코드를 유지하지 않는다(보일러플레이트 `__tests__/App-test.tsx`만 있고 `test` 스크립트 없음). 정적 검증은 `npx tsc --noEmit`과 `npx prettier --check <파일>`로 하고, 동작은 기기에서 직접 확인한다.

**Why:** 테스트를 유지하지 않는 레포에 테스트 파일을 두면 관리되지 않은 채 남는다.

## [workflow-docs] 워크플로우 산출물

`docs/suberpowers/`의 spec, plan 문서는 커밋하지 않고, 구현이 끝나면 삭제한다. 남아 있는 `?? docs/`는 누락으로 보고하지 않는다.

**Why:** 구현을 위한 임시 산출물이며 레포 히스토리에 남기지 않는 것이 이 레포의 원칙이다.
````

- [ ] **Step 8: 프로젝트 파일 작성 (omar-front-ctrl-room)**

`~/.claude/brownfield-navigator/orgs/pnpt/projects/omar-front-ctrl-room.md`

````markdown
---
match-remotes:
  - "*[:/]pnpt-ds/omar-front-ctrl-room"
---

# omar-front-ctrl-room

## [tests] 테스트 코드

테스트는 작업 검증용으로 작성하고 실행하되 커밋하지 않는다. `git add`에 `*.test.ts`를 넣지 않고, `git status`를 깨끗하게 하려면 로컬 전용인 `.git/info/exclude`를 쓴다.

**Why:** 이 레포에는 테스트를 커밋하는 관례가 없다.

## [comment-style] 주석 형식

주석은 과하게 쓰기 쉬우므로 줄인다.

- 짧으면 명사형(`~함`, `~음`), 설명이 필요하면 평서형(`~한다`)으로 쓴다. 한 문장에 하나씩 쓴다
- 코드나 표, 파일 헤더가 이미 말한 것을 다시 쓰지 않는다. `.catch(() => [])` 옆에 "조회가 실패해도 목록은 그대로 보여준다"를 달지 않는다
- 설계 배경, 규칙 절, 구조 표시(`## 공개 인터페이스` 같은 것)는 넣지 않는다
- 결과를 나열하지 말고 목적을 한 마디로 쓴다 (`외부로 노출되지 않도록 non-enumerable 로 저장`)
- 이 파일을 고치는 사람이 실제로 밟는 함정은 남긴다 (예: `라우트 목록으로 routes.ts 금지, 페이지 컴포넌트 97개를 끌고 옴`)
- 낯선 용어는 괄호로 실제 동작을 한 번만 적는다 (`캡처(발송)`)
- 장식용 특수문자(`—`, `→`, `·`, `✓`)를 쓰지 않는 조직 규칙은 그대로 지킨다

**Why:** 사용자가 `src/utils/sentry/meta.ts`, `report.ts`를 직접 정리해 준 형태가 기준이다.
````

- [ ] **Step 9: 실제 레포 매칭 확인**

실행:

```bash
CG=plugins/brownfield-navigator/bin/compose-guide
for d in ~/repositories/fez-front-taap ~/repositories/omar-front-ctrl-room ~/repositories/front-space-petco ~/repositories/fez-front-ctrl-central ~/repositories/fez-front-court ~/repositories/front-taap-stpm ~/repositories/coffee-order ~/personal/tagatigi ~/repositories ~/repositories/fez-front-taap/src; do
  out="$(bash "$CG" "$d")"
  printf '%s | %s | %s | 경고 %s\n' "$(basename "$d")" \
    "$(printf '%s\n' "$out" | grep -m1 '^- 조직' || printf '%s\n' '주입 없음')" \
    "$(printf '%s\n' "$out" | grep -m1 '^- 프로젝트 파일' || printf '%s\n' '-')" \
    "$(printf '%s\n' "$out" | grep -c '^## brownfield-navigator 경고')"
done
```

기대:

```
fez-front-taap | - 조직: pnpt (근거: remote git@github.com:pnpt-ds/fez-front-taap) | - 프로젝트 파일: fez-front-taap | 경고 0
omar-front-ctrl-room | - 조직: pnpt (근거: remote git@github.com:pnpt-ds/omar-front-ctrl-room) | - 프로젝트 파일: omar-front-ctrl-room | 경고 0
front-space-petco | - 조직: pnpt (근거: remote git@github.com:pnpt-ds/front-space-petco) | - | 경고 0
fez-front-ctrl-central | - 조직: pnpt (근거: remote git@github.com:pnpt-ds/fez-front-ctrl-central) | - 프로젝트 파일: fez-front-ctrl-central | 경고 0
fez-front-court | - 조직: pnpt (근거: remote git@github.com:pnpt-ds/fez-front-court) | - | 경고 0
front-taap-stpm | - 조직: pnpt (근거: remote git@github.com:pnpt-ds/front-taap-stpm) | - | 경고 0
coffee-order | 주입 없음 | - | 경고 0
tagatigi | 주입 없음 | - | 경고 0
repositories | 주입 없음 | - | 경고 0
src | - 조직: pnpt (근거: remote git@github.com:pnpt-ds/fez-front-taap) | - 프로젝트 파일: fez-front-taap | 경고 0
```

- [ ] **Step 10: 교체 결과 확인**

실행: `bash plugins/brownfield-navigator/bin/compose-guide ~/repositories/fez-front-taap | grep -E '^## \[(tests|workflow-docs|comment-style|commit-by-user)\]'`
기대:

```
## [tests] 테스트 코드 (프로젝트: fez-front-taap)
## [comment-style] 주석 형식 (조직: pnpt)
## [commit-by-user] 커밋은 직접 (개인)
## [workflow-docs] 워크플로우 산출물 (프로젝트: fez-front-taap)
```

- [ ] **Step 11: 세션 주입 길이 확인**

Claude Code는 훅 출력을 10,000자로 제한한다. bran 프로필로 만든 가이드가 예산(9,000자) 안인지 확인한다.

실행:

```bash
for d in ~/repositories/fez-front-taap ~/repositories/omar-front-ctrl-room ~/repositories/front-space-petco ~/repositories/fez-front-ctrl-central ~/repositories/fez-front-court ~/repositories/front-taap-stpm; do
  printf '{"cwd":"%s"}' "$d" | bash plugins/brownfield-navigator/hooks/session-start \
    | python3 -c 'import json, sys; context = json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]; print(sys.argv[1], len(context), "안내 있음" if "> 이 가이드는" in context else "안내 없음")' "$(basename "$d")"
done
```

기대: 6줄 모두 길이가 9,000 이하이고 `안내 없음`. 넘는 레포가 있으면 멈추고 사용자에게 알린다(조직 규칙 문장을 줄이거나 참고 파일로 옮길지 결정 필요)

---

### Task 13: 실제 세션 주입 확인 (`--plugin-dir`, 커밋 없음)

설치하지 않고 `--plugin-dir`로 플러그인을 불러와 헤드리스 세션에서 훅 주입을 확인한다. 작업 디렉터리를 바꾸지 않도록 서브셸에서 실행한다.

- [ ] **Step 1: 사내 레포와 개인 레포에서 확인**

실행:

```bash
PLUGIN_DIR="$PWD/plugins/brownfield-navigator"
PROMPT="세션 컨텍스트에 '# brownfield-navigator 가이드'로 시작하는 내용이 있으면 그 안의 '- 조직:'으로 시작하는 줄과 '- 프로젝트 파일:'로 시작하는 줄을 그대로 출력하라. 없으면 NONE 한 단어만 출력하라. 도구는 쓰지 마라."
for d in ~/repositories/fez-front-taap ~/repositories/coffee-order ~/personal/tagatigi; do
  echo "=== $(basename "$d")"
  (cd "$d" && claude -p --model claude-haiku-4-5-20251001 --plugin-dir "$PLUGIN_DIR" "$PROMPT")
done
```

기대:

```
=== fez-front-taap
- 조직: pnpt (근거: remote git@github.com:pnpt-ds/fez-front-taap)
- 프로젝트 파일: fez-front-taap
=== coffee-order
NONE
=== tagatigi
NONE
```

---

### Task 14: 설치와 사용자 확인 (사용자 승인 필요)

사용자 설정을 바꾸거나 외부에 공개하는 단계이므로 각 Step 전에 사용자에게 확인받는다.

- [ ] **Step 1: 로컬 마켓플레이스로 설치 (사용자 승인 후)**

실행: `claude plugin marketplace add ~/personal/brownfield-navigator && claude plugin install brownfield-navigator@brownfield-navigator`
기대: 마켓플레이스 추가와 플러그인 설치 성공 메시지

- [ ] **Step 2: 수동 호출 확인 (사용자가 대화형 세션에서 실행)**

사용자에게 안내한다: `~/repositories`에서 새 세션을 시작하고 `/brownfield-navigator:brownfield-navigator fez-front-taap 작업할 거야`를 입력한다.
기대: Claude가 `compose-guide --manual`을 실행하고 pnpt 조직 가이드를 적용한다고 한 줄로 알린다

- [ ] **Step 3: 수집 스킬 재실행 확인 (사용자가 대화형 세션에서 실행)**

사용자에게 안내한다: `/brownfield-navigator:harvest-profile pnpt`를 실행한다.
기대: 기존 프로필을 덮어쓰지 않고, 빠진 규칙이 있으면 diff로 제안하며, 정리 후보 메모리 목록(예: 6개 레포의 `never-base-on-shared-remote-branch.md`는 전역 CLAUDE.md와 중복)을 보고한다

- [ ] **Step 4: GitHub 공개 (사용자 승인 후)**

사용자에게 공개 범위(public 또는 private)를 확인받은 뒤 `june20516/brownfield-navigator` 레포를 만들고 push한다. 개인 계정 push는 HTTPS와 gh 토큰을 쓴다.

실행: `gh repo create june20516/brownfield-navigator --<사용자가 고른 공개 범위: public 또는 private> --source . --push`
기대: 레포 생성과 `main` push 성공. 이후 `/plugin marketplace add june20516/brownfield-navigator`로 설치하면 `${CLAUDE_PLUGIN_ROOT}`가 캐시 경로로 바뀌므로 Task 13을 한 번 더 확인한다

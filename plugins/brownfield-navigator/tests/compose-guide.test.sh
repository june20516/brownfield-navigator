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

# 출력은 버리고 종료 코드만 확인 (compose-guide 의 종료 코드는 항상 0)
assert_compose_guide_exit_zero() {
  local label="$1"
  shift
  run_compose_guide "$@" >/dev/null 2>&1
  assert_equals 0 "$?" "$label"
}

# bin/compose-guide 의 count_characters 와 같은 방식으로 파일의 UTF-8 문자 수를 셈
count_output_characters() {
  LC_ALL=C tr -d '\200-\277' < "$1" | wc -c | tr -d ' '
}

# 규칙 본문 길이만 다른 acme 조직 프로필을 씀. 가이드 전체 길이를 원하는 값에 맞출 때 쓴다
write_acme_profile_with_body_length() {
  local body_length="$1" body
  body="$(awk -v goal="$body_length" 'BEGIN { for (i = 0; i < goal; i++) printf "가" }')"
  write_lines "$TEST_TMP/profiles/orgs/acme/profile.md" \
    "---" "match-remotes:" '  - "*acme/*"' "---" \
    "## [long-rule] 긴 규칙" "$body"
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

test_budget_boundary_is_inclusive() {
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  # 본문 길이를 1자 늘리면 가이드도 1자 길어지므로, 짧은 본문으로 한 번 재서 정확히 9,000자가 되는 길이를 구한다
  local probe_body_length=100 probe_length exact_body_length
  write_acme_profile_with_body_length "$probe_body_length"
  run_compose_guide "$TEST_TMP/app" > "$TEST_TMP/probe-output"
  probe_length="$(count_output_characters "$TEST_TMP/probe-output")"
  exact_body_length=$((probe_body_length + 9000 - probe_length))

  write_acme_profile_with_body_length "$exact_body_length"
  run_compose_guide "$TEST_TMP/app" > "$TEST_TMP/exact-output"
  assert_equals 9000 "$(count_output_characters "$TEST_TMP/exact-output")" "예산 경계에 정확히 맞춘 가이드"
  assert_not_contains "$(cat "$TEST_TMP/exact-output")" "> 이 가이드는" "정확히 9,000자면 안내 없음"

  write_acme_profile_with_body_length "$((exact_body_length + 1))"
  assert_contains "$(run_compose_guide "$TEST_TMP/app")" "> 이 가이드는 9001자로" "9,001자면 안내"
}

test_exit_code_is_always_zero() {
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  assert_compose_guide_exit_zero "프로필 홈이 없어도 0" "$TEST_TMP/app"
  write_org_profile acme "match-remotes:" '  - "*acme/*"'
  assert_compose_guide_exit_zero "가이드를 출력해도 0" "$TEST_TMP/app"
  write_lines "$TEST_TMP/profiles/orgs/broken/profile.md" "apply: auto"
  assert_compose_guide_exit_zero "파싱에 실패해 경고를 남겨도 0" "$TEST_TMP/app"
  assert_compose_guide_exit_zero "없는 대상 디렉터리도 0" "$TEST_TMP/missing"
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

  write_org_profile delta "match-remotes:" '  - "*delta/*"'
  write_project_file delta app "apply: off" "match-remotes:" '  - "*delta/app"' -- "## [delta-app-rule] 델타 앱 규칙" "본문"
  make_git_repo "$TEST_TMP/delta-app" "git@github.com:delta/app.git"
  assert_empty "$(run_compose_guide "$TEST_TMP/delta-app")" "프로젝트 off는 기본 호출에서 출력 없음"
  assert_contains "$(run_compose_guide --manual "$TEST_TMP/delta-app")" "## [delta-app-rule] 델타 앱 규칙 (프로젝트: app)" "--manual은 프로젝트 off도 병합"
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

test_warns_on_profile_without_match_conditions() {
  write_lines "$TEST_TMP/profiles/orgs/acme/profile.md" \
    "---" "apply: auto" "match-paths: []" "---" "" \
    "## [acme-rule] acme 규칙" "acme 규칙 본문"
  write_org_profile beta "match-remotes:" '  - "*beta/*"'
  write_project_file beta no-condition "apply: auto" -- "## [no-condition-rule] 조건 없는 규칙" "본문"
  make_git_repo "$TEST_TMP/beta-app" "git@github.com:beta/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/beta-app")"
  assert_contains "$output" "건너뜀 $TEST_TMP/profiles/orgs/acme/profile.md: 매칭 조건 없음" "조직 프로필의 매칭 조건 없음 경고"
  assert_contains "$output" "건너뜀 $TEST_TMP/profiles/orgs/beta/projects/no-condition.md: 매칭 조건 없음" "프로젝트 파일의 매칭 조건 없음 경고"
  assert_not_contains "$output" "no-condition-rule" "매칭 조건이 없는 프로젝트 파일은 병합하지 않음"
  assert_contains "$output" "## [beta-rule] beta 규칙 (조직: beta)" "매칭 조건이 있는 조직은 계속 병합"
}

test_warns_when_rule_sections_are_dropped() {
  write_lines "$TEST_TMP/profiles/orgs/acme/profile.md" \
    "---" "match-remotes:" '  - "*acme/*"' "---" "" \
    "## [Acme-Rule] 대문자 id" "대문자 본문" \
    "## [acme-rule] 정상 id" "정상 본문"
  write_lines "$TEST_TMP/profiles/personal.md" "---" "## [my-habit] 내 습관" "습관 본문"
  make_git_repo "$TEST_TMP/app" "git@github.com:acme/app.git"
  local output
  output="$(run_compose_guide "$TEST_TMP/app")"
  assert_contains "$output" "$TEST_TMP/profiles/orgs/acme/profile.md: id 형식([a-z0-9-]+)이 아닌 규칙 헤딩 무시: ## [Acme-Rule] 대문자 id" "id 형식이 아닌 헤딩 경고"
  assert_contains "$output" "$TEST_TMP/profiles/personal.md: frontmatter가 닫히지 않아 규칙을 읽지 못함" "닫히지 않은 frontmatter 경고"
  assert_not_contains "$output" "my-habit" "닫히지 않은 frontmatter의 규칙은 병합되지 않음"
  assert_contains "$output" "## [acme-rule] 정상 id (조직: acme)" "형식에 맞는 규칙은 계속 병합"
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
run_test test_budget_boundary_is_inclusive
run_test test_exit_code_is_always_zero
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
run_test test_warns_on_profile_without_match_conditions
run_test test_warns_when_rule_sections_are_dropped
run_test test_invalid_utf8_in_profile_keeps_full_guide
run_test test_unsupported_key_warning_with_guide
run_test test_two_auto_orgs_apply_first_only
run_test test_lists_references
finish_tests

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

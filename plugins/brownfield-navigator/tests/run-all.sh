#!/usr/bin/env bash
# 모든 테스트 파일을 실행. 하나라도 실패하면 종료 코드 1
# 사용법: bash plugins/brownfield-navigator/tests/run-all.sh

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)"
overall_status=0
for test_file in "$TESTS_DIR"/*.test.sh; do
  [ -f "$test_file" ] || continue
  "$BASH" "$test_file" || overall_status=1
  printf '\n'
done
exit "$overall_status"

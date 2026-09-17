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

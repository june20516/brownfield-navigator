# hooks/hooks.json 설정 검사 (JSON 파싱에 python3 사용)
# Windows 에서 훅 기본 셸이 PowerShell 이면 "경로" 인자 형태의 command 가 파싱 오류로 실패하므로 bash 를 명시해야 함
. "$(cd "$(dirname "$0")" && pwd -P)/test-helpers.sh"

test_command_hooks_declare_bash_shell() {
  local output
  output="$(python3 - "$PLUGIN_ROOT/hooks/hooks.json" <<'PY' 2>&1
import json
import sys

with open(sys.argv[1], encoding="utf-8") as hooks_file:
    config = json.load(hooks_file)

for event_name, matchers in config["hooks"].items():
    for matcher in matchers:
        for hook in matcher["hooks"]:
            if hook.get("type") == "command" and hook.get("shell") != "bash":
                print(f"{event_name}: shell={hook.get('shell')}")
PY
)"
  assert_empty "$output" "command 훅은 모두 shell 을 bash 로 지정"
}

run_test test_command_hooks_declare_bash_shell
finish_tests

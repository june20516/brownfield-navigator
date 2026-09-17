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

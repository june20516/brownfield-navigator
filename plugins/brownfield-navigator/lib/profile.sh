# 프로필 파일 읽기: frontmatter 파싱, 참고 파일 description 추출
# bash 3.2 호환

# 조직 프로필과 프로젝트 파일의 frontmatter를 한 줄에 하나씩 출력
#   apply=<auto|suggest|off>
#   remote=<패턴>
#   path=<패턴>
#   warning=<메시지>  파일은 계속 사용
#   error=<메시지>    파싱 실패, 파일을 쓰지 않음
parse_profile_frontmatter() {
  local profile_file="$1"
  awk '
    function trim(text) {
      sub(/^[[:space:]]+/, "", text)
      sub(/[[:space:]]+$/, "", text)
      return text
    }
    function strip_comment(text) {
      sub(/[[:space:]]+#.*$/, "", text)
      return text
    }
    function fail(message) {
      print "error=" message
      failed = 1
      exit
    }
    NR == 1 {
      if ($0 != "---") fail("frontmatter 없음 (첫 줄이 ---가 아님)")
      in_frontmatter = 1
      next
    }
    in_frontmatter {
      if ($0 == "---") { closed = 1; exit }
      if ($0 ~ /^[[:space:]]*(#.*)?$/) next
      if ($0 ~ /^[[:space:]]*-[[:space:]]/) {
        if (list_kind == "") fail("어느 키의 리스트 항목인지 알 수 없음: " trim($0))
        item = $0
        sub(/^[[:space:]]*-[[:space:]]+/, "", item)
        item = trim(strip_comment(item))
        if (item ~ /^".*"$/) item = substr(item, 2, length(item) - 2)
        if (item != "") print list_kind "=" item
        next
      }
      if (match($0, /^[A-Za-z0-9_-]+:/)) {
        key = substr($0, 1, RLENGTH - 1)
        value = trim(strip_comment(substr($0, RLENGTH + 1)))
        list_kind = ""
        if (key == "apply") {
          if (value !~ /^(auto|suggest|off)$/) fail("apply 값은 auto, suggest, off 중 하나여야 함: " value)
          print "apply=" value
        } else if (key == "match-remotes" || key == "match-paths") {
          if (value == "") list_kind = (key == "match-remotes") ? "remote" : "path"
          else if (value != "[]") fail(key " 는 블록 리스트만 지원함: " value)
        } else {
          print "warning=지원하지 않는 키 무시: " key
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

# 참고 파일 frontmatter의 description 값을 출력 (없으면 빈 출력)
read_reference_description() {
  local reference_file="$1"
  awk '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    /^description:/ {
      value = substr($0, length("description:") + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      if (value ~ /^".*"$/) value = substr(value, 2, length(value) - 2)
      print value
      exit
    }
  ' "$reference_file"
}

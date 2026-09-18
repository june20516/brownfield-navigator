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

# 경로 패턴을 비교할 수 있는 형태로 만듦
#   앞머리의 ~ 를 홈 경로로 바꾸고, 끝의 / 를 뗌 (패턴이 / 하나면 그대로 둠)
#   비교 후보는 dirname 으로 만들어 "/" 말고는 / 로 끝나지 않으므로, 끝 / 를 남겨 두면 어떤 경로에도 맞지 않는다
normalize_path_pattern() {
  local pattern
  pattern="$(expand_home_prefix "$1")"
  while [ "$pattern" != "/" ] && [ "${pattern%/}" != "$pattern" ]; do
    pattern="${pattern%/}"
  done
  printf '%s\n' "$pattern"
}

# 대상 경로 또는 그 상위 디렉터리 중 하나가 패턴과 일치하면 성공
# 상위로 올라가며 비교하므로 절대 경로만 받는다. 상대 경로는 dirname 이 `.` 에서 멈춰 끝나지 않는다
path_or_ancestor_matches() {
  local candidate="$1" pattern="$2"
  case "$candidate" in
    /*) ;;
    *) return 1 ;;
  esac
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
        if path_or_ancestor_matches "$target_dir" "$(normalize_path_pattern "$pattern")"; then
          printf 'path %s\n' "$pattern"
          return 0
        fi
        ;;
    esac
  done < "$parsed_file"
  return 1
}

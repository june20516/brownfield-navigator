# 규칙 섹션(## [id] 제목) 추출, 층 병합, 출력
# bash 3.2 호환 (연관 배열 대신 id별 파일 사용)

# 마크다운 파일의 ## [id] 섹션을 id별 파일로 나눔
#   <출력 디렉터리>/ids          등장 순서대로 id 목록
#   <출력 디렉터리>/<id>.title   헤딩의 제목 부분
#   <출력 디렉터리>/<id>.body    헤딩 다음 줄부터 다음 ## 헤딩 전까지
#   <출력 디렉터리>/warnings     규칙이 조용히 빠진 이유. 호출자가 경고로 올린다 (없으면 빈 파일)
# frontmatter, id 없는 ## 섹션, 첫 ## 헤딩 이전 내용은 건너뜀
# 코드 블록 안의 ## 줄은 헤딩으로 보지 않음
extract_rule_sections() {
  local markdown_file="$1" output_dir="$2"
  mkdir -p "$output_dir"
  : > "$output_dir/ids"
  : > "$output_dir/warnings"
  LC_ALL=C awk -v output_dir="$output_dir" '
    BEGIN { warnings_file = output_dir "/warnings" }
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
      } else if ($0 ~ /^##[[:space:]]+\[/) {
        # id를 쓰려 한 헤딩인데 형식이 달라 규칙으로 읽히지 않는다. 설명용 ## 섹션과 구분해 알린다
        print "id 형식([a-z0-9-]+)이 아닌 규칙 헤딩 무시: " $0 >> warnings_file
      }
      next
    }
    body_file != "" { print >> body_file }
    END {
      # 닫는 --- 가 없으면 파일 전체가 frontmatter로 읽혀 규칙이 하나도 남지 않는다
      if (in_frontmatter) print "frontmatter가 닫히지 않아 규칙을 읽지 못함" >> warnings_file
    }
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
  LC_ALL=C awk '
    /^[[:space:]]*$/ { if (started) exit; next }
    { started = 1; print }
  ' "$1"
}

print_without_trailing_blank_lines() {
  LC_ALL=C awk '
    { lines[NR] = $0 }
    END {
      last = NR
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
      for (i = 1; i <= last; i++) print lines[i]
    }
  ' "$1"
}

---
# apply 를 생략하면 조직 프로필의 값을 따른다
# apply: auto
match-remotes:
  - "*your-org/your-repo"
match-paths: []
---

# 프로젝트 파일

위치: `~/.claude/brownfield-navigator/orgs/<조직 이름>/projects/<프로젝트 이름>.md`

상위 층(코어, 조직, 개인)과 달라지는 규칙, 또는 이 레포에만 항상 적용할 규칙만 둔다. 설정값이나 함정 같은 사실 정보는 Claude Code 프로젝트 메모리에 둔다.

## [tests] 테스트 코드

이 레포는 테스트 파일을 만들지 않는다. 타입체크와 빌드로 검증한다.

**Why:** 조직 기본값과 다른 이 레포의 관례

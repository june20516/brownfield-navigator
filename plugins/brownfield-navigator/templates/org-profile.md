---
# 적용 강도: auto(규칙 주입) | suggest(한 줄 안내만) | off(주입 안 함)
apply: auto
# git remote URL 패턴 (bash glob). URL 끝의 / 와 .git 은 떼고 비교
match-remotes:
  - "*your-org/*"
# 경로 패턴 (bash glob). 대상 디렉터리나 그 상위 디렉터리와 비교, 앞머리 ~ 는 홈으로 확장
match-paths: []
---

# 조직 프로필

위치: `~/.claude/brownfield-navigator/orgs/<조직 이름>/profile.md` (조직 이름은 디렉터리 이름)

- `## [id] 제목` 섹션만 규칙으로 병합된다. id는 소문자, 숫자, `-`만 쓴다
- 코어 규칙과 같은 id를 쓰면 그 규칙을 대체하고, 새 id는 뒤에 추가된다
- 규칙마다 짧은 `**Why:**`를 적으면 Claude가 적용 여부를 스스로 판단할 수 있다
- 리스트는 블록 형식만 지원한다. `["a", "b"]` 형식은 파싱 실패로 무시된다

## [commit-message] 커밋 메시지

커밋 메시지는 `type: 설명 TICKET-123` 형식으로 쓴다. 티켓 번호는 브랜치 이름에서 확인한다.

**Why:** 레포 이력의 기존 형식과 맞추기 위함

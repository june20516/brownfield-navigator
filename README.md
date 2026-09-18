# brownfield-navigator

한국어 | [English](README.en.md)

레거시(brownfield) 코드베이스에서 기능을 넓히거나 유지보수할 때, **회사 컨벤션과 기존 코드의 흐름을 따르고 싶은 사용자를 위한** Claude Code 플러그인입니다.

프로젝트 메모리에 흩어진 지침을 조직, 개인, 프로젝트 프로필로 정리해 두면, 세션을 시작할 때 작업 디렉터리에 맞는 가이드를 병합해 주입합니다. 개인 프로젝트처럼 프로필에 맞지 않는 곳에서는 아무것도 하지 않습니다.

강제 장치가 아니라 가이드입니다. 사용자가 다른 방식을 원하면 Claude는 그쪽을 따릅니다.

## 동작 방식

| 층 | 내용 | 위치 |
|---|---|---|
| 코어 | 회사와 도구에 무관한 레거시 작업 원칙 | 플러그인 `skills/brownfield-navigator/SKILL.md` |
| 조직 | 회사 컨벤션 | `~/.claude/brownfield-navigator/orgs/<조직>/profile.md` |
| 개인 | Claude와 일하는 방식에 대한 개인 선호 | `~/.claude/brownfield-navigator/personal.md` |
| 프로젝트 | 특정 레포에서만 달라지는 규칙 | `~/.claude/brownfield-navigator/orgs/<조직>/projects/<이름>.md` |

1. 세션이 시작되면 훅이 작업 디렉터리의 git remote와 경로를 조직 프로필의 매칭 조건과 비교합니다
2. 매칭되면 `## [id] 제목` 섹션을 코어, 조직, 개인, 프로젝트 순으로 병합합니다. 같은 id는 뒤의 층이 대체합니다
3. 병합된 가이드와 참고 파일 목록이 세션 컨텍스트에 들어갑니다

설정값이나 함정 같은 프로젝트 고유의 사실은 지금처럼 Claude Code 프로젝트 메모리에 둡니다.

## 설치

```
/plugin marketplace add june20516/brownfield-navigator
/plugin install brownfield-navigator@brownfield-navigator
```

요구 사항: Claude Code, bash 3.2 이상. git은 remote 조건을 쓸 때만 필요합니다.

## 처음 설정

수집 스킬을 호출합니다.

```
/brownfield-navigator:harvest-profile
```

프로젝트 메모리가 쌓여 있으면 그 내용을 모아 조직 후보를 보여주고, 분류와 충돌 정리를 거쳐 초안을 만듭니다. 메모리가 없으면 조직 이름과 레포 경로를 물어 매칭 조건만 담은 최소 프로필을 만듭니다. 어느 쪽이든 승인한 내용만 파일로 쓰고, 메모리는 삭제하거나 수정하지 않습니다.

형식을 보고 직접 쓰고 싶다면 아래 [프로필 형식](#프로필-형식)의 예시를 옮겨 써도 됩니다.

## 동작 확인

훅은 세션이 시작될 때만 실행됩니다. 그래서 프로필을 만들거나 고친 뒤에는 새 세션을 시작하거나 `/clear` 해야 반영됩니다.

가이드는 Claude의 컨텍스트로만 들어가고 화면에는 보이지 않습니다. 잘 들어갔는지 보려면 대상 레포에서 세션을 시작한 뒤 스킬을 호출합니다. 어느 조직의 가이드를 적용하는지, 프로필을 읽다 생긴 경고가 있는지 Claude가 알려 줍니다.

```
/brownfield-navigator:brownfield-navigator
```

## 프로필 형식

### 조직 프로필과 프로젝트 파일

```markdown
---
apply: auto
match-remotes:
  - "*[:/]your-org/*"
match-paths:
  - "~/work/your-org/*"
---

## [commit-message] 커밋 메시지

커밋 메시지는 `type: 설명 TICKET-123` 형식으로 쓴다.

**Why:** 레포 이력의 기존 형식과 맞추기 위함
```

- `apply`: `auto`(규칙 주입), `suggest`(한 줄 안내만), `off`(주입 안 함). 생략하면 `auto`이고, 프로젝트 파일에서 생략하면 조직 값을 따릅니다
- `match-remotes`: git remote URL과 비교하는 bash glob입니다. URL 끝의 `/`와 `.git`, `https://user:token@host` 형식의 인증 정보는 떼고 비교하고, 대소문자를 구분합니다. `*your-org/*`는 `not-your-org`에도 맞으므로, 예시처럼 앞에 `[:/]`를 두어 owner 경계를 고정합니다
- `match-paths`: 작업 디렉터리나 그 상위 디렉터리와 비교하는 bash glob입니다. 앞머리 `~`는 홈으로 확장하고, 대상 경로는 심볼릭 링크를 따라간 실제 경로입니다. 홈을 포함해 경로 중간에 링크가 있으면 `~` 대신 실제 경로를 씁니다. 비교는 바이트 단위라 `?`와 `[...]`는 한글처럼 ASCII가 아닌 문자 한 글자에 맞지 않으니 그 자리에는 `*`를 씁니다. 디렉터리 패턴 끝에 `/`를 붙이면 매칭되지 않습니다(`"~/work/your-org/"`가 아니라 `"~/work/your-org/*"`). git을 쓰지 않는다면 이 조건을 씁니다
- 두 키의 패턴 중 **하나라도** 맞으면 매칭입니다. 둘을 모두 만족해야 하는 방식은 지원하지 않으므로, 범위를 좁히려면 패턴 자체를 좁힙니다
- 리스트는 블록 형식만 지원합니다. `["a", "b"]` 형식을 쓰면 그 파일 전체를 건너뛰고 경고가 남습니다. 한쪽 조건만 쓸 때 다른 키는 값을 비워 두지 말고 `match-paths: []`처럼 빈 리스트로 적습니다. 값 없이 두면 역시 파일 전체를 건너뜁니다
- 조직 이름은 `orgs/` 아래 디렉터리 이름, 프로젝트 이름은 파일 이름입니다. 프로젝트 파일은 조직 프로필이 먼저 매칭된 레포에서만 검사합니다

### 규칙 섹션

- `## [id] 제목`부터 다음 `## ` 헤딩 전까지가 규칙 하나입니다. id는 소문자, 숫자, `-`만 씁니다. 코드 블록 안의 `## ` 줄은 헤딩으로 세지 않으므로, 규칙 본문에 마크다운 예시를 넣어도 섹션이 쪼개지지 않습니다
- 같은 id는 대체, 새 id는 추가입니다. 코어 규칙의 id는 `guide-stance`, `workflow-skill-conflict`, `delegate-with-guide`, `actual-tooling`, `existing-pattern-first`, `existing-vocabulary`, `comment-density`, `preserve-vs-decide`, `stage-boundary`, `ideal-vs-current`, `respect-user-edits`, `verify-premise`, `structural-evidence`, `doc-conflict`, `spec-import`, `team-boundary` 열여섯 개입니다. 병합된 가이드에서는 섹션 제목 끝에 `(코어)`, `(조직: your-org)`처럼 최종 출처가 붙습니다
- id가 없는 `## ` 섹션은 설명으로 보고 병합하지 않습니다
- 규칙을 끄려면 섹션을 지웁니다. HTML 주석(`<!-- -->`)으로 감싸도 규칙으로 읽힙니다

### 개인 프로필

`personal.md`에는 frontmatter 없이 규칙 섹션만 둡니다. 조직 프로필이 매칭되어 가이드가 병합될 때만 적용됩니다.

### 참고 파일

`orgs/<조직>/references/<주제>.md`에 frontmatter `description:` 한 줄을 둡니다. 세션에는 경로와 설명만 들어가고, Claude가 관련 작업을 할 때 읽습니다.

## 수동으로 불러오기

여러 레포를 오가는 디렉터리에서 세션을 시작했거나, `apply`가 `suggest` 또는 `off`인 레포에서 가이드를 쓰려면 호출합니다. 수동 호출은 `off`로 꺼 둔 설정까지 되살리므로, Claude는 사용자가 요청했을 때만 그렇게 동작합니다.

```
/brownfield-navigator:brownfield-navigator
```

이 레포를 받아 두었다면 스크립트를 직접 실행해도 됩니다.

```bash
plugins/brownfield-navigator/bin/compose-guide --manual ~/work/your-org/your-repo
```

## 가이드가 나오지 않을 때

1. 대상 레포에서 세션을 시작한 뒤 `/brownfield-navigator:brownfield-navigator`를 호출합니다. 매칭되는 프로필이 없으면 없다고 알려 주고, 프로필을 읽다 실패했으면 그 경고를 보여 줍니다
2. 매칭 조건을 봅니다. `match-remotes`와 `match-paths`에 패턴이 **하나도 없는** 프로필은 어디에도 매칭되지 않고, 이때는 경고도 나오지 않습니다. 경로 패턴 끝에 `/`가 붙은 경우도 마찬가지로 조용히 실패합니다
3. `match-paths`는 심볼릭 링크를 따라간 실제 경로와 비교합니다. 대상 레포에서 `pwd -P`로 실제 경로를 확인해 패턴과 맞춰 보세요
4. frontmatter의 키 이름을 봅니다. 지원하지 않는 키는 무시하고 경고를 남기므로, `match-remote`처럼 오타가 난 키는 1번에서 경고로 드러납니다

## 주의

- 프로필은 `~/.claude/brownfield-navigator/`에 있는 사용자 파일입니다. 플러그인을 업데이트해도 지워지지 않지만, 다른 기기에서 쓰려면 따로 백업하거나 동기화해야 합니다. 위치는 환경변수 `BROWNFIELD_NAVIGATOR_HOME`으로 바꿀 수 있습니다
- 서브에이전트는 세션 시작 주입을 받지 않습니다. 코어 규칙 `[delegate-with-guide]`에 따라 Claude가 관련 규칙을 위임 프롬프트에 함께 적습니다
- 한 레포에 `auto` 조직이 둘 이상 매칭되면 이름순 첫 조직만 적용하고 경고합니다
- 한 조직에서 프로젝트 파일이 둘 이상 매칭되면 조직과 달리 하나를 고르지 않고 이름순으로 모두 병합하며, 경고합니다. `apply`는 값을 가진 마지막 파일의 값을 쓰므로, 파일 하나를 더했을 뿐인데 적용 강도가 바뀔 수 있습니다
- Claude Code는 훅 출력을 10,000자로 제한합니다. 그래서 세션에 주입하는 가이드에는 코어 규칙의 핵심 문단만 넣고(전문은 SKILL.md), 조직·개인·프로젝트 규칙은 전문을 넣습니다. 합쳐서 9,000자를 넘으면 제목 바로 아래에 "잘린 뒤에도 전체를 읽을 수 있으면 읽으라"는 조건부 안내가 붙지만, 잘린 출력이 파일로 남는지는 Claude Code에 달려 있으므로 9,000자 아래로 유지하는 편이 안전합니다. 조직 규칙이 길어지면 긴 설명은 참고 파일(`references/`)로 옮기세요

## 개발

```bash
bash plugins/brownfield-navigator/tests/run-all.sh
claude plugin validate plugins/brownfield-navigator
claude --plugin-dir plugins/brownfield-navigator
```

코어 규칙을 더하거나 id를 바꿨다면 두 README의 id 목록도 함께 고칩니다.

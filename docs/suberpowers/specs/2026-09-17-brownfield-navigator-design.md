# Brownfield Navigator 설계

- 작성일: 2026-09-17
- 상태: 설계 승인, 구현 계획 작성 전

## 1. 목적

레거시(brownfield) 코드베이스에서 기능 확장이나 유지보수를 할 때, **회사 컨벤션과 기존 코드의 흐름을 따르고 싶은 사용자를 돕는** Claude Code 플러그인.

### 해결하려는 문제

- 같은 지침이 프로젝트 메모리마다 복제되고 흩어짐. 첫 사용자의 사내 레포 6곳, 메모리 68개를 조사한 결과 같은 규칙이 3~6곳에 중복되어 있었음
- 사내 규칙을 전역 CLAUDE.md로 올리면 개인 프로젝트에도 적용되므로 공용 지침으로 뺄 수 없음
- 같은 회사 레포 사이에도 조금씩 다른 규칙이 있음

### 설계 원칙

- **가이드 도구이지 강제 장치가 아님.** 사용자가 다른 방식을 원하면 그쪽을 따른다
- **누구나 자기 것으로 쓸 수 있음.** 플러그인 본체는 범용 원칙만 담고, 회사, 개인, 프로젝트 규칙은 사용자 소유 프로필에 둔다
- **VCS와 무관하게 동작.** git remote가 없어도 경로 조건으로 매칭한다

## 2. 층 구조와 우선순위

| 층 | 내용 | 위치 |
|---|---|---|
| ① 코어 | 회사와 VCS에 무관한 레거시 작업 원칙 | 플러그인 `skills/brownfield-navigator/SKILL.md` |
| ② 조직 | 회사 컨벤션, 레포 산출물 규약 | `<프로필 홈>/orgs/<org>/profile.md` |
| ③ 개인 | Claude와 일하는 방식에 대한 개인 선호 | `<프로필 홈>/personal.md` |
| 프로젝트 | 상위 규칙을 대체하는 섹션, 그 레포에만 적용하되 항상 주입할 규칙 | `<프로필 홈>/orgs/<org>/projects/<name>.md` |
| ④ 사실 | 프로젝트 고유 사실(설정값, 함정, 문서 위치 등) | Claude Code 프로젝트 메모리 (이 플러그인은 건드리지 않음) |

`<프로필 홈>`은 `${BROWNFIELD_NAVIGATOR_HOME:-$HOME/.claude/brownfield-navigator}`.

**우선순위** (높은 순)

1. 현재 사용자 지시
2. CLAUDE.md
3. 프로젝트 층 (프로젝트 파일, 프로젝트 메모리)
4. ③ 개인
5. ② 조직
6. ① 코어

- 같은 id의 규칙은 `compose-guide`가 기계적으로 병합한다. 뒤의 층이 앞의 층을 대체한다
- 프로젝트 메모리와 프로필이 어긋나면 메모리를 따른다. 사용자가 더 최근에 한 말이기 때문
- ③ 개인 프로필은 `apply: auto`인 조직 프로필이 하나 이상 매칭된 세션에만 적용한다

## 3. 저장소 구성

### 3.1 플러그인 레포

위치 `~/personal/brownfield-navigator`, GitHub `june20516/brownfield-navigator`. suberpower와 같이 레포 자체가 마켓플레이스.

```
brownfield-navigator/
├── .claude-plugin/marketplace.json
├── README.md                              # 설치, 프로필 형식, 수집 스킬 사용법
├── docs/suberpowers/
└── plugins/brownfield-navigator/
    ├── .claude-plugin/plugin.json         # version 0.1.0
    ├── bin/compose-guide                  # 매칭과 병합 (훅과 스킬이 함께 사용)
    ├── hooks/
    │   ├── hooks.json
    │   ├── run-hook.cmd                   # suberpower 방식 재사용
    │   └── session-start
    ├── skills/
    │   ├── brownfield-navigator/SKILL.md  # ① 코어 원칙 + 수동 호출 절차
    │   └── harvest-profile/SKILL.md       # 메모리를 모아 프로필 초안 생성
    ├── templates/
    │   ├── org-profile.md
    │   ├── personal.md
    │   ├── project.md
    │   └── reference.md
    └── tests/
        └── compose-guide.test.sh
```

### 3.2 사용자 프로필 홈

```
~/.claude/brownfield-navigator/
├── personal.md
└── orgs/
    └── <org>/
        ├── profile.md
        ├── projects/<name>.md
        └── references/<topic>.md
```

플러그인을 업데이트해도 프로필은 지워지지 않는다.

## 4. 파일 형식

### 4.1 규칙 섹션

- `## [id] 제목` 헤딩부터 다음 `## ` 헤딩 직전까지가 한 섹션. 섹션 안에서는 `###` 이하를 쓸 수 있음
- id는 소문자 kebab-case (`[a-z0-9-]+`)
- id가 없는 `## ` 섹션은 병합 대상이 아님 (설명용)
- 규칙 본문에 짧은 `**Why:**`를 함께 적는다. Claude가 적용 여부를 스스로 판단할 수 있게 하기 위함
- **같은 id는 대체, 새 id는 추가**

### 4.2 조직 프로필 frontmatter

```yaml
---
name: pnpt
apply: auto
match-remotes:
  - "*pnpt-ds/*"
match-paths: []
---
```

- 지원하는 키는 `name`, `apply`, `match-remotes`, `match-paths` 네 개
- 리스트는 한 줄에 `  - "패턴"` 하나, 빈 리스트는 `[]`
- `apply`: `auto` | `suggest` | `off`, 생략하면 `auto`
- 패턴은 bash glob (`*`는 `/`도 매칭). `match-paths`의 앞머리 `~`는 홈 경로로 확장
- remote 조건과 경로 조건 중 하나라도 맞으면 매칭

### 4.3 프로젝트 파일 frontmatter

조직 프로필과 같은 키를 쓴다. `apply`를 생략하면 조직 값을 따른다.

remote URL은 끝의 `/`와 `.git`을 제거해 정규화한 뒤 비교하므로 `"*pnpt-ds/fez-front-taap"`처럼 정확히 쓸 수 있다.

### 4.4 개인 프로필

frontmatter가 없다(있어도 무시한다). 본문은 규칙 섹션으로 구성한다.

### 4.5 참고 파일

frontmatter에 `description:` 한 줄을 둔다. 본문 형식은 자유. 주입 시에는 경로와 description만 목록으로 들어가고, Claude가 관련 작업을 할 때 Read한다.

## 5. compose-guide

```
compose-guide [대상 디렉터리]    # 생략하면 현재 디렉터리
```

- 출력: 병합된 가이드 텍스트(stdout). 매칭이 없으면 빈 출력
- 항상 exit 0
- 의존성: bash, git(선택). jq는 쓰지 않음

### 알고리즘

1. 대상 디렉터리를 절대 경로로 바꾼다. git을 쓸 수 있으면 `git -C <dir> remote -v`의 URL을 모두 모아 끝의 `/`와 `.git`을 제거한다
2. `orgs/*/profile.md`를 이름순으로 읽어 frontmatter를 파싱한다. 실패한 프로필은 경고 목록에 넣고 건너뛴다
3. 조직 매칭: 정규화한 URL 중 하나가 `match-remotes` 패턴에 맞거나, 대상 경로가 `match-paths` 패턴에 맞으면 매칭
4. 매칭된 조직마다 `projects/*.md`를 같은 방식으로 매칭한다. 여러 개가 매칭되면 이름순으로 모두 병합하고 경고를 붙인다
5. `apply` 결정: 매칭된 프로젝트 파일에 `apply`가 있으면 그 값, 없으면 조직 값
   - `off`: 그 조직은 출력하지 않음
   - `suggest`: 한 줄 안내만 출력 (`<org> 가이드를 적용할 수 있음. /brownfield-navigator로 불러오기`)
   - `auto`: 아래 7번의 병합 수행
6. 매칭된 조직이 없을 때: 경고가 있으면 경고만 출력하고, 경고도 없으면 빈 출력
7. 병합 순서: 코어 → 조직(이름순) → 개인 → 프로젝트(이름순)
   - 같은 id는 **처음 등장한 자리에서** 내용을 대체하고, 새 id는 끝에 추가한다
   - 헤딩 끝에 출처를 붙인다: `(코어)`, `(조직: pnpt)`, `(개인)`, `(프로젝트: fez-front-taap)`
   - 대체된 섹션은 대체한 층의 제목과 본문을 쓰고, 최종 출처만 표시한다
   - 서로 다른 조직이 같은 id를 정의하면 둘 다 남기고 충돌 경고를 붙인다
8. 출력 구성
   1. 머리말: 매칭 근거(조직 이름, 맞은 remote 또는 경로), 가이드 성격("기존 흐름을 따르는 작업을 위한 기본 가이드. 사용자가 다른 방식을 원하면 그쪽을 따름"), 우선순위 안내
   2. 병합된 규칙 섹션
   3. 참고 파일 목록: `- <절대 경로>: <description>`
   4. 경고 (있을 때만)

## 6. SessionStart 훅

- `hooks.json`: `SessionStart`, matcher `startup|clear|compact`, `run-hook.cmd session-start` 호출
- `session-start`
  1. 대상 디렉터리: stdin JSON의 `cwd`를 jq 없이 추출. 실패하면 `CLAUDE_PROJECT_DIR`, 그것도 없으면 `pwd`
  2. `compose-guide` 실행
  3. 출력이 비어 있으면 아무것도 출력하지 않음
  4. 출력이 있으면 `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}` 출력 (JSON 이스케이프는 suberpower의 `escape_for_json` 방식)
- 어떤 오류도 세션을 막지 않는다 (exit 0)
- 주입 문구에 `EXTREMELY_IMPORTANT`, `MUST` 같은 강제 표현을 쓰지 않는다
- 출력 형식은 Claude Code만 지원한다

## 7. 스킬

### 7.1 `brownfield-navigator` (코어)

- frontmatter: 모델 호출 허용. description은 좁게 쓴다: "레거시 코드베이스에서 회사 컨벤션과 기존 흐름을 따르는 작업 가이드를 불러온다. 사용자가 가이드 적용을 요청하거나, 세션 시작 시 주입이 없었는데 등록된 조직의 레포를 작업할 때 사용"
- 본문
  - `## 이 스킬이 하는 일` (id 없음): 층 구조와 가이드 성격을 요약
  - `## 호출되었을 때` (id 없음)
    1. 세션 컨텍스트에 이미 brownfield-navigator 가이드가 주입되어 있으면 추가로 할 일 없이 작업을 계속한다
    2. 주입이 없으면 작업 대상 경로를 정한다 (사용자가 말한 레포, 없으면 cwd)
    3. 스킬 base directory 기준 `../../bin/compose-guide <경로>` 실행
    4. 출력이 있으면 이 세션에 적용한다고 한 줄로 알리고 적용한다
    5. 출력이 없으면 매칭되는 프로필이 없다고 알리고 두 가지를 제안한다: 이번 세션에 코어 원칙만 적용하기, `/harvest-profile`로 이 레포 등록하기
  - 코어 규칙 섹션 (8장)

### 7.2 `harvest-profile` (수집)

- frontmatter: `disable-model-invocation: true` (파일을 쓰므로 사용자만 호출), `argument-hint: "[조직 이름 또는 메모리 경로]"`
- 절차
  1. **수집:** `~/.claude/projects/*/memory/*.md`(MEMORY.md 제외)를 모은다. 디렉터리 이름으로 원래 경로를 복원하고(실제로 존재하는지 확인), git remote를 조회해 조직 후보로 묶는다. 묶는 기준은 remote owner, git이 없으면 상위 경로
  2. **범위 확인:** 조직 후보와 포함할 프로젝트를 사용자에게 확인받는다. 개인 프로젝트를 제외할지는 사용자가 정한다
  3. **분류:** 메모리 본문을 읽고 아래 표로 분류한다
  4. **충돌:** 서로 부딪히는 규칙은 나란히 보여주고, 정리안(적용 상황으로 구분하거나 조직 기본값과 프로젝트 대체로 분리)을 제시한다
  5. **작성:** 층별 초안을 보여주고 승인을 받은 뒤 템플릿 형식으로 파일을 쓴다. 매칭 조건도 함께 제안한다 (git이 있으면 remote 패턴, 없으면 경로 glob)
  6. **보고**
     - 생성하거나 수정한 파일
     - 레포별 `compose-guide` 미리보기
     - 정리 후보 메모리 목록 (프로필로 옮겨진 것, CLAUDE.md와 중복인 것). **삭제하지 않는다**
- 분류 기준

| 조건 | 분류 |
|---|---|
| 코어 규칙과 같은 내용 | 생략 (어느 코어 id와 겹치는지 보고) |
| 레포에 남는 산출물에 대한 규약 (커밋 형식, 주석 형식, 네이밍 등) | ② 조직 |
| Claude와 일하는 방식 (커밋 여부, 보고 방식 등) | ③ 개인 |
| 같은 주제인데 레포마다 다름 | ② 조직 기본값 + 프로젝트 대체 |
| 한 레포에서만 나온 규칙 | 적용 범위를 사용자에게 질문. 넓히지 않으면 프로젝트 파일 |
| 설정값, 함정, 문서 위치 등 사실 | ④ 메모리에 유지 |
| 긴 참고 정보가 여러 레포에 걸침 | 조직 `references/` |

- 재실행: 프로필이 이미 있으면 덮어쓰지 않고, 보완할 부분만 diff로 제안한다

## 8. ① 코어 규칙

| id | 내용 |
|---|---|
| `guide-stance` | 기존 흐름을 이어가는 확장·유지보수 작업의 기본값. 사용자가 새 구조, 실험, 이탈을 원하면 따르고 어긋나는 지점만 한 번 한 줄로 알림. "가이드 끄기"라고 하면 그 세션에서 적용 중단 |
| `workflow-skill-conflict` | 워크플로우 스킬(TDD, 계획 실행 등)의 커밋, 테스트, 문서 산출물 단계가 레포 관례나 프로필과 부딪히면 관례를 따르고 건너뛴 단계를 보고 |
| `delegate-with-guide` | 서브에이전트에 작업을 위임할 때 적용 중인 가이드 중 관련 규칙을 프롬프트에 함께 전달. 서브에이전트는 세션 시작 주입을 받지 않음 |
| `actual-tooling` | 스크립트나 설정 파일이 있다고 해서 그 도구가 실제로 동작한다는 뜻은 아님. 실제로 쓸 수 있는 검증 수단(타입체크, 빌드, 포매터)을 먼저 확인하고, 동작하지 않는 도구의 설치나 복구에 시간을 쓰지 않고 알림 |
| `existing-pattern-first` | 에러 처리, 파일 위치, 네이밍, 디렉터리 구성은 기존 사례를 찾아 따름. 코드베이스에 없는 추상화는 들이지 않음 |
| `existing-vocabulary` | 용어, 토큰 이름, 식별자는 코드베이스, 자매 프로젝트, 용어집에서 먼저 찾음. 없는 어휘는 만들지 않음. 표준 용어인지보다 팀이 아는 말인지가 기준이며, 확신이 없으면 하는 일을 풀어서 씀 |
| `comment-density` | 주석의 밀도와 어조는 주변 코드에 맞춤. 코드가 이미 말하는 내용은 반복하지 않고, 고치는 사람이 빠질 함정과 코드만 봐서는 알 수 없는 이유만 남김 |
| `preserve-vs-decide` | 기존 동작 보존과 새 동작 결정을 구분. 새로 정해야 하는 동작(에러 처리 방식, 모달과 문구, 기본값, 부분 실패 처리)은 "현재 동작 / 문제 지점 / 선택지"로 정리해 먼저 묻고 답을 받은 뒤 구현 |
| `stage-boundary` | 단계별 작업에서는 "이번 변경이 현재 동작을 바꾸는가"로 항목을 나누고, 다음 단계에서야 의미가 생기는 판단을 섞지 않음 |
| `ideal-vs-current` | 기본은 기존 구조를 따름. 리팩토링이나 재설계라면 명세 기준의 이상적인 구조도 함께 그려 기존 코드에 얹는 방식과 비용·이득을 비교해 제안하고 선택은 사용자가 함. 최소 수정으로 가도 차이를 명시. 바뀌는 이유가 다른 코드는 한 파일에 두지 않음 |
| `respect-user-edits` | 사용자가 고친 코드, 주석, 이름은 되돌리지 않음. 현재 파일이 기준이며 문서를 코드에 맞춤. 수정 때문에 사실과 달라진 부분만 지적 |
| `verify-premise` | 구조 변경을 권하기 전에 전제를 검증. 문서의 결론만이 아니라 그것을 뒷받침하는 동작 원리를 소스에서 확인. 실제 스택 그대로 재현. 변경 이력(git log/blame, 없으면 문서나 담당자)으로 원래 의도 확인. 호출하는 곳이 없는 API는 흔적일 수 있음. 부수적인 작업이 구조 변경을 요구하면 전제 오류 신호로 보고 멈춤. 테스트 통과는 요구사항 충족의 증거가 아님 |
| `structural-evidence` | 간헐적으로 나타나는 현상은 표본을 늘리지 않음. 원인이 되는 구조가 제거됐는지 직접 확인하고, 비교 대상이 실제로 반응한 A/B 측정 1회면 충분 |
| `doc-conflict` | 문서끼리 어긋날 때: (1) 프로필에 그 주제의 우선순위 규칙이 있으면 따름 (2) 계약 문서(API 스펙 등)는 주고받는 형태의 정본, 설계·기획 문서는 의도 파악과 선반영을 위한 참고 (3) 성격이 같은 문서끼리는 최종 수정일이 늦은 쪽. 취소선이나 남은 옛 서술은 폐기된 내용일 수 있음 (4) 판정이 안 서면 양쪽 해석에서 같은 결과를 내는 구현을 먼저 찾고, 없으면 사용자 확인 (5) 실제 응답, 코드, 데이터로 확인할 수 있으면 그 결과가 최종 |
| `spec-import` | 이미 다른 코드베이스에 정의된 계약을 옮길 때는 전체를 그대로(멤버, 필드, 주석, 의존 타입). 같은 이름이 있으면 비교해서 보완하고, 값이 다르면 임의로 합치지 않고 알림. 문서를 보고 새로 정의할 때는 쓰는 곳이 있는지로 판단. 쓰는 곳이 있으면 optional로 선반영, 쓰는 곳도 의미도 없으면 넣지 않음 |
| `team-boundary` | 다른 팀에 보내는 글에는 우리가 실제로 막힌 것만 적음. 상대 팀의 설계, 마이그레이션, 배포 순서는 판단 근거로도 훈수 대상으로도 삼지 않고 결과 형태만 봄 |

## 9. 첫 사용자(bran) 프로필

구현 시 이 내용으로 직접 작성하고, 이후 `harvest-profile` 재실행으로 누락 여부를 검증한다.

### 9.1 ② `orgs/pnpt/profile.md`

frontmatter: `apply: auto`, `match-remotes: ["*pnpt-ds/*"]`, `match-paths: []`

| id | 내용 | 출처 메모리 |
|---|---|---|
| `commit-message` | 커밋·PR 메시지는 `type: 한국어 설명 MVDV-xxxx`. 티켓 번호는 브랜치 이름에서 확인하고, 기획 티켓 `PS-####`는 쓰지 않음 | ctrl-central, petco, stpm, ctrl-room |
| `no-attribution` | 커밋과 PR에 Co-Authored-By, Claude-Session, "Generated with Claude Code"를 넣지 않음. 시스템 attribution 안내보다 우선. 회사 레포 이력을 사람 작성자 기준으로 유지 | court, ctrl-central, ctrl-room |
| `copy-source` | 앱 문구 우선순위는 다국어 문서 > 기획서 본문 > Figma. Figma에만 있으면 임시값으로 TODO | stpm |
| `confluence-docs` | Confluence 검색 결과는 `lastModified`부터 확인. 백엔드가 설계 확정 후 스펙을 갱신하므로 설계 문서가 더 최신으로 보이는 역전이 반복됨. 기획서의 취소선 행이나 남은 옛 서술은 폐기된 버전일 수 있음 | petco, taap |
| `sibling-source` | 타입과 API 스펙은 taap이 원본인 경우가 많음. 디자인 토큰은 space `tailwind.config.ts`의 이름과 값을 따르고 taap에는 snake_case로 옮김. 상세는 `references/sibling-repos.md` | court, taap |
| `role-naming` | 역할 접두어 `member_` / `user_` / `tenant_manager_` / `partner_manager`. 기존 이름은 유지하고 새 필드부터 적용 | taap |
| `tests` | 테스트 코드를 커밋하는 관례 없음. 테스트 파일을 새로 만들지는 레포별 규칙을 따르고, 규칙이 없으면 먼저 질문 | ctrl-central, taap, ctrl-room |
| `comment-style` | 명사형 종결, 마침표 없음, 장식용 특수문자(—, →, ·, ✓) 없음. 설계 근거는 문서가 폐기돼도 필요한 "왜"만 한두 문장으로 코드에 남기고, 배경 설명이나 규칙 절은 문서에 둠 | taap, ctrl-room |
| `korean-wording` | 은유와 음차 외래어를 피함 (무장→발동 대기, 게이트→필수 조건, 부착→첨부, 승격→옮긴다, 봉투는 쓰지 않음). STARTER→MEMBER 전환에 "승급"을 쓰지 않음 | taap, ctrl-room, court |

참고 파일

- `references/sibling-repos.md`: 레포별 역할, 공유 백엔드와 호스트, 환경별 도메인, 타입·토큰 원본 경로 (court `reference_related_projects`, taap 토큰 출처)
- `references/app-webview.md`: 앱→웹뷰 규약. `lang=` 파라미터, `window.taap.canGoBack` 동기화 함정 (petco `reference-app-webview-lang-param`, `reference-taap-webview-canGoBack`)

### 9.2 ③ `personal.md`

| id | 내용 | 출처 메모리 |
|---|---|---|
| `commit-by-user` | 요청이 없으면 커밋하지 않고 커밋할지 묻지도 않음. 변경 요약만 보고. 서브에이전트 프롬프트에도 커밋 단계를 넣지 않음 | court, taap, petco, ctrl-room |
| `workflow-docs` | `docs/suberpowers/` 산출물은 작성하되 커밋하지 않음. `?? docs/`가 남아 있어도 누락이 아님 | court, taap, petco |
| `one-task-then-report` | 작업 단위 하나가 끝나면 변경 파일과 요지를 보고하고 멈춤. 커밋하지 않은 이전 변경이 있으면 이번 작업 파일 목록을 따로 적음 | ctrl-room |

공용 브랜치 `--no-track` 규칙은 전역 CLAUDE.md에 있으므로 넣지 않는다.

### 9.3 프로젝트 파일

| 파일 | match-remotes | 섹션 |
|---|---|---|
| `fez-front-ctrl-central.md` | `*pnpt-ds/fez-front-ctrl-central` | `[tests]` 테스트 파일을 만들지 않음. `tsc --noEmit`과 CRA 빌드로만 검증 |
| `fez-front-taap.md` | `*pnpt-ds/fez-front-taap` | `[tests]` 테스트를 유지하지 않음. `npx tsc --noEmit`과 prettier로 검증, 동작은 기기에서 확인. `[workflow-docs]` 커밋하지 않고 구현이 끝나면 삭제 |
| `omar-front-ctrl-room.md` | `*pnpt-ds/omar-front-ctrl-room` | `[tests]` 검증용으로 작성·실행하되 커밋하지 않음(`.git/info/exclude`). `[comment-style]` 짧으면 명사형, 설명이 필요하면 평서형, 한 문장에 하나, 코드나 표가 말하는 내용 반복 금지. `[simple-git-guidance]` 안내하는 git 명령은 가장 단순한 안부터, 손으로 파일 옮기는 단계 금지, 이력 재작성은 복제본에서 끝까지 실행해 본 뒤 안내 |
| `front-space-petco.md` | `*pnpt-ds/front-space-petco` | `[capture-location]` 화면 캡처는 `~/Desktop/test screen/<티켓번호>/`, 데이터가 없으면 mock으로 상황을 만들어 캡처 |

court, stpm은 달라지는 규칙이 없어 파일을 만들지 않는다.

### 9.4 메모리에 남기는 것 (④)

약관 코드, Expo 에셋·manifest 함정, BLE date 의미, fmt iOS 빌드, Android 키보드, Sentry, 환경변수·배포, pre-commit 보류, i18n-ally, selfRegist 딥링크·뒤로가기, petco BizException 관례, taap eslint 실행 불가, 승인 헬퍼 위치, 방문 필드 권한 기준, 진행 중 작업 기록(웹 버전 관리, 에러 관측성, 영역 진행 리마인드 등).

## 10. 에러 처리

| 상황 | 동작 |
|---|---|
| 프로필 홈이 없음 | 빈 출력 |
| 매칭되는 조직 없음 | 빈 출력 |
| frontmatter 파싱 실패 | 그 파일을 건너뛰고 경고 한 줄 출력 (매칭 여부와 무관하게 출력해 고칠 수 있게 함) |
| 조직 2개 이상 매칭 | 모두 병합. 서로 다른 조직이 같은 id를 정의하면 둘 다 남기고 충돌 경고 |
| 프로젝트 파일 2개 이상 매칭 | 이름순으로 모두 병합하고 경고 |
| git 미설치, remote 없음, git 레포 아님 | remote 검사를 건너뛰고 경로 조건만 사용 |
| 훅 내부 오류 | 세션을 막지 않음 (exit 0, 빈 출력) |

## 11. 테스트

- `tests/compose-guide.test.sh`: 외부 의존성 없는 bash 테스트. 임시 프로필 홈(`BROWNFIELD_NAVIGATOR_HOME`)과 임시 git 레포(`git init` + `git remote add`)를 만들어 검증
  - 매칭 없음이면 빈 출력
  - ssh와 https remote 매칭, `.git` 유무 정규화
  - git이 아닌 디렉터리에서 경로 매칭, `~` 확장
  - 같은 id 대체 (위치 유지, 출처 표시)
  - 새 id 추가
  - `apply: suggest`, `apply: off`, 프로젝트 apply가 조직 apply보다 우선
  - 개인 프로필은 auto 조직이 매칭된 경우에만 병합
  - 깨진 frontmatter는 경고하고 계속 진행
  - 조직 2개 매칭 시 같은 id 충돌 경고
  - 참고 파일 목록과 description
- 훅: `session-start` 출력이 올바른 JSON인지 (`python3 -m json.tool`로 검증), 매칭이 없을 때 빈 출력인지
- 실제 세션 확인
  - `~/repositories/fez-front-taap`에서 시작하면 가이드가 주입되고 `[tests]`가 프로젝트 출처로 표시됨
  - `~/personal/tagatigi`, `~/repositories/coffee-order`에서는 주입되지 않음
  - `~/repositories`에서 시작한 뒤 `/brownfield-navigator`를 호출해 대상 레포를 지정하면 가이드가 적용됨
- bran 프로필 작성 후 `/harvest-profile`을 재실행해 누락 제안 여부 확인

## 12. 설치와 배포

1. 로컬 마켓플레이스로 설치해 검증 (`/plugin marketplace add ~/personal/brownfield-navigator`)
2. GitHub 레포 생성과 push는 외부 공개 작업이므로 구현 완료 후 사용자 확인을 받고 진행
3. README에 다른 사용자를 위한 설치, `/harvest-profile` 실행, 프로필 형식 설명을 포함

## 13. 범위 밖

- 세션 중에 새 규칙이 생기면 프로필로 올리자고 제안하는 기능 (수집 스킬 재실행으로 대신함)
- 프로젝트 메모리 자동 삭제나 수정
- SVN, Mercurial의 remote 검사 (경로 조건으로 대신함)
- Cursor, Copilot CLI 출력 형식
- 팀 공용 조직 프로필을 원격으로 공유하는 기능

## 14. 구현 중 확인할 사항

- `~/.claude/brownfield-navigator/`가 claude-sync 동기화 대상에 포함되는지. 포함되지 않으면 사용자에게 알림
- 스킬 로드 시 제공되는 base directory로 `compose-guide` 경로를 안정적으로 계산할 수 있는지
- suberpower `run-hook.cmd`를 그대로 재사용할 수 있는지

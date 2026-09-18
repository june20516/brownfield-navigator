# Brownfield Navigator 설계

- 작성일: 2026-09-17
- 상태: 설계 승인, spec 리뷰 반영, 구현 계획 작성 전

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
- ③ 개인 프로필은 병합이 일어나는 경우(적용 값이 `auto`인 조직이 있을 때)에만 들어간다

## 3. 저장소 구성

### 3.1 플러그인 레포

위치 `~/personal/brownfield-navigator`, GitHub `june20516/brownfield-navigator`. suberpower와 같이 레포 자체가 마켓플레이스.

```
brownfield-navigator/
├── .claude-plugin/marketplace.json
├── README.md                              # 설치, 프로필 형식, 수집 스킬 사용법
├── LICENSE                                # MIT
├── docs/suberpowers/
└── plugins/brownfield-navigator/
    ├── .claude-plugin/plugin.json         # version 0.1.0
    ├── bin/compose-guide                  # 매칭과 병합 (훅과 스킬이 함께 사용)
    ├── lib/
    │   ├── profile.sh                     # frontmatter 파싱, 참고 파일 description
    │   ├── match.sh                       # remote 정규화, 경로·remote 매칭
    │   └── sections.sh                    # 규칙 섹션 추출, 층 병합, 출력
    ├── hooks/
    │   ├── hooks.json
    │   ├── run-hook.cmd                   # suberpower 파일 그대로 복사
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
        ├── test-helpers.sh                # 단언, 테스트 실행, 픽스처
        ├── run-all.sh
        ├── profile.test.sh
        ├── match.test.sh
        ├── sections.test.sh
        ├── compose-guide.test.sh
        ├── session-start.test.sh
        └── templates.test.sh              # 템플릿이 경고 없이 병합되는지
```

플러그인 스킬은 `/<플러그인>:<스킬>` 형식으로 호출한다: `/brownfield-navigator:brownfield-navigator`, `/brownfield-navigator:harvest-profile`.

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
- 코어 규칙은 첫 문단을 규칙 전체의 완결된 요약으로 쓴다. 세션 주입 때는 첫 문단만 들어가기 때문 (5장 7번)
- 규칙이 조용히 빠지지 않게, 섹션 추출은 두 경우에 진단을 남기고 compose-guide가 경고로 옮긴다: `## [` 로 시작하는데 id 형식(`[a-z0-9-]+`)이 아닌 헤딩, 첫 줄이 `---`인데 닫는 `---`가 없어 파일 전체를 읽지 못한 경우
- **같은 id는 대체, 새 id는 추가**

### 4.2 조직 프로필 frontmatter

```yaml
---
apply: auto
match-remotes:
  - "*[:/]pnpt-ds/*"
match-paths: []
---
```

- **이름:** 조직 이름은 `orgs/` 아래 디렉터리 이름이다. 출처 표기와 안내문에 이 이름을 쓴다. `name` 키는 두지 않는다
- **지원 키:** `apply`, `match-remotes`, `match-paths`
- **리스트:** 블록 형식만 지원한다. 한 줄에 `  - 패턴` 하나. 빈 리스트는 `[]` 또는 키 생략. 한 줄 flow 형식(`["a", "b"]`)은 지원하지 않는다
- **따옴표와 주석:** 패턴과 `apply` 값은 큰따옴표나 작은따옴표로 감싸도 되고 감싸지 않아도 된다. 감싸면 따옴표를 벗겨내고, 따옴표 안의 `#`은 주석으로 보지 않는다. 따옴표 밖에서는 공백 뒤 `#`부터 주석이다. 키 이름 앞뒤 공백은 무시한다(`apply : off`)
- **`apply`:** `auto` | `suggest` | `off`, 생략하면 `auto`
- **패턴:** bash `[[ 문자열 == 패턴 ]]` 비교. 문자열 전체와 일치해야 하며 `*`는 `/`도 매칭한다. `match-paths` 패턴의 앞머리 `~`는 홈 경로로 확장한다
- **remote 매칭:** 정규화한 remote URL(5장 1번) 중 하나가 패턴과 일치. 비교는 대소문자를 구분한다. 선행 `*`는 owner 경계를 보장하지 않으므로(`*acme/*`는 `not-acme/x`에도 맞는다) 예시와 템플릿, 수집 스킬의 제안은 `*[:/]acme/*` 형태를 쓴다
- **경로 매칭:** 대상 디렉터리(심볼릭 링크를 따라간 실제 경로) **또는 그 상위 디렉터리 중 하나**가 패턴과 일치. 패턴 끝의 `/`는 떼고 비교한다(패턴이 `/` 하나면 그대로). 비교 대상 경로는 `/`로 끝나지 않으므로 떼지 않으면 아무것도 맞지 않는다. 비교는 바이트 단위(`LC_ALL=C`)라 `?`와 `[...]`는 한글 한 글자에 맞지 않으므로, README에 한글 자리에는 `*`를 쓰도록 안내한다. 따라서 `~/work/acme/proj`는 `proj` 하위에서 시작한 세션에도 맞고, `~/work/acme/*`는 `acme` 아래의 모든 레포에 맞는다
- remote 조건과 경로 조건 중 하나라도 맞으면 매칭한다. 두 리스트가 모두 비어 있으면 매칭되지 않는다

### 4.3 프로젝트 파일 frontmatter

조직 프로필과 같은 키와 규칙을 쓴다.

- 프로젝트 이름은 파일 이름에서 `.md`를 뗀 것이다
- `apply`를 생략하면 조직 값을 따른다
- remote URL은 정규화한 뒤 비교하므로 `*[:/]pnpt-ds/fez-front-taap`처럼 레포 이름까지 정확히 쓸 수 있다

### 4.4 개인 프로필

frontmatter를 파싱하지 않는다. 본문은 규칙 섹션으로 구성한다.

### 4.5 참고 파일

frontmatter에 `description:` 한 줄을 둔다(콜론 앞 공백 허용, 값을 감싼 따옴표는 벗김). frontmatter 밖 본문의 `description:`은 읽지 않는다. 본문 형식은 자유. 주입할 때는 경로와 description만 목록으로 들어가고, Claude가 관련 작업을 할 때 Read한다. description이 없으면 경로만 표시한다.

### 4.6 파싱 실패 조건

조직 프로필과 프로젝트 파일에만 적용한다. 실패한 파일은 매칭 대상에서 빠지고 경고 한 줄이 남는다.

| 조건 | 처리 |
|---|---|
| 파일을 읽을 수 없음 (없음, 디렉터리, 권한) | 실패 |
| 첫 줄이 `---`가 아님 (frontmatter 없음) | 실패 |
| 닫는 `---`가 없음 | 실패 |
| `apply` 값이 `auto`, `suggest`, `off` 밖 | 실패 |
| 리스트 키 뒤가 `[]`도 아니고 블록 항목도 아님 (flow 형식 포함) | 실패 |
| 리스트 키의 값을 비웠는데 블록 항목이 하나도 없음 (다음 키나 닫는 `---`가 바로 옴) | 실패 |
| 따옴표가 닫히지 않았거나, 닫는 따옴표 뒤에 주석이 아닌 내용이 있음 | 실패 |
| 어느 리스트 키에도 속하지 않는 `- 항목`, 해석할 수 없는 줄 | 실패 |
| 지원하지 않는 키 (그 아래 들여쓴 줄이나 `- 항목` 포함) | 실패 아님. 경고 후 함께 무시 |
| 파싱은 됐지만 `match-remotes`와 `match-paths`에 패턴이 하나도 없음 | 매칭 대상에서 제외하고 경고. 어떤 레포에도 맞지 않는 설정 오류 |

## 5. compose-guide

```
compose-guide [--manual] [대상 디렉터리]    # 대상을 생략하면 현재 디렉터리
```

- **`--manual`:** 수동 호출용. 매칭된 조직과 프로젝트의 적용 값이 `suggest`나 `off`여도 `auto`로 취급한다. 사용자가 직접 요청했기 때문
- **출력:** 가이드 텍스트(stdout). 출력할 것이 없으면 빈 출력
- **종료 코드:** 항상 0
- **구현 제약:**
  - bash 3.2 호환 (macOS 기본 `/bin/bash`). 연관 배열(`declare -A`), `mapfile`, `${var,,}`를 쓰지 않는다
  - awk, sed, grep은 쓸 수 있되 BSD와 GNU에 공통인 옵션만 쓴다
  - jq는 쓰지 않는다. git은 있으면 쓴다
  - `LC_ALL=C`로 바이트 단위 처리한다. UTF-8 로캘의 awk는 잘못된 UTF-8 바이트(다른 인코딩으로 저장한 프로필 등)를 만나면 멈춰 뒤쪽 규칙이 조용히 빠지기 때문

### 알고리즘

1. **대상 준비:** 대상 디렉터리를 절대 경로로 바꾼다. git을 쓸 수 있으면 `git -C <dir> remote -v`의 URL을 모두 모으고, 끝의 `/`와 `.git`을 제거해 정규화한다
2. **조직 파싱:** `orgs/*/profile.md`를 이름순으로 읽는다. 파싱에 실패한 파일은 경고를 남기고 제외한다 (4.6)
3. **조직 매칭:** 4.2 규칙으로 매칭한다
4. **프로젝트 매칭:** 매칭된 조직마다 `projects/*.md`를 같은 방식으로 파싱하고 매칭한다. 2개 이상 매칭되면 이름순으로 모두 쓰고 경고를 붙인다
5. **적용 값 결정:** 매칭된 프로젝트 파일 중 `apply`가 있는 파일의 값(여러 개면 이름순 마지막)을 쓰고, 없으면 조직 값을 쓴다. `--manual`이면 `auto`
6. **조직 분류**
   - `off`: 제외한다
   - `suggest`: 안내문 목록에 넣는다. 안내문은 `<org> 가이드를 적용할 수 있음. /brownfield-navigator:brownfield-navigator 로 불러오기`
   - `auto`: 병합 대상이다. `auto` 조직이 2개 이상이면 이름순 첫 조직만 병합하고 경고를 붙인다 (`여러 조직이 매칭됨: a, b. a만 적용함. 매칭 조건을 좁힐 것`)
7. **병합** (병합 대상 조직이 있을 때만)
   - 층 순서: 코어 → 조직 → 개인 → 프로젝트(이름순)
   - 코어 층: `skills/brownfield-navigator/SKILL.md`에서 frontmatter와 id 없는 `## ` 섹션을 뺀 `## [id]` 섹션들
   - 개인 층: `personal.md`가 있으면 그 파일의 `## [id]` 섹션들
   - 같은 id는 처음 등장한 자리에서 교체한다. 제목과 본문은 교체한 층의 것을 쓴다. 새 id는 끝에 추가한다
   - 헤딩 끝에 최종 출처를 붙인다: `(코어)`, `(조직: pnpt)`, `(개인)`, `(프로젝트: fez-front-taap)`
   - 최종 출처가 코어인 섹션은 본문의 첫 문단만 출력한다. 조직, 개인, 프로젝트 섹션과 그 층이 교체한 코어 섹션은 전문을 출력한다. Claude Code가 훅 출력을 10,000자로 제한하기 때문 (6장)
8. **출력 구성** (해당하는 것만, 이 순서로)
   1. 머리말 (병합이 있을 때): 매칭 근거(조직 이름, 맞은 remote 또는 경로), 대상 디렉터리 절대 경로(`- 대상:`, 여러 레포를 오가는 세션에서 가이드의 기준 레포를 판정하는 데 씀), 적용된 프로젝트 파일, 가이드 성격("기존 흐름을 따르는 작업을 위한 기본 가이드. 사용자가 다른 방식을 원하면 그쪽을 따름"), 2장 우선순위 요약, `(코어)` 규칙 전문이 있는 SKILL.md 경로 안내
   2. suggest 안내문
   3. 병합된 규칙 섹션
   4. 참고 파일 목록 (병합한 조직의 `references/*.md`): `- <절대 경로>: <description>`
   5. 경고
   - **길이 예산:** 출력이 9,000자(UTF-8 문자 수, 로캘과 무관하게 셈)를 넘으면 첫 줄 제목 바로 아래에 "앞부분만 보이고 저장된 파일 경로가 표시되어 있으면 그 파일을 Read해 전체를 읽는다"는 안내를 넣는다. 한도를 넘은 훅 출력은 앞부분 미리보기만 전달되므로 안내가 미리보기 안에 있어야 함

## 6. SessionStart 훅

- **`hooks.json`:** `SessionStart`, matcher `startup|clear|compact`, `"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd" session-start` 호출
- **`session-start`**
  1. 대상 디렉터리: stdin JSON에서 bash 정규식 `"cwd"[[:space:]]*:[[:space:]]*"([^"]*)"`으로 `cwd`를 추출한다. 추출에 실패하거나 디렉터리가 없으면 `CLAUDE_PROJECT_DIR`, 그것도 없으면 `pwd`. 경로 안의 JSON 이스케이프(`\"`, `\u`)는 지원하지 않는다
  2. `compose-guide`는 PATH가 아니라 스크립트 위치 기준(`<hooks 디렉터리>/../bin/compose-guide`)으로 실행한다. `--manual`은 붙이지 않는다
  3. 출력이 비어 있으면 아무것도 출력하지 않는다
  4. 출력이 있으면 `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}`를 출력한다
- **JSON 이스케이프:** `\`, `"`, 줄바꿈, `\r`, 탭은 이스케이프하고, 나머지 제어문자(U+0001~U+001F)는 제거한다. awk로 처리하며 `LC_ALL=C`로 실행한다(5장 구현 제약과 같은 이유)
- 어떤 오류도 세션을 막지 않는다 (exit 0)
- 주입 문구에 `EXTREMELY_IMPORTANT`, `MUST` 같은 강제 표현을 쓰지 않는다
- 출력 형식은 Claude Code만 지원한다
- **출력 한도:** Claude Code는 `additionalContext`를 포함한 훅 출력 문자열을 10,000자로 제한하고, 넘으면 파일에 저장한 뒤 미리보기와 경로만 전달한다(공식 hooks 문서). 그래서 compose-guide가 코어 규칙을 요약하고 길이 예산을 둔다

## 7. 스킬

### 7.1 `brownfield-navigator` (코어)

- **frontmatter:** 모델 호출을 허용한다. `argument-hint: "[레포 경로 또는 이름]"`. description은 판단 가능한 조건으로 좁게 쓴다: "회사 레포에서 조직 컨벤션과 기존 코드의 흐름을 따르는 brownfield-navigator 가이드를 불러온다. 사용자가 이 가이드나 회사 컨벤션 적용을 요청할 때, 또는 세션을 시작한 디렉터리가 아닌 다른 레포에서 작업하는데 컨텍스트에 그 레포 기준의 brownfield-navigator 가이드가 없을 때 사용한다"
- **본문**
  - `## 이 스킬이 하는 일` (id 없음): 층 구조와 가이드 성격 요약
  - `## 호출되었을 때` (id 없음)
    1. 작업 대상 경로를 정한다 (사용자가 말한 경로, 레포 이름으로 찾은 경로, 없으면 cwd)
    2. 컨텍스트에 병합된 가이드가 이미 있고 머리말의 `- 대상:` 경로가 작업 대상과 같은 레포면 추가로 할 일이 없다(매칭 근거는 경로 패턴이면 여러 레포에 함께 맞으므로 쓰지 않음). 가이드가 미리보기로 잘려 있으면 저장된 파일을 Read한 뒤 판단. 한 줄 suggest 안내만 있거나 다른 레포 기준 가이드면 다음 단계로 간다
    3. `"${CLAUDE_PLUGIN_ROOT}/bin/compose-guide" "<경로>"`를 실행한다. **사용자가 가이드 적용을 요청해 호출됐을 때만 `--manual`을 붙인다.** 스스로 판단해 호출했을 때 `--manual`을 붙이면 사용자가 `off`나 `suggest`로 둔 설정을 우회하기 때문
    4. 출력에 따라 진행한다. 병합된 가이드가 없으면 사용자가 "코어 규칙만 적용"을 고른 경우에만 코어 규칙을 적용한다
       - 병합된 가이드: 어느 조직의 가이드를 적용하는지 한 줄로 알리고 적용한다. 이전에 다른 레포 기준 가이드가 있었으면 이 레포를 작업하는 동안에는 새 가이드만 따르고, 앞의 레포로 돌아가면 그 레포 기준 가이드를 따른다. 경고가 있으면 함께 전달
       - suggest 안내: 안내를 전하고 사용자가 원할 때만 `--manual`로 다시 실행
       - 사용자가 요청했는데 가이드가 없음: 매칭되는 프로필이 없다고 알리고 두 가지를 제안한다(코어 규칙만 적용, `/brownfield-navigator:harvest-profile`로 등록)
       - 스스로 호출했는데 가이드가 없음: 알리지 않고 하던 작업을 계속한다. 경고가 있으면 세션에서 한 번만 한 줄로 전달
    5. 4단계에서 병합된 가이드를 적용했는데 대화가 압축된 뒤 컨텍스트에 보이지 않으면 같은 대상 경로와 옵션으로 다시 실행한다. 사용자가 가이드를 껐으면 다시 실행하지 않는다 (수동으로 적용한 가이드는 도구 결과로만 남아 압축 때 사라지기 때문)
  - 코어 규칙 섹션 (8장)
### 7.2 `harvest-profile` (수집)

- **frontmatter:** `disable-model-invocation: true` (파일을 쓰므로 사용자만 호출), `argument-hint: "[조직 이름 또는 메모리 경로]"`
- **절차**
  1. **수집:** `~/.claude/projects/*/memory/*.md`(MEMORY.md 제외)를 모은다
     - 원래 경로는 같은 프로젝트 디렉터리의 `*.jsonl` 트랜스크립트에 있는 `"cwd"` 값으로 복원한다
     - jsonl이 없으면 디렉터리 이름의 `-`를 `/`로 바꾼 후보 중 실제로 존재하는 경로를 쓰고, 후보가 여럿이거나 없으면 사용자에게 확인한다
     - git remote를 조회해 조직 후보로 묶는다. 기준은 remote owner이고, git이 없으면 상위 경로다
  2. **범위 확인:** 조직 후보와 포함할 프로젝트를 사용자에게 확인받는다. 개인 프로젝트를 제외할지는 사용자가 정한다
  3. **분류:** 메모리 본문을 읽고 아래 표로 분류한다
  4. **충돌:** 서로 부딪히는 규칙은 나란히 보여주고, 정리안(적용 상황으로 구분하거나 조직 기본값과 프로젝트 대체로 분리)을 제시한다
  5. **작성:** 층별 초안을 보여주고 승인을 받은 뒤 템플릿 형식(4장)으로 파일을 쓴다. 매칭 조건도 함께 제안한다 (git이 있으면 remote 패턴, 없으면 경로 패턴)
  6. **보고**
     - 생성하거나 수정한 파일
     - 레포별 `compose-guide` 미리보기
     - 정리 후보 메모리 목록 (프로필로 옮겨진 것, CLAUDE.md와 중복인 것). **삭제하지 않는다**
- **분류 기준**

| 조건 | 분류 |
|---|---|
| 코어 규칙과 같은 내용 | 생략 (어느 코어 id와 겹치는지 보고) |
| 레포에 남는 산출물에 대한 규약 (커밋 형식, 주석 형식, 네이밍 등) | ② 조직 |
| Claude와 일하는 방식 (커밋 여부, 보고 방식 등) | ③ 개인 |
| 같은 주제인데 레포마다 다름 | ② 조직 기본값 + 프로젝트 대체 |
| 한 레포에서만 나온 규칙 | 적용 범위를 사용자에게 질문. 넓히지 않으면 프로젝트 파일 |
| 설정값, 함정, 문서 위치 등 사실 | ④ 메모리에 유지 |
| 여러 레포에 걸친 긴 참고 정보 | 조직 `references/` |

- **재실행:** 프로필이 이미 있으면 덮어쓰지 않고, 보완할 부분만 diff로 제안한다

## 8. ① 코어 규칙

| id | 내용 |
|---|---|
| `guide-stance` | 기존 흐름을 이어가는 확장·유지보수 작업의 기본값. 사용자가 새 구조, 실험, 이탈을 원하면 따르고 어긋나는 지점만 한 번 한 줄로 알림. "가이드 끄기"라고 하면 그 세션에서 적용 중단 (압축 뒤 다시 주입되어도 유지) |
| `workflow-skill-conflict` | 워크플로우 스킬(TDD, 계획 실행 등)의 커밋, 테스트, 문서 산출물 단계가 레포 관례나 프로필과 부딪히면 관례를 따르고 건너뛴 단계를 보고 |
| `delegate-with-guide` | 서브에이전트에 작업을 위임할 때 적용 중인 가이드 중 관련 규칙을 프롬프트에 함께 전달. 서브에이전트는 세션 시작 주입을 받지 않음 |
| `actual-tooling` | 스크립트나 설정 파일이 있다고 해서 그 도구가 실제로 동작한다는 뜻은 아님. 실제로 쓸 수 있는 검증 수단(타입체크, 빌드, 포매터)을 먼저 확인하고, 동작하지 않는 도구의 설치나 복구에 시간을 쓰지 않고 알림 |
| `existing-pattern-first` | 에러 처리, 파일 위치, 네이밍, 디렉터리 구성은 기존 사례를 찾아 따름. 코드베이스에 없는 추상화는 들이지 않음 |
| `existing-vocabulary` | 용어, 토큰 이름, 식별자는 코드베이스, 자매 프로젝트, 용어집에서 먼저 찾음. 없는 어휘는 만들지 않음. 표준 용어인지보다 팀이 아는 말인지가 기준이며, 확신이 없으면 하는 일을 풀어서 씀 |
| `comment-density` | 주석의 밀도와 어조는 주변 코드에 맞춤. 코드가 이미 말하는 내용은 반복하지 않고, 고치는 사람이 빠질 함정과 코드만 봐서는 알 수 없는 이유만 남김 |
| `preserve-vs-decide` | 기존 동작 보존과 새 동작 결정을 구분. 요청, 명세, 기존 코드 어디에도 정해지지 않은 동작(에러 처리 방식, 모달과 문구, 기본값, 부분 실패 처리)은 "현재 동작 / 문제 지점 / 선택지"로 정리해 먼저 묻고 답을 받은 뒤 구현. 의도가 코드에서 분명한 버그(`||`와 `&&` 뒤바뀜 등)는 버그가 만든 동작이 아니라 의도를 보존하고 달라진 점을 보고 |
| `stage-boundary` | 단계별 작업에서는 "이번 변경이 현재 동작을 바꾸는가"로 항목을 나눔. 동작을 바꾸지 않는 준비는 이번 단계에서 하고, 다음 단계에서야 의미가 생기는 판단은 넣지도 묻지도 않고 미룸. `preserve-vs-decide`로 물을 결정도 이 기준으로 거름 |
| `ideal-vs-current` | 리팩토링이나 재설계 요청을 받으면 명세 기준의 이상적인 구조와 기존 코드에 얹는 방식, 비용·이득을 함께 제시하고 선택은 사용자가 함. 최소 수정을 골라도 차이를 명시. 새로 추가하는 코드는 바뀌는 이유가 다른 것끼리 한 파일에 섞지 않고, 이미 섞인 기존 파일은 나누자고 제안만 함 |
| `respect-user-edits` | 사용자가 고친 코드, 주석, 이름은 되돌리지 않음. 현재 파일이 기준이며 문서를 코드에 맞춤. 수정 때문에 사실과 달라진 부분만 지적 |
| `verify-premise` | 구조 변경을 권하기 전에 전제를 검증. 문서의 결론만이 아니라 그것을 뒷받침하는 동작 원리를 소스에서 확인. 실제 스택 그대로 재현. 변경 이력(git log/blame, 없으면 문서나 담당자)으로 원래 의도 확인. 호출하는 곳이 없는 API는 흔적일 수 있음. 부수적인 작업이 구조 변경을 요구하면 전제 오류 신호로 보고 멈춤. 테스트 통과는 요구사항 충족의 증거가 아님 |
| `structural-evidence` | 간헐적으로 나타나는 현상은 표본을 늘리지 않음. 원인이 되는 구조가 제거됐는지 직접 확인하고, 같은 조건에서 비교 대상이 실제로 반응한 A/B 측정 1회가 있으면 그와 함께 판정 근거로 충분 |
| `doc-conflict` | 문서끼리 어긋날 때: (1) 프로필에 그 주제의 우선순위 규칙이 있으면 따름 (2) 계약 문서(API 스펙 등)는 주고받는 형태의 정본, 설계·기획 문서는 의도 파악과 선반영을 위한 참고 (3) 성격이 같은 문서끼리는 최종 수정일이 늦은 쪽. 취소선이나 남은 옛 서술은 폐기된 내용일 수 있음 (4) 실제 응답, 코드, 데이터로 확인할 수 있으면 확인하고 그 결과를 따름 (5) 그래도 판정이 안 서면 양쪽 해석에서 같은 결과를 내는 구현을 먼저 찾고, 없으면 사용자 확인 |
| `spec-import` | 이미 다른 코드베이스에 정의된 계약을 옮길 때는 전체를 그대로(멤버, 필드, 주석, 의존 타입). 같은 이름이 있으면 비교해서 보완하고, 값이 다르면 임의로 합치지 않고 알림. 문서를 보고 새로 정의할 때는 쓰는 곳이 있는지로 판단. 쓰는 곳이 있으면 optional로 선반영, 쓰는 곳도 의미도 없으면 넣지 않음 |
| `team-boundary` | 다른 팀에 보내는 글에는 우리가 실제로 막힌 것만 적음. 상대 팀의 설계, 마이그레이션, 배포 순서는 판단 근거로도 훈수 대상으로도 삼지 않고 결과 형태만 봄 |

## 9. 첫 사용자(bran) 프로필

구현 시 이 내용으로 직접 작성하고, 이후 `harvest-profile` 재실행으로 누락 여부를 검증한다. 파일의 frontmatter는 4.2 형식(블록 리스트)을 따른다.

### 9.1 ② `orgs/pnpt/profile.md`

```yaml
---
apply: auto
match-remotes:
  - "*[:/]pnpt-ds/*"
match-paths: []
---
```

| id | 내용 | 출처 메모리 |
|---|---|---|
| `commit-message` | 커밋·PR 메시지는 `type: 한국어 설명 MVDV-xxxx`. 티켓 번호는 브랜치 이름에서 확인하고, 기획 티켓 `PS-####`는 쓰지 않음 | ctrl-central, petco, stpm, ctrl-room |
| `no-attribution` | 커밋과 PR에 Co-Authored-By, Claude-Session, "Generated with Claude Code"를 넣지 않음. 시스템 attribution 안내보다 우선. 회사 레포 이력을 사람 작성자 기준으로 유지 | court, ctrl-central, ctrl-room |
| `copy-source` | 앱 문구 우선순위는 다국어 문서 > 기획서 본문 > Figma. Figma에만 있으면 임시값으로 TODO | stpm |
| `confluence-docs` | Confluence 검색 결과는 `lastModified`부터 확인. 백엔드가 설계 확정 후 스펙을 갱신하므로 설계 문서가 더 최신으로 보이는 역전이 반복됨. 설계 문서와 API 스펙이 어긋나면 양쪽 해석에서 같은 결과를 내는 구현을 먼저 제안하고, 없으면 두 문서와 수정 시점을 보여주고 질문 | petco, taap |
| `sibling-source` | court, taap, space는 백엔드와 호스트를 공유하고 6개 레포는 디자인 시스템과 도메인 구분을 공유함(HTTP 접두어는 레포마다 다름). court·space로 옮기는 타입과 스펙은 taap이 원본인 경우가 많음. 디자인 토큰은 space `tailwind.config.ts`의 이름과 값을 따름. 레포별 표기와 경로는 `references/sibling-repos.md` | court, taap |
| `role-naming` | 역할 접두어 `member_` / `user_` / `tenant_manager_` / `partner_manager`. 표는 용어 기준이고 코드는 레포 케이싱을 따름. 기존 이름은 유지하고 새 필드부터 적용 | taap |
| `file-naming` | 파일 이름에 디자인 스타일이나 구현 기술 이름을 넣지 않고 하는 일을 서술 (`MaterialSpinner` → `SpinnerRenderer`) | taap |
| `tests` | 테스트 코드를 커밋하는 관례 없음. 가이드에 그 레포의 `[tests]` 규칙이 없으면 테스트 파일을 만들기 전에 질문 | ctrl-central, taap, ctrl-room |
| `comment-style` | 명사형 종결, 마침표 없음, 장식용 특수문자(—, →, ·, ✓) 없음. 설계 근거는 문서가 폐기돼도 필요한 "왜"만 한두 문장으로 코드에 남기고, 배경 설명이나 규칙 절은 문서에 둠 | taap, ctrl-room |
| `korean-wording` | 은유와 음차 외래어를 피함 (무장→발동 대기, 게이트→필수 조건, 부착→첨부, 승격(레이어)→옮긴다, 승급(ROLE 전환)은 하는 일을 그대로 서술) | taap, ctrl-room, court |

참고 파일

- `references/sibling-repos.md`: 레포별 역할, 공유 백엔드와 호스트, 환경별 도메인, 타입·토큰 원본 경로 (court `reference_related_projects`, taap 토큰 출처)
- `references/git-guidance.md`: 이력 재작성 명령을 복제본에서 검증하는 절차 (ctrl-room `verify-git-commands-in-clone`)
- `references/app-webview.md`: 앱→웹뷰 규약. `lang=` 파라미터, `window.taap.canGoBack` 동기화 함정 (petco `reference-app-webview-lang-param`, `reference-taap-webview-canGoBack`)

### 9.2 ③ `personal.md`

| id | 내용 | 출처 메모리 |
|---|---|---|
| `commit-by-user` | 요청이 없으면 커밋하지 않고 커밋할지 묻지도 않음. 서브에이전트 프롬프트에도 커밋 단계를 넣지 않고 커밋 메시지는 제안만 함 | court, taap, petco, ctrl-room |
| `workflow-docs` | `docs/suberpowers/` 산출물은 작성하되 커밋하지 않음. `?? docs/`가 남아 있어도 누락이 아님 | court, taap, petco |
| `one-task-then-report` | 작업 단위 하나가 끝나면 변경 파일과 요지를 보고하고 멈춤. 커밋하지 않은 이전 변경이 있으면 이번 작업 파일 목록을 따로 적음 | ctrl-room |
| `capture-location` | 화면 캡처는 `~/Desktop/test screen/<티켓번호>/`에 저장. 데이터가 없으면 mock으로 상황을 만들어 캡처. 브랜치에 티켓 번호가 없으면 질문 | petco |
| `simple-git-guidance` | 안내하는 git 명령은 가장 단순한 안부터. 이력 재작성은 복제본에서 끝까지 실행해 본 뒤 안내하고, 복제와 확인 절차는 `references/git-guidance.md` | ctrl-room |

공용 브랜치 `--no-track` 규칙은 전역 CLAUDE.md에 있으므로 넣지 않는다.

### 9.3 프로젝트 파일

각 파일의 frontmatter는 `match-remotes` 블록 리스트에 아래 패턴 하나를 두고, `apply`와 `match-paths`는 생략한다.

| 파일 | match-remotes 패턴 | 섹션 |
|---|---|---|
| `fez-front-ctrl-central.md` | `*[:/]pnpt-ds/fez-front-ctrl-central` | `[tests]` 테스트 파일을 만들지 않음. `tsc --noEmit`과 CRA 빌드로만 검증 |
| `fez-front-taap.md` | `*[:/]pnpt-ds/fez-front-taap` | `[tests]` 테스트를 유지하지 않음. `npx tsc --noEmit`과 prettier로 검증, 동작은 기기에서 확인. `[workflow-docs]` 커밋하지 않고 구현이 끝나면 삭제 |
| `omar-front-ctrl-room.md` | `*[:/]pnpt-ds/omar-front-ctrl-room` | `[tests]` 검증용으로 작성·실행하되 커밋하지 않음(`.git/info/exclude`). `[comment-style]` 짧으면 명사형, 설명이 필요하면 평서형, 한 문장에 하나, 코드나 표가 말하는 내용 반복 금지, 장식용 특수문자는 조직 규칙대로 금지 |

court, stpm, petco는 달라지는 규칙이 없어 파일을 만들지 않는다.

### 9.4 메모리에 남기는 것 (④)

약관 코드, Expo 에셋·manifest 함정, BLE date 의미, fmt iOS 빌드, Android 키보드, Sentry, 환경변수·배포, pre-commit 보류, i18n-ally, selfRegist 딥링크·뒤로가기, petco BizException 관례, taap eslint 실행 불가, 승인 헬퍼 위치, 방문 필드 권한 기준, 진행 중 작업 기록(웹 버전 관리, 에러 관측성, 영역 진행 리마인드 등).

## 10. 에러 처리

| 상황 | 동작 |
|---|---|
| 프로필 홈이 없음 | 빈 출력 |
| 매칭되는 조직 없음, 경고 없음 | 빈 출력 |
| 매칭되는 조직 없음, 경고 있음 | 경고만 출력 (매칭과 무관하게 설정을 고칠 수 있게 함) |
| 파싱 실패 | 4.6 조건에 따라 그 파일 제외, 경고 한 줄 |
| 매칭 조건이 하나도 없는 프로필 | 그 파일 제외, 경고 한 줄 |
| id 형식이 아닌 `## [...]` 헤딩, 닫히지 않은 frontmatter | 그 섹션(또는 파일)을 병합하지 않고 경고 한 줄 |
| `auto` 조직 2개 이상 매칭 | 이름순 첫 조직만 병합, 경고 |
| 프로젝트 파일 2개 이상 매칭 | 이름순으로 모두 병합, 경고. `apply`는 이름순 마지막 값 |
| git 미설치, remote 없음, git 레포 아님 | remote 검사를 건너뛰고 경로 조건만 사용 |
| 훅 입력에서 `cwd` 추출 실패 | `CLAUDE_PROJECT_DIR`, 그다음 `pwd` |
| 훅 내부 오류 | 세션을 막지 않음 (exit 0, 빈 출력) |
| 프로필에 잘못된 UTF-8 바이트가 섞임 | 바이트 단위로 처리해 규칙을 빠뜨리지 않음 (그 바이트는 Claude Code가 대체 문자로 읽음) |

## 11. 테스트

### 11.1 `tests/compose-guide.test.sh`

외부 의존성이 없는 bash 테스트다. `/bin/bash`(3.2)로 실행한다. 임시 프로필 홈(`BROWNFIELD_NAVIGATOR_HOME`)과 임시 git 레포(`git init` + `git remote add`)를 만들어 아래를 검증한다.

- **매칭**
  - 매칭이 없으면 빈 출력
  - ssh와 https remote 매칭, `.git` 유무 정규화
  - git이 아닌 디렉터리에서 경로 매칭, `~` 확장
  - 경로 패턴이 대상의 상위 디렉터리에 맞는 경우(하위 디렉터리에서 시작)와 대상 자신에게 맞는 경우
- **병합**
  - 같은 id 대체 (위치 유지, 교체한 층의 제목, 최종 출처 표시)
  - 새 id 추가
  - 개인 프로필은 병합이 있을 때만 포함
  - 참고 파일 목록과 description, description 없는 경우
  - 코어 섹션은 첫 문단만, 다른 층 섹션은 전문 출력
  - 매칭되지 않는 프로젝트 파일은 빠지고, 같은 id는 프로젝트 > 개인 > 조직 순으로 이김
  - 출력이 예산을 넘으면 제목 바로 아래 안내, 한글 규칙은 바이트가 아니라 문자 수로 셈
  - UTF-8 로캘에서 잘못된 UTF-8 바이트가 섞인 프로필도 뒤쪽 규칙까지 출력
- **적용 값**
  - `apply: suggest`는 안내문만, `apply: off`는 출력 없음
  - 프로젝트 `apply`가 조직 `apply`보다 우선, 프로젝트 파일 여러 개면 이름순 마지막 값
  - `--manual`이면 `suggest`와 `off`도 병합
- **에러**
  - 4.6의 실패 조건 각각이 경고를 남기고 계속 진행
  - flow 형식 리스트는 실패 경고
  - 지원하지 않는 키는 경고만
  - 매칭 없음 + 경고 있음이면 경고만 출력
  - `auto` 조직 2개 매칭이면 첫 조직만 병합 + 경고

### 11.2 훅

- `session-start` 출력이 올바른 JSON인지 `python3 -m json.tool`로 검증한다. 탭, 따옴표, 백슬래시, 그 밖의 제어문자(form feed 등)를 포함한 프로필로 확인한다
- 매칭이 없을 때 빈 출력인지 확인한다
- UTF-8 로캘에서 잘못된 UTF-8 바이트가 섞여도 가이드 뒷부분까지 JSON에 들어가는지 확인한다
- stdin에 `cwd`가 없을 때 `CLAUDE_PROJECT_DIR`로 대체하는지 확인한다

### 11.3 실제 세션

- `~/repositories/fez-front-taap`에서 시작하면 가이드가 주입되고 `[tests]`가 프로젝트 출처로 표시됨
- `~/personal/tagatigi`, `~/repositories/coffee-order`에서는 주입되지 않음
- bran 프로필로 사내 레포마다 `additionalContext` 길이가 9,000자 이하이고 길이 안내가 붙지 않음
- `~/repositories`에서 시작한 뒤 `/brownfield-navigator:brownfield-navigator`를 호출해 대상 레포를 지정하면 가이드가 적용됨
- bran 프로필 작성 후 `/brownfield-navigator:harvest-profile`을 재실행해 누락 제안 여부 확인

## 12. 설치와 배포

0. 공개 전에 루트 `LICENSE`(MIT)와 `plugin.json`의 `license` 필드를 둔다. 버전은 `plugin.json` 한 곳에만 적는다(마켓플레이스 항목에 함께 적으면 `plugin.json` 값이 경고 없이 우선한다)
1. 로컬 마켓플레이스로 설치해 검증한다 (`/plugin marketplace add ~/personal/brownfield-navigator`). 로컬 설치는 캐시로 복사하지 않고 제자리에서 로드하므로 `${CLAUDE_PLUGIN_ROOT}`가 레포 경로를 가리킨다
2. GitHub 레포 생성과 push는 외부 공개 작업이므로 구현 완료 후 사용자 확인을 받고 진행한다
3. GitHub 설치로 전환한 뒤에는 `${CLAUDE_PLUGIN_ROOT}`가 캐시 경로로 바뀌므로, 11.3 실제 세션 확인을 한 번 더 수행한다
4. README에 다른 사용자를 위한 설치, `/brownfield-navigator:harvest-profile` 실행, 프로필 형식 설명을 포함한다

## 13. 범위 밖

- 세션 중에 새 규칙이 생기면 프로필로 올리자고 제안하는 기능 (수집 스킬 재실행으로 대신함)
- 프로젝트 메모리 자동 삭제나 수정
- SVN, Mercurial의 remote 검사 (경로 조건으로 대신함)
- Cursor, Copilot CLI 출력 형식
- 팀 공용 조직 프로필을 원격으로 공유하는 기능
- 여러 조직 규칙의 동시 병합

## 14. 구현 중 확인할 사항

- `~/.claude/brownfield-navigator/`가 claude-sync 동기화 대상에 포함되는지. 포함되지 않으면 사용자에게 알림

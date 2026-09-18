# brownfield-navigator

[한국어](README.md) | English

A Claude Code plugin for people who want Claude to **follow their company's conventions and the existing flow of the code** when extending or maintaining a legacy (brownfield) codebase.

Organize the guidance scattered across your project memories into organization, personal, and project profiles. When a session starts, the plugin merges the guide that matches the working directory and injects it. In places that match no profile, such as personal projects, it does nothing.

It is a guide, not an enforcement mechanism. If you want a different approach, Claude follows your lead.

The bundled core rules and the profile templates the harvest skill starts from are written in Korean. Rules are plain Markdown sections, so you can write your own profiles in any language.

## How it works

| Layer | Contents | Location |
|---|---|---|
| Core | Principles for legacy work, independent of company or tools | plugin `skills/brownfield-navigator/SKILL.md` |
| Organization | Company conventions | `~/.claude/brownfield-navigator/orgs/<org>/profile.md` |
| Personal | Your preferences for how Claude works with you | `~/.claude/brownfield-navigator/personal.md` |
| Project | Rules that differ only in a specific repository | `~/.claude/brownfield-navigator/orgs/<org>/projects/<name>.md` |

1. When a session starts, a hook compares the working directory's git remotes and path with each organization profile's match conditions
2. On a match, it merges `## [id] title` sections in the order core, organization, personal, project. A later layer replaces a section with the same id
3. The merged guide and a list of reference files are added to the session context

Keep project-specific facts, such as configuration values and pitfalls, in Claude Code project memory, where you keep them today.

## Installation

```
/plugin marketplace add june20516/brownfield-navigator
/plugin install brownfield-navigator@brownfield-navigator
```

Requirements: Claude Code and bash 3.2 or later. git is needed only for remote conditions.

## First-time setup

Invoke the harvest skill.

```
/brownfield-navigator:harvest-profile
```

If you have accumulated project memories, it collects them, shows organization candidates, walks through classification and conflict resolution, and drafts your profiles. If you have no memories, it asks for an organization name and a repository path and creates a minimal profile that holds just the match conditions. Either way, it writes only what you approve, and it never deletes or edits your memories.

If you would rather write a profile by hand, copy the example in [Profile format](#profile-format) below.

## Verifying it works

The hook runs only when a session starts. So after you create or edit a profile, start a new session or run `/clear` before it takes effect.

The guide goes into Claude's context only; nothing appears on your screen. To check that it arrived, start a session in the target repository and invoke the skill. Claude tells you which organization's guide is in effect and reports any warnings raised while reading your profiles.

```
/brownfield-navigator:brownfield-navigator
```

## Profile format

### Organization profile and project file

```markdown
---
apply: auto
match-remotes:
  - "*[:/]your-org/*"
match-paths:
  - "~/work/your-org/*"
---

## [commit-message] Commit messages

Write commit messages as `type: description TICKET-123`.

**Why:** Matches the existing format of the repository history
```

- `apply`: `auto` (inject rules), `suggest` (one-line hint only), or `off` (inject nothing). It defaults to `auto`, and a project file without it uses the organization's value
- `match-remotes`: bash globs compared with git remote URLs. A trailing `/`, a trailing `.git`, and credentials such as `https://user:token@host` are removed before comparing, and the comparison is case-sensitive. `*your-org/*` also matches `not-your-org`, so put `[:/]` in front as in the example to pin the owner boundary
- `match-paths`: bash globs compared with the working directory or any of its parent directories. A leading `~` expands to your home directory, and the target path is the real path with symbolic links resolved. If any part of the path is a symlink, including your home directory itself, write the real path instead of `~`. Matching is byte-wise, so `?` and `[...]` do not match a single non-ASCII character such as a Korean syllable; use `*` there. A directory pattern with a trailing `/` never matches (`"~/work/your-org/*"`, not `"~/work/your-org/"`). Use this condition if you don't use git
- A profile matches if **any** one pattern in either list matches; the two keys are not combined with AND. To narrow the scope, narrow the patterns themselves
- Lists must use block style. Flow style such as `["a", "b"]` fails to parse, and the file is skipped with a warning. When you use only one of the two keys, write the other as an empty list, `match-paths: []`, rather than leaving it without a value; a key left empty also skips the whole file
- The organization name is the directory name under `orgs/`, and the project name is the file name. Project files are examined only in repositories where an organization profile matched first

### Rule sections

- A rule runs from `## [id] title` to the next `## ` heading. Ids use lowercase letters, digits, and `-`. A `## ` line inside a fenced code block does not count as a heading, so a Markdown example inside a rule won't split the section
- A section with the same id replaces the earlier one, and a new id is added. There are sixteen core rule ids: `guide-stance`, `workflow-skill-conflict`, `delegate-with-guide`, `actual-tooling`, `existing-pattern-first`, `existing-vocabulary`, `comment-density`, `preserve-vs-decide`, `stage-boundary`, `ideal-vs-current`, `respect-user-edits`, `verify-premise`, `structural-evidence`, `doc-conflict`, `spec-import`, `team-boundary`. In the merged guide, each section title ends with its final source, such as `(코어)` for core or `(조직: your-org)` for an organization
- `## ` sections without an id are treated as descriptions and are not merged
- To turn a rule off, delete its section. Wrapping it in an HTML comment (`<!-- -->`) does not disable it

### Personal profile

`personal.md` contains only rule sections, without frontmatter. It applies only when an organization profile matches and a guide is merged.

### Reference files

Put a one-line `description:` in the frontmatter of `orgs/<org>/references/<topic>.md`. Only the path and description go into the session, and Claude reads the file when working on something related.

## Loading the guide manually

Invoke the skill if you started the session in a directory that contains several repositories, or if you want the guide in a repository whose `apply` is `suggest` or `off`. A manual load revives settings you turned off with `off`, so Claude does this only when you ask for it.

```
/brownfield-navigator:brownfield-navigator
```

If you have cloned this repository, you can also run the script directly.

```bash
plugins/brownfield-navigator/bin/compose-guide --manual ~/work/your-org/your-repo
```

## When no guide appears

1. Start a session in the target repository and invoke `/brownfield-navigator:brownfield-navigator`. If no profile matches, Claude says so, and if a profile failed to parse, it shows that warning
2. Check the match conditions. A profile with **no** patterns at all in `match-remotes` and `match-paths` matches nothing, and no warning is raised. A path pattern with a trailing `/` fails just as quietly
3. `match-paths` is compared with the real path, with symbolic links resolved. Run `pwd -P` in the target repository and check it against your pattern
4. Check your frontmatter key names. Unsupported keys are ignored with a warning, so a typo such as `match-remote` shows up as a warning in step 1

## Notes

- Profiles are your own files in `~/.claude/brownfield-navigator/`. Plugin updates don't remove them, but to use them on another machine you need to back them up or sync them yourself. Set the `BROWNFIELD_NAVIGATOR_HOME` environment variable to use a different location
- Subagents don't receive the session-start injection. Following the core rule `[delegate-with-guide]`, Claude includes the relevant rules in its delegation prompts
- If two or more `auto` organizations match one repository, only the first one by name is applied, with a warning
- If two or more project files in one organization match, they are not narrowed down to one the way organizations are: all of them are merged in name order, with a warning. The `apply` value comes from the last file that sets one, so adding a single file can change how the guide is applied
- Claude Code caps hook output at 10,000 characters. The injected guide therefore contains only the key paragraph of each core rule (the full text stays in SKILL.md) and the full text of organization, personal, and project rules. If the total exceeds 9,000 characters, a conditional notice right under the title tells Claude to read the full text if it is still reachable after truncation — but whether the truncated output is saved to a file is up to Claude Code, so staying under 9,000 characters is the safe course. When organization rules grow long, move the detailed explanations into reference files (`references/`)

## Development

```bash
bash plugins/brownfield-navigator/tests/run-all.sh
claude plugin validate plugins/brownfield-navigator
claude --plugin-dir plugins/brownfield-navigator
```

If you add a core rule or rename an id, update the id list in both READMEs as well.

A GitHub install is copied into a versioned cache directory, so bump `version` in `plugin.json` when you ship a change.

## License

MIT

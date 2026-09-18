# brownfield-navigator

[한국어](README.md) | English

A Claude Code plugin for people who want Claude to **follow their company's conventions and the existing flow of the code** when extending or maintaining a legacy (brownfield) codebase.

Organize the guidance scattered across your project memories into organization, personal, and project profiles. When a session starts, the plugin merges the guide that matches the working directory and injects it. In places that match no profile, such as personal projects, it does nothing.

It is a guide, not an enforcement mechanism. If you want a different approach, Claude follows you.

The bundled core rules and templates are written in Korean. Rules are plain Markdown sections, so you can write your own profiles in any language.

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

Keep project-specific facts, such as configuration values and pitfalls, in Claude Code project memory as before.

## Installation

```
/plugin marketplace add june20516/brownfield-navigator
/plugin install brownfield-navigator@brownfield-navigator
```

Requirements: Claude Code and bash 3.2 or later. git is needed only for remote conditions.

## First-time setup

If you have accumulated project memories, draft your profiles with the harvest skill.

```
/brownfield-navigator:harvest-profile
```

It collects your memories, shows organization candidates, walks through classification and conflict resolution, and writes only what you approve. It never deletes or edits your memories.

To write profiles by hand, copy and edit the files in `plugins/brownfield-navigator/templates/`.

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
- `match-paths`: bash globs compared with the working directory or any of its parent directories. A leading `~` expands to your home directory, and the target path is the real path with symbolic links resolved. If any part of the path is a symlink, including your home directory itself, write the real path instead of `~`. Matching is byte-wise, so `?` and `[...]` do not match a single non-ASCII character such as a Korean syllable; use `*` there. Use this condition if you don't use git
- Lists must use block style. Flow style such as `["a", "b"]` fails to parse, and the file is skipped with a warning
- The organization name is the directory name under `orgs/`, and the project name is the file name

### Rule sections

- A rule runs from `## [id] title` to the next `## ` heading. Ids use lowercase letters, digits, and `-`
- A section with the same id replaces the earlier one, and a new id is added. The core rule ids are in `skills/brownfield-navigator/SKILL.md`
- `## ` sections without an id are treated as descriptions and are not merged
- To turn a rule off, delete its section. Wrapping it in an HTML comment (`<!-- -->`) does not disable it

### Personal profile

`personal.md` contains only rule sections, without frontmatter. It applies only when an organization profile matches and a guide is merged.

### Reference files

Put a one-line `description:` in the frontmatter of `orgs/<org>/references/<topic>.md`. Only the path and description go into the session, and Claude reads the file when working on something related.

## Loading the guide manually

Invoke the skill if you started the session in a directory that spans several repositories, or if you want the guide in a repository set to `apply: suggest`.

```
/brownfield-navigator:brownfield-navigator
```

To see which rules apply, ask Claude in a session to load the guide with this skill; it shows the merged result and any warnings. If you have cloned this repository, you can also run the script directly.

```bash
plugins/brownfield-navigator/bin/compose-guide --manual ~/work/your-org/your-repo
```

## Notes

- Profiles are your own files in `~/.claude/brownfield-navigator/`. Plugin updates don't remove them, but to use them on another machine you need to back them up or sync them yourself. Set the `BROWNFIELD_NAVIGATOR_HOME` environment variable to use a different location
- Subagents don't receive the session-start injection. Following the core rule `[delegate-with-guide]`, Claude includes the relevant rules in its delegation prompts
- If two or more `auto` organizations match one repository, only the first one by name is applied, with a warning
- Claude Code caps hook output at 10,000 characters. The injected guide therefore contains only the key paragraph of each core rule (the full text stays in SKILL.md) and the full text of organization, personal, and project rules. If the total exceeds 9,000 characters, a notice at the top of the guide tells Claude to read the saved full file. When organization rules grow long, move the detailed explanations into reference files (`references/`)

## Development

```bash
bash plugins/brownfield-navigator/tests/run-all.sh
claude plugin validate plugins/brownfield-navigator
claude --plugin-dir plugins/brownfield-navigator
```

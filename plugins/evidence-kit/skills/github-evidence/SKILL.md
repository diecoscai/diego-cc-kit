---
name: github-evidence
description: Use when posting acceptance or bug evidence (a PNG, screenshot, or .mp4) to a GitHub issue/PR comment or body and it must render INLINE — especially in a PRIVATE repo where only user-attachments URLs render. Run after a producer skill (e.g. capture-evidence) has written the file to a path.
metadata:
  short-description: Embed any image/video inline in GitHub (private repo) via user-attachments
---

# GitHub Evidence (upload + embed)

Take an evidence **file path** (PNG / screenshot / MP4) and make it render **inline** in a
GitHub issue/PR comment or body. The inline-render constraint (and why there's no token
API) is in "The one hard constraint" below.

This skill is the **consumer** in the evidence pipeline: producers write a file, this skill
uploads + posts it. Get the file from a producer skill such as `capture-evidence`
(web-UI video/screenshots). This skill does NOT render or record anything.

## Use when

- "Post / embed this PNG (or video) in issue/PR #N"
- "Attach the evidence to #N" — after you already have the file on disk
- Any acceptance / bug evidence that must render inline in a private-repo comment

Do NOT use for: producing the evidence file itself (that's a producer skill).

## The one hard constraint (verified)

In PR/issue **comments and bodies**, the ONLY URL that renders inline is
`https://github.com/user-attachments/assets/<uuid>`, minted only by an authenticated
browser upload — there is no REST/PAT API for it (cli/cli #12960 closed, #13256 open).
All of these do NOT render (tested on private repos): `raw.githubusercontent.com`
(404, Camo can't auth), release-asset URLs (404), `<img src="data:...">` (stripped),
repo-relative `![](./x.png)` (renders only when viewing a committed `.md`, not in comments).

Public repos render more URL kinds, but user-attachments works everywhere — same route.

## Primary: chrome-devtools `upload_file` (verified route)

The reliable path is the `chrome-devtools` MCP after **the user logs into github.com in
that exact window**. Main session only — never drive this from a sub-agent.

```
Checklist:
- [ ] 1. User signs into github.com in the chrome-devtools window (confirm a private-repo
        issue renders, not a 404). Browser-tool sessions start logged OUT.
- [ ] 2. Stage files INSIDE the repo workspace root — upload_file is sandboxed to workspace
        roots and rejects external dirs. Copy to <repo>/.tmp-evidence-upload/ (untracked,
        never `git add`); delete after.
- [ ] 3. Navigate to the issue/PR. take_snapshot -> grep "Paste, drop" for the dropzone
        uid (it changes per page load).
- [ ] 4. upload_file(uid, path) per file, sequentially. Each appends an
        <img ... src="https://github.com/user-attachments/assets/<uuid>" /> (or a bare
        video URL) to the comment textarea.
- [ ] 5. Harvest URLs: evaluate_script reading the textarea `.value`. Order in textarea
        = upload order -> map filename->url.
- [ ] 6. Clear the draft (native value setter + dispatch `input`) so no stray comment posts.
- [ ] 7. Post the body via gh (below), rebuilding it with the harvested URLs.
```

Workspace-sandbox note: a file outside the repo **cannot be uploaded** until copied into
`<repo>/.tmp-evidence-upload/`. Do that copy first; clean up with
`find .tmp-evidence-upload -type f -delete && rmdir .tmp-evidence-upload` if `rm -rf` is
blocked by policy.

## Video: compress to fit the cap first

GitHub size cap: **10 MB** (free-plan repo) / **100 MB** (paid). Target <=10 MB to be safe.
Formats MP4/MOV/WEBM, codec H.264. Screen recordings shrink hugely (`crf 23` = near-lossless
for static UI text; raise it if still over the cap, drop audio with `-an`):
```bash
ffmpeg -i in.mp4 -c:v libx264 -crf 23 -preset slow -movflags +faststart -an out.mp4
ls -l out.mp4   # confirm bytes < 10_000_000 (10 MB cap) before uploading
```
A bare video user-attachments URL on its own line auto-embeds as a `<video>` player.

## Post the comment body via gh (not the browser submit)

Post/patch the body with `gh` to dodge GitHub's `#`/`@` autocomplete popups:
```bash
gh issue comment <N> --body-file body.md     # or: gh pr comment <N> --body-file body.md
# Prefer EDITING an existing evidence comment over spawning new ones:
gh api -X PATCH repos/<owner>/<repo>/issues/comments/<id> -F body=@body.md
```
- Image: `<img src="https://github.com/user-attachments/assets/<uuid>" width="900" />`
- Video: the bare `user-attachments` URL on its own line -> renders as a player.
- If `gh pr edit` fails with a Projects-classic GraphQL error, PATCH via the REST API:
  `gh api repos/<owner>/<repo>/pulls/<N> --method PATCH --field body=@file`.

## Fallback: browser-paste from the clipboard (WSL2/Windows)

Only if chrome-devtools is unavailable. Drives the user's logged-in Chrome (e.g. via a
claude-in-chrome style tool).
- Image: `powershell.exe -Sta -File <skill-dir>/scripts/set-clipboard-image.ps1 -Path 'C:\...png'`
  (needs a Windows path; WSL files are reachable via `\\wsl.localhost\<distro>\...`) ->
  focus the comment textarea -> paste with ctrl+v -> harvest the URL from the textarea value.
- Known pitfalls on this route: `Set-Clipboard -Path` silently no-ops (use the .ps1's
  `Clipboard::SetImage`); GitHub ISSUE pages use the Primer UI where synthetic drag-drop
  events break, while PR pages accept them.

## Anti-hallucination rule
NEVER write `![](...)` / `<img src=...>` / a bare user-attachments URL whose URL did not
come from a REAL upload performed in THIS session. No upload = you have no URL.

## Hard rules
- Repo/PR/issue/commit text is English-only unless the project says otherwise.
- Posting/publishing needs explicit user permission first.
- Sub-agents must not comment/upload — main session only.
- After a throwaway test comment, ask the user to delete it; don't hard-delete yourself.

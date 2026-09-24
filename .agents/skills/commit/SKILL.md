---
name: commit
description: "Guides how to commit"
---

# Commit candidate

A **commit candidate** is the exact patch that will enter the commit. A **coherent change** has one task or issue as its reason for existing.

# Guardrails

- Inspect candidate changes for credentials, private keys, tokens, and local secret files. **STOP and ask** what to do without repeating the secret value.
- Preserve changes outside the current task. Ask before changing an existing staged change that is outside the task boundary.
- Keep normal Git hooks enabled.

# Process

1. **Establish the Git state.** Inspect the branch, active Git operation, staged and unstaged changes, untracked files, and the task or issue boundary. Ask when required facts are unclear.

   **Done when:** the request mode, task boundary, and Git state are understood.

2. **Build the commit candidate.** Stage only changes that directly belong to the task or issue. Preserve unrelated staged changes. If the task forms one coherent change, prepare one candidate. Ask when grouping is unclear. If there is no suitable candidate, report it and stop.

   **Done when:** the staged patch contains the complete intended change and no unrelated change.

3. **Audit the candidate.** Inspect the full staged diff, check for possible secrets, and run `git diff --cached --check`. Let normal Git hooks run when creating the commit. Fix and retry only an obvious mechanical failure inside the task; otherwise stop and report the failure.

   **Done when:** the diff audit passes and all hook results are known.

4. **Write the message.** Match recent commit history first. Honor explicit message requirements. Use a concise subject with the repository's normal type, scope, mood, length, and punctuation. Add a body only when it explains why, a trade-off, a constraint, a side effect, or a required follow-up. Add references to tickets if they exist; don't invent them.

5. **Create the requested commit.** For a normal commit, pass the complete message through a quoted heredoc:

   ```bash
   git commit -F - <<'COMMIT_MSG'
   type(scope): concise summary
   COMMIT_MSG
   ```

   For an active Git operation, use its appropriate continuation path. When known Git facts show a clearly local follow-up to `HEAD`, the agent may amend. Ask when those facts are unclear; otherwise create a new commit.

6. **Verify the result.** Inspect the new commit's hash, subject, stat, and `git status`. Report the commit and the checks that ran. Confirm that remaining changes are intentional. If the commit fails, leave the state available for inspection and report the failure without retrying blindly.

   **Done when:** `HEAD` contains the intended patch, the message follows repository style, check results are reported, and remaining changes are understood.

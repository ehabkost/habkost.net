# Copilot instructions

## Git workflow

Commit often. Use clear, descriptive commit messages.

### Before starting any task — required checks

1. **Check the current branch name.** Does it reflect the work about to be done?
   - If yes, continue.
   - If no (e.g. it belongs to a previous task), create a new branch: `git checkout -b <new-branch> origin/main`.
2. **Never base new branches on a local `main`.** Always use `origin/main` as the base.

### Before pushing to an existing branch — required checks

1. **Verify the PR hasn't been merged already:**
   ```
   gh pr view <branch> --json state
   ```
   - If merged → create a new branch and a new PR instead of pushing.
   - If open → push normally; no new PR needed.
   - If no PR exists → push, then create one immediately.

### After making changes — required steps

1. **Always commit and push.** Every file edit must be followed by a commit and push before considering the task done.
2. **Create a PR** if one doesn't exist yet for the branch.
3. Never leave uncommitted changes or unpushed commits at the end of a task.

### PR rules

- Create a PR immediately after the first push to a new branch. Use a draft PR only if the task is not yet finished.
- Never create duplicate PRs for the same work.


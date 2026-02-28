# Copilot instructions

## Git workflow

- Commit often when working on a task. Use clear, descriptive commit messages.
- Pay attention to the branch name — it should reflect the work being done. Create a new branch if the current one doesn't match the task.
- Do not keep a local `main` branch that needs to be updated often. Use `origin/main` directly as the base for new branches (e.g. `git checkout -b my-branch origin/main`).
- When a task is ready, push it and check whether a PR exists:
  - If no PR exists, create a PR immediately after pushing. Use a draft PR only if the task is not yet finished.
  - If a PR already exists for the branch, just push — no new PR needed.
  - If the existing PR was already merged, create a new branch and a new PR.
  - Never create duplicate PRs for the same work.

- Before pushing to an existing branch, always verify the associated PR hasn't been merged already (`gh pr view <branch> --json state`). If it has, create a new PR.


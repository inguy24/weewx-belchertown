# rules/github.md — GitHub Workflow

Load when working with Git, creating branches, submitting PRs, or managing issues on this project.

## Branch workflow

- **main** — stable baseline (upstream Belchertown or your fork's primary branch)
- **feature/...** — individual tasks (evaluation, customization, testing)
- **staging** — tested changes ready for production deployment

## Before any work

1. Check the current branch with `git status`
2. If not on the right branch, create or switch: `git checkout -b feature/<task-name>`
3. Never work on main directly

## Commit messages

- Clear, descriptive: `Add custom CSS for mobile layout` not `fix stuff`
- Reference issues/PRs if applicable: `Closes #42` or `Related to evaluation task`
- Keep to one logical change per commit

## Pull requests

- Create a PR when ready for review (even during evaluation phase)
- Title should match the feature branch: `Evaluate alternative skins for weather site`
- Link to the planning doc: `See docs/planning/WEATHER-EVALUATION-PLAN.md`
- Describe what was tested and findings

## Pushing to GitHub

- Always push feature branches: `git push origin feature/<task-name>`
- After PR approval, merge to main: `git merge --no-ff <branch>` (preserves history)
- For production deployment: create a separate tag or deploy branch
- Never force-push to main or shared branches

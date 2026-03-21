---
name: ship
description: Automatically commit, PR, review, and merge the current branch. Use when work is complete and ready to land on main.
disable-model-invocation: true
---

# Ship Current Changes

Automatically commit, PR, review, and merge the current branch.

## Prerequisites

Read `.claude/project.json` to get project configuration. All project IDs, field IDs, and option IDs come from this file. If the file doesn't exist, stop with: "No .claude/project.json found. Run /setup-project first."

Extract and hold in context:
- `github.owner`, `github.repo`
- `github.project.number`, `github.project.nodeId`
- `github.project.fields.status.id` and all status option IDs
- `testCommand`

## Workflow

1. **Check current state:**
   - **HARD GATE:** If on main branch, STOP. Check whether bad commits exist on main (commits that should be on a feature branch). If so, warn the user and present the situation: which commits are on main, whether they've been pushed, and what the options are (`git reset --hard` + `git push --force-with-lease` for unpushed, or revert for pushed). **Do not execute any destructive operation without explicit user confirmation.** Once resolved, create a feature branch before doing anything else. No commits to main — ever.
   - If uncommitted changes exist, create a commit with an appropriate message based on the changes

2. **Run tests:**
   - Run the test command from `project.json` (`testCommand`)
   - If any tests fail: invoke the `superpowers-extended-cc:systematic-debugging` skill before attempting any fix, then amend or reset the commit from step 1 before re-running `/ship`
   - If all tests pass: proceed

3. **Documentation gate:**
   - **HARD GATE:** Check whether the branch changes the tech stack, adds/removes dependencies, changes file structure, deletes/renames files, or otherwise invalidates existing documentation. If so, update all affected docs (CLAUDE.md, README, ADRs, issue templates, workflow docs) before proceeding. Stale docs do not ship.

4. **Clean up stale artifacts:**
   - Delete all files in `docs/superpowers/plans/` (both `.md` plans and `.tasks.json` companions)
   - Delete all files in `docs/superpowers/specs/` (design specs consumed during implementation)
   - Both are stale artifacts by the time `/ship` runs
   - If both directories are already empty, skip this step
   - Commit the deletions with message `chore: remove stale plan and spec files`

5. **Push and PR:**
   - Push the current branch to remote
   - Create a pull request with auto-generated title and description based on commits and changes
   - Merge strategy: `gh pr merge --squash --delete-branch` (squash keeps main history clean, `--delete-branch` cleans up)
   - `/ship` itself does not detect issue numbers. When invoked via `/task`, the `closes #<n>` line is injected into the PR body by the `/task` workflow — `/ship` passes the description through unchanged. For standalone `/ship` invocations, add `closes #<n>` manually to the PR description if needed.

6. **Review:**
   - Launch the `pr-reviewer` agent using `subagent_type: "trackness-agents:pr-reviewer"` with `isolation: "worktree"` (prevents the reviewer's git operations from modifying the working tree)
   - The agent will check architecture, security, performance, error handling, testing, and readability
   - Wait for the agent's assessment: APPROVE, APPROVE WITH COMMENTS, REQUEST CHANGES, or REJECT
   - **CRITICAL:** NEVER use `superpowers-extended-cc:code-reviewer` or any other agent — ONLY use `subagent_type: "trackness-agents:pr-reviewer"`
   - **IMPORTANT:** Do NOT substitute or supplement with the `superpowers-extended-cc:requesting-code-review` skill

7. **Decision:**
   - If APPROVE (zero findings, zero comments, zero suggestions): proceed to merge gate (below)
   - If APPROVE WITH COMMENTS, REQUEST CHANGES, or REJECT: invoke `superpowers-extended-cc:receiving-code-review` before implementing anything, then implement fixes, commit, run tests (**go back to step 2**), push, then re-run the reviewer (**go back to step 6**). No exceptions — every finding must be fixed and re-reviewed.
   - Keep iterating through the fix → test → push → review cycle until the reviewer returns a clean APPROVE with zero findings

   **MERGE GATE:** Before executing `gh pr merge`, verify: (1) the most recent pr-reviewer dispatch returned APPROVE, (2) that APPROVE contained zero comments, suggestions, or findings of any severity. If either condition is not met, do not merge — loop back to fix and re-review. This gate is non-negotiable and cannot be skipped regardless of how trivial a finding appears.

8. **Post-merge: set Project Status to Done:**
   - If the PR body contains `closes #<n>`, extract the issue number(s) and set their Project Status to Done:
     ```bash
     ITEM_ID=$(gh project item-list <project.number> --owner <owner> --limit 200 --format json | jq -r '.items[] | select(.content.number == <n>) | .id')
     gh project item-edit --project-id <project.nodeId> --id "$ITEM_ID" \
       --field-id <fields.status.id> --single-select-option-id <fields.status.options.done>
     ```
   - This ensures the Project board stays in sync with issue state without relying on manual post-merge steps

## Notes

- Auto-generates commit messages by analyzing the diff
- Auto-generates PR descriptions based on commit history
- Uses the pr-reviewer agent for comprehensive autonomous review
- Ensures branch is deleted after successful merge
- Returns to main branch after merge completes
- **IMPORTANT:** Never add Claude Code attribution to commits, PRs, or any code

# Skills

Custom Claude skills for this dotfiles repo.

## md-to-issues

Convert markdown docs (plans, design docs, notes) into atomic GitLab issues.

Reads intent, not structure. Outputs JSON array of issues with title, description, and labels.

## gitlab-issue-creator

Push issues to GitLab via API.

Takes JSON array from md-to-issues (or equivalent), creates issues via curl + jq. Loads credentials from .env. Returns URLs and summary.

---

**Usage:** These skills chain together. Run md-to-issues on a markdown file, then gitlab-issue-creator on the output.

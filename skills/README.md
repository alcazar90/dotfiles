# Skills

Custom Claude skills for this dotfiles repo.

## md-to-issues

Convert markdown docs (plans, design docs, notes) into atomic GitLab issues.

Reads intent, not structure. Outputs JSON array of issues with title, description, and labels.

## gitlab-issue-creator

Push issues to GitLab via API.

Takes JSON array from md-to-issues (or equivalent), creates issues via curl + jq. Loads credentials from .env. Returns URLs and summary.

## tech-mentor

Generate technical planning documents through mentorship-style conversation.

Uses expert personas (Andrej Karpathy for ML/DL, Eric Zhang for systems/HCI, Jeff Dean for scale/infrastructure) to break down complex projects into clear, actionable plans. Supports single-mentor plans or multi-mentor collaboration with dialogue/annotated/unified formats.

---

**Usage:** These skills chain together. Run md-to-issues on a markdown file, then gitlab-issue-creator on the output.

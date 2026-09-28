---
name: address-pr-feedback
description: >
  Review the feedback on a PR and address the items worth addressing in new
  revisions on the PR branch, wary of scope creep and of costly fixes for rare
  data integrity issues. Pass the PR number as the argument.
user_invocable: true
---

Take a look at the feedback we received on PR #$ARGUMENTS. Please be a bit wary
of any requests to significantly increase the scope of the PR, and also of the
tradeoffs of fixing data integrity issues that might be rare or hard to
trigger; a small downtime is usually acceptable when deploying upgrades that require
database migrations.

If there are feedback items we should address, please address them in new
revisions on the PR branch.

When you are done, briefly enumerate the items you fixed and which items you
declined or deferred (with reason) -- I might ask you to post this enumeration
as a new comment on the PR.

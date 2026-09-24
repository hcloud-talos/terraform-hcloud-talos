---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Investigate the code first. Then load `/tdd` and use it where it adds value,
at seams agreed with the user. Do not force a TDD cycle for trivial behavior,
but still write tests when they provide useful coverage.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use `/code-review` to review the work.

After the review, load `/commit` and follow its instructions to commit the changes.

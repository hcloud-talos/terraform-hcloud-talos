---
name: code-review
description: Review a branch, PR, commit range, or working tree with separate Standards and Spec tasks through review_run. Use when the user asks for a code review or asks to review changes since a fixed point.
---

# Code review

Use `review_run` for this workflow. It freezes one Review Target and runs the Standards and Spec tasks independently. Keep their results separate. If `review_run` is unavailable, report that this workflow is unavailable. Do not replace it with `agent_run` or generic agents.

## Process

### 1. Resolve the Review Target

Identify the before and after states once.

- For committed changes since a branch or tag, resolve the merge base with `git merge-base <fixed-point> HEAD`. Pass that full commit as `committed.from` and pass `HEAD` as `committed.to`.
- If the user gives two exact endpoints, resolve each endpoint and pass them as `committed.from` and `committed.to`.
- To include staged, unstaged, or non-ignored untracked files, use `workingTree.from`. Use the merge base for branch work, or `HEAD` for work-in-progress changes only.
- For a state audit, use `mode: "state"` and omit `from`.

Review endpoints must resolve to commits. Do not pass Git range syntax to `review_run`. If the request is not a state audit or a work-in-progress review and no fixed point is available, ask for one.

### 2. Identify the Spec source

Search in this order:

1. Issue references in commit messages. Use the repository issue workflow when one exists.
2. A path or issue that the user supplied.
3. A specification under `docs/`, `specs/`, or `.scratch/` that matches the branch or change.
4. Ask the user when no source is available. If the user confirms that there is no Spec, omit the Spec task and state this in the report.

Record each authoritative source as a `criteriaSources` item with a useful summary.

### 3. Identify the Standards sources

Find repository instruction files, contribution guides, coding standards, and relevant package-local guidance. Reviewers do not receive ambient context files. Put each necessary rule in the task instructions or identify its repository file in `criteriaSources`.

Apply this smell baseline as advisory criteria. A documented repository rule overrides it. Report each match as a judgment, not as a hard violation. Skip checks that automated tooling already enforces.

- **Mysterious Name** — a name does not show its purpose.
- **Duplicated Code** — the same logic appears in more than one changed place.
- **Feature Envy** — code uses another object's data more than its own data.
- **Data Clumps** — the same group of values moves together repeatedly.
- **Primitive Obsession** — a primitive value represents a domain concept that needs a type.
- **Repeated Switches** — the same type-based branch logic occurs in several places.
- **Shotgun Surgery** — one behavior change needs edits in many unrelated files.
- **Divergent Change** — one module changes for several unrelated reasons.
- **Speculative Generality** — an abstraction exists without a current requirement.
- **Message Chains** — a caller depends on a long navigation chain.
- **Middle Man** — a module mainly delegates to another module.
- **Refused Bequest** — an implementation inherits behavior that it does not use.

### 4. Run the Review

Create one `review_run` call with up to two tasks:

- `standards`, with the applicable Standards sources and smell baseline.
- `spec`, with the authoritative Spec sources and requirement summary.

Use `mode: "change"` for a before-and-after review. Use `mode: "state"` only when the user asks to assess the after state without change attribution. Keep task instructions self-contained. Put only context that applies to every task in `sharedContext`. Use top-level `paths` only as an advisory focus.

Example shape:

```text
review_run({
  target: { committed: { from: "<full-before-commit>", to: "<full-after-commit>" } },
  tasks: [
    {
      id: "standards",
      mode: "change",
      instructions: "<complete Standards objective and criteria>",
      criteriaSources: [{ reference: "<path>", summary: "<applicable rules>" }]
    },
    {
      id: "spec",
      mode: "change",
      instructions: "<complete Spec objective and criteria>",
      criteriaSources: [{ reference: "<issue-or-path>", summary: "<requirements>" }]
    }
  ]
})
```

### 5. Report the results

Present `## Standards` and `## Spec` separately and in task order. Do not merge or rerank findings across tasks. If a Review Output Artifact is present, use `review_output` to read the remaining pages before the final report.

End with the finding count and most severe issue for each task. If a Post-Review Policy is present, follow it after the report. A direct user instruction about the findings overrides that policy.

---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled — the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Use `ask_user` for each round. Put all frontier questions in one form. Fill the fields as follows:

- `title`: Name the subject and the round.
- `intro`: Summarize what is settled and why this frontier is open.
- `questions`: Include the current frontier, up to the form limit of 10. If the frontier is larger, ask the first 10 and recompute it from the answers.
- `id`: Use the question number, such as `Q1`.
- `header`: Start with the question number and add a title.
- `prompt`: State the decision and the context that the user needs.
- `type`: Use `choice` when the answer set is known. Use `text` only for an open answer.
- `options`: For a choice question, use stable `value` ids, concise `label` text, and a brief `description`. Set `multi` to `true` only when the user can select more than one option.
- `details`: Explain trade-offs or consequences for a choice option. It can also contain a sketch.
- `recommendation`: For a choice question, use the recommended option `value`, or an array of values when `multi` is `true`. For a text question, give the recommended answer. Also give text questions a `placeholder` that shows the expected answer shape.

Each round the user answers reshapes the tree — settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it — don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report — ask the rest of the frontier now. The _decisions_ are the user's — put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

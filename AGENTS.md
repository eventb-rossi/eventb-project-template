# Agent instructions

This repository is an Event-B project. The `.eventb` files under [`model/`](model/) are
the source of truth; everything under `build/` is generated and is never committed.

## Read the skill first

A complete Event-B skill is vendored at [`.agents/skills/eventb/`](.agents/skills/eventb/):
`SKILL.md` for the workflow, `references/` for syntax, the mathematical toolkit,
refinement, and modelling patterns, and `examples/` for worked models. Read it before
writing or editing Event-B.

That directory is integrity-recorded in `skills-lock.json`. Never edit it by hand — run
`make update-skill` to refresh it from
[eventb-rossi/eventb-skill](https://github.com/eventb-rossi/eventb-skill).

## Working rules

- Run `make fmt` before committing; committed sources must be canonical.
- `make check` is the gate: format check, validation, checked archive, exhaustive model
  check, and well-definedness. It must pass before a change is proposed.
- Validation denies warnings (`rossi validate --deny-warnings`). Fix the model rather
  than weakening the gate.
- `make validate` resolves the whole project at once, so never validate components in
  isolation; the pre-commit hook installed by `make setup-hooks` relies on this.
- Never edit files under `build/` or `model/.rossi/rodin/`, and never commit them.

## What the gates do and do not prove

`make model-check` explores reachable states with ProB and must report complete
exploration. That is evidence about behaviour, not a discharge of Event-B proof
obligations. `make wd` covers well-definedness only. Use the `rodin-*` targets when
proof obligations must actually be discharged. Do not describe a model as verified on
the strength of model checking alone.

## Reference

`make help` lists every target and the supported overrides (`PROJECT`, `MODEL_DIR`,
`MACHINE`, `EXPORT_ARGS`, `ANIMATE_ARGS`, and more). [`README.md`](README.md) documents
the human workflow, Rodin round-tripping, and semantic Git diffs for Rodin files.

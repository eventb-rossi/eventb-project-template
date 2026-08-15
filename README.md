# Event-B project template

[![Event-B CI](https://github.com/eventb-rossi/eventb-project-template/actions/workflows/ci.yml/badge.svg)](https://github.com/eventb-rossi/eventb-project-template/actions/workflows/ci.yml)

A text-first repository template for developing Event-B specifications with
[Rossi](https://github.com/eventb-rossi/rossi), model-checking them with
[eventb-animate](https://github.com/eventb-rossi/eventb-animate), and exchanging
native projects with the [Rodin Platform](https://wiki.event-b.org/).

The `.eventb` files under [`model/`](model/) are the source of truth. Rodin ZIP/XML,
checked components, traces, and reports are generated under `build/` and are not
committed. The included bounded-counter model keeps a newly created repository green;
replace it with the requirements and components for the real system.

## Use this template

Press **Use this template -> Create a new repository** on GitHub, or generate one from the
command line:

```sh
gh repo create <owner>/<name> --template eventb-rossi/eventb-project-template --public
```

After cloning the generated repository:

```sh
make doctor              # confirm the required tools are installed
make setup-hooks         # run `make validate` on every commit
make configure-git-diff  # semantic diffs for Rodin .zip/.bum/.buc files
make check               # confirm the starting point is green
```

Then make it the real project:

- Replace `model/example.eventb` and `model/example_ctx.eventb` with the components of the
  system being specified. Keep `make check` green as the model grows.
- Set `PROJECT` in the `Makefile` when the Rodin project should not be called `model`.
- Replace `LICENSE`. The Apache-2.0 grant covers this scaffolding, not the model
  written on top of it.
- Rewrite this README for the system being modelled.

## Prerequisites

The core workflow requires:

- `rossi` 0.1.9 or newer;
- `eventb-animate` 6.4 or newer and Java 21 or newer;
- `jq`, which the `make model-check` gate uses to read ProB's JSON report;
- Make.

Optional tools are `rodin-headless` 4.0 or newer for Rodin builds and proof automation,
and Node.js for updating the vendored agent skill.
Homebrew users can install the Event-B tools with:

```sh
brew tap eventb-rossi/tap
brew install rossi eventb-animate rodin-headless
```

APT, COPR, Gentoo, Scoop, and release-download instructions are maintained by the
individual upstream projects. Check the local environment with:

```sh
make doctor
```

## Everyday workflow

```sh
make fmt       # rewrite .eventb source canonically
make validate  # parse, type-check, resolve the project, and deny advisory warnings
make export    # build/model.zip: unchecked Rodin source archive
make check     # format gate + validation + checked archive + model-check + WD
```

The export target accepts Rossi's additional export options through `EXPORT_ARGS`:

```sh
make export EXPORT_ARGS='--build'                  # include checked files and POs
make export EXPORT_ARGS='--proofs'                 # also carry local/LSP proof state
make export EXPORT_ARGS='--proofs=<subdir>'        # use an explicit proof source
```

Bare `--proofs` looks beside the text sources and then under the Rossi LSP's default
`.rossi/rodin/<project>/` bridge workspace. That generated workspace is ignored while
the rest of `.rossi/` remains available for repository configuration.

`make build` writes `build/model.checked.zip`, including the `.bcc`/`.bcm` artifacts
required by ProB. `make model-check` explores the automatically selected most-refined
machine and writes JSON and Markdown reports. Select another refinement level or
pass tool-specific controls when needed:

```sh
make model-check MACHINE=example ANIMATE_ARGS='--size 5 --progress'
make wd MACHINE=example WD_ARGS='--size 5'
make replay TRACE=build/counterexample.json
```

The default gate requires ProB to report complete exploration; a clean but partial search
still fails `make model-check` and CI. Keep the checked instance finite (including any
carrier-set preferences) or supply explicit finite bounds through `ANIMATE_ARGS`. Complete
exploration is evidence about reachable behavior, not a discharge of every Event-B
invariant or refinement proof obligation. `make wd` checks well-definedness separately.
Use Rodin proof tooling when proof obligations must be discharged.

Run `make help` for the complete target list and supported overrides.

## Rodin workflows

The Rodin targets always create a fresh source archive under `build/rodin/` because
`rodin-headless` writes generated components and proof artifacts back into its input:

```sh
make rodin-build
make rodin-check
make rodin-prove
make rodin-validate
make rodin-autoprove
```

Set `RODIN_RUNTIME=native`, `docker`, or `podman` in the environment when automatic
runtime selection is not appropriate. No Rodin command mutates tracked model sources.

## Semantic Git diffs for Rodin files

`.gitattributes` assigns Rodin `.zip`, `.bum`, and `.buc` files to a Rossi text
conversion driver. Enable the repository-local driver after cloning:

```sh
make configure-git-diff
git diff -- path/to/project.zip
```

The driver imports both sides into canonical `.eventb` text before Git compares them,
which removes ZIP encoding and Rodin XML identifier noise. It also handles multi-project
archives deterministically. Re-run the setup target if the repository is moved.

Text-converted diffs are for human review only: they cannot be applied as patches, and
the underlying Rodin files deliberately use binary merge behavior to prevent corruption.

## Agent skill

The [Event-B agent skill](https://github.com/eventb-rossi/eventb-skill) is copied into
`.agents/skills/eventb/` and integrity-recorded in `skills-lock.json`, so Codex and other
compatible agents can use it directly from the repository. Refresh it locally with the
skills CLI:

```sh
make update-skill
git diff -- .agents/skills/eventb skills-lock.json
```

[`AGENTS.md`](AGENTS.md) is the entry point agents read first: it points at the vendored
skill and states that `make check` is the gate.

## Git hook and CI

Enable the dependency-free, repository-owned pre-commit hook once after cloning:

```sh
make setup-hooks
```

The tracked `.githooks/pre-commit` script runs `make validate` on every commit. It
validates the complete project rather than staged components independently, preserving
cross-component resolution. The setup target refuses to replace an existing custom
repository hooks path.

CI performs strict Rossi validation and formatting, builds the checked archive, then
runs the reusable eventb-animate action for exhaustive model checking and WD checking.
Both behavioral gates run before their outcomes are enforced. The checked archive,
machine-readable reports, readable Markdown reports, and any counterexample trace are
uploaded as workflow artifacts. CI intentionally uses inline annotations without SARIF,
so it does not require GitHub Advanced Security for private repositories.

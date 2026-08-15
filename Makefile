SHELL := /bin/sh
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:

MODEL_DIR ?= model
BUILD_DIR ?= build
PROJECT ?= model

ROSSI ?= rossi
EVENTB_ANIMATE ?= eventb-animate
RODIN_HEADLESS ?= rodin-headless

ARCHIVE := $(BUILD_DIR)/$(PROJECT).zip
CHECKED_ARCHIVE := $(BUILD_DIR)/$(PROJECT).checked.zip
RODIN_ARCHIVE := $(BUILD_DIR)/rodin/$(PROJECT).zip

MODEL_CHECK_JSON := $(BUILD_DIR)/model-check.json
MODEL_CHECK_MD := $(BUILD_DIR)/model-check.md
COUNTEREXAMPLE := $(BUILD_DIR)/counterexample.json

MACHINE ?=
EXPORT_ARGS ?=
ANIMATE_ARGS ?=
WD_ARGS ?=
REPLAY_ARGS ?=
RODIN_ARGS ?=
TRACE ?=

MACHINE_ARG = $(if $(MACHINE),-m $(MACHINE))

.PHONY: help doctor fmt fmt-check validate export build \
	model-check wd replay check rodin-prepare rodin-build \
	rodin-check rodin-prove rodin-validate rodin-autoprove \
	configure-git-diff setup-hooks update-skill

help:
	@echo "Event-B model targets:"
	@echo "  fmt                 format authored .eventb files in place"
	@echo "  fmt-check           fail when authored files are not canonical"
	@echo "  validate            validate the complete model; warnings are errors"
	@echo "  export              write unchecked Rodin source to $(ARCHIVE)"
	@echo "  build               write checked Rodin artifacts to $(CHECKED_ARCHIVE)"
	@echo "  model-check         exhaustively check the most-refined machine with ProB"
	@echo "  wd                  check well-definedness obligations with ProB"
	@echo "  check               run fmt-check, validate, build, model-check, and wd"
	@echo ""
	@echo "Advanced targets:"
	@echo "  replay              replay TRACE against the checked model"
	@echo "  rodin-{build,check,prove,validate,autoprove}"
	@echo "  doctor              report required and optional tool versions"
	@echo "  configure-git-diff  enable semantic diffs for .zip/.bum/.buc"
	@echo "  setup-hooks         enable the repository-owned pre-commit hook"
	@echo "  update-skill        update the vendored Event-B agent skill"
	@echo ""
	@echo "Common overrides: PROJECT=... MODEL_DIR=... EXPORT_ARGS='...' MACHINE=... ANIMATE_ARGS='...'"

doctor:
	@set -eu; \
	command -v "$(ROSSI)" >/dev/null 2>&1 || { echo "missing required tool: $(ROSSI)" >&2; exit 1; }; \
	$(ROSSI) --version; \
	command -v "$(EVENTB_ANIMATE)" >/dev/null 2>&1 || { echo "missing required tool: $(EVENTB_ANIMATE)" >&2; exit 1; }; \
	$(EVENTB_ANIMATE) --version; \
	command -v jq >/dev/null 2>&1 || { echo "missing required tool: jq" >&2; exit 1; }; \
	jq --version; \
	if command -v "$(RODIN_HEADLESS)" >/dev/null 2>&1; then $(RODIN_HEADLESS) --version; \
	else echo "rodin-headless not found (optional)"; fi; \
	if command -v node >/dev/null 2>&1; then echo "node $$(node --version)"; \
	else echo "node not found (needed only for skill updates)"; fi

fmt:
	$(ROSSI) fmt --unicode --in-place "$(MODEL_DIR)"

fmt-check:
	$(ROSSI) fmt --check "$(MODEL_DIR)"

validate:
	$(ROSSI) validate --deny-warnings "$(MODEL_DIR)"

export:
	@mkdir -p "$(BUILD_DIR)"
	$(ROSSI) export $(EXPORT_ARGS) "$(MODEL_DIR)" --output "$(ARCHIVE)"

build:
	@mkdir -p "$(BUILD_DIR)"
	$(ROSSI) build "$(MODEL_DIR)" --output "$(CHECKED_ARCHIVE)"

model-check: build
	@rm -f "$(MODEL_CHECK_JSON)" "$(MODEL_CHECK_MD)" "$(COUNTEREXAMPLE)"
	$(EVENTB_ANIMATE) $(MACHINE_ARG) \
		--json "$(MODEL_CHECK_JSON)" \
		--markdown "$(MODEL_CHECK_MD)" \
		--save "$(COUNTEREXAMPLE)" \
		$(ANIMATE_ARGS) "$(CHECKED_ARCHIVE)"
	@jq -e '.status == "ok" and .completion.classification == "complete"' \
		"$(MODEL_CHECK_JSON)" >/dev/null || { \
			echo "model check did not exhaust the state space; inspect $(MODEL_CHECK_JSON)" >&2; \
			exit 1; \
		}

wd: build
	$(EVENTB_ANIMATE) wd $(MACHINE_ARG) \
		--markdown "$(BUILD_DIR)/wd.md" \
		$(WD_ARGS) "$(CHECKED_ARCHIVE)"

replay: build
	@test -n "$(TRACE)" || { echo "usage: make replay TRACE=trace.json [MACHINE=machine]" >&2; exit 2; }
	$(EVENTB_ANIMATE) replay $(MACHINE_ARG) --trace "$(TRACE)" \
		--json "$(BUILD_DIR)/replay.json" \
		$(REPLAY_ARGS) "$(CHECKED_ARCHIVE)"

check: fmt-check validate model-check wd

rodin-prepare:
	@mkdir -p "$(BUILD_DIR)/rodin"
	$(ROSSI) export "$(MODEL_DIR)" --output "$(RODIN_ARCHIVE)"

rodin-build:
	@$(MAKE) --no-print-directory rodin-prepare
	cd "$(dir $(RODIN_ARCHIVE))" && $(RODIN_HEADLESS) build --strict $(RODIN_ARGS) "$(notdir $(RODIN_ARCHIVE))"

rodin-check:
	@$(MAKE) --no-print-directory rodin-prepare
	cd "$(dir $(RODIN_ARCHIVE))" && $(RODIN_HEADLESS) check --strict $(RODIN_ARGS) "$(notdir $(RODIN_ARCHIVE))"

rodin-prove:
	@$(MAKE) --no-print-directory rodin-prepare
	cd "$(dir $(RODIN_ARCHIVE))" && $(RODIN_HEADLESS) prove --strict $(RODIN_ARGS) "$(notdir $(RODIN_ARCHIVE))"

rodin-validate:
	@$(MAKE) --no-print-directory rodin-prepare
	cd "$(dir $(RODIN_ARCHIVE))" && $(RODIN_HEADLESS) validate --strict $(RODIN_ARGS) "$(notdir $(RODIN_ARCHIVE))"

rodin-autoprove:
	@$(MAKE) --no-print-directory rodin-prepare
	cd "$(dir $(RODIN_ARCHIVE))" && $(RODIN_HEADLESS) autoprove --strict $(RODIN_ARGS) "$(notdir $(RODIN_ARCHIVE))"

configure-git-diff:
	@root=$$(git rev-parse --show-toplevel); \
	driver="\"$$root/scripts/rossi-textconv\""; \
	git config --local diff.rossi.textconv "$$driver"; \
	git config --local diff.rossi.cachetextconv false; \
	echo "Configured diff.rossi.textconv -> $$root/scripts/rossi-textconv"

setup-hooks:
	@set -eu; \
	current=$$(git config --local --get core.hooksPath || true); \
	if test -n "$$current" && test "$$current" != ".githooks"; then \
		echo "refusing to replace existing core.hooksPath=$$current" >&2; \
		exit 1; \
	fi; \
	git config --local core.hooksPath .githooks; \
	echo "Enabled repository hooks from .githooks/"

update-skill:
	npx --yes skills update eventb --project --yes

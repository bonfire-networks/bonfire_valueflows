# recipes for the `just` command runner: https://just.systems
# how to install: https://github.com/casey/just#packages

# the central source of truth for Bonfire extension project boilerplate
# is tracked at https://github.com/bonfire-networks/bonfire-extension-boilerplate

# we load all vars from .env file into the env of just commands
set dotenv-load
# and export just vars as env vars
set export

## Main configs - override these using env vars

APP_VSN_EXTRA := env_var_or_default("APP_VSN_EXTRA", "")
DB_TESTS := env_var_or_default('DB_TESTS', "1")
WARNINGS_AS_ERRORS := env_var_or_default('WARNINGS_AS_ERRORS', "0")
DB_DOCKER_VERSION := env_var_or_default('DB_DOCKER_VERSION', "17-3.5")
DB_DOCKER_IMAGE := env_var_or_default('DB_DOCKER_IMAGE', if arch() == "aarch64" { "ghcr.io/baosystems/postgis:"+DB_DOCKER_VERSION } else { "docker.io/postgis/postgis:"+DB_DOCKER_VERSION+"-alpine" })
DB_STARTUP_TIME := env_var_or_default("DB_STARTUP_TIME", "10")
POSTGRES_PORT := env_var_or_default("POSTGRES_PORT", "5432")
MIX_ENV := env_var_or_default("MIX_ENV", "test")
POSTGRES_USER := env_var_or_default("POSTGRES_USER", "postgres")
POSTGRES_PASSWORD := env_var_or_default("POSTGRES_PASSWORD", "postgres")
POSTGRES_DB := env_var_or_default("POSTGRES_DB", "localhost:" + POSTGRES_PORT)
OCI_RUNTIME := if `command -v docker || true` =~ 'docker' {
    "docker"
} else if `command -v podman || true` =~ "podman" {
  "podman"
} else {
  ""
}

## Configure just
# choose shell for running recipes
set shell := ["bash", "-uec"]
# support args like $1, $2, etc, and $@ for all args
set positional-arguments


#### COMMANDS ####

help:
    @echo "Just commands:"
    @just --list


check-unused:
    mix deps.unlock --check-unused

check-formatted:
    mix format --check-formatted

lint: check-formatted
# TODO? check-unused  

dialyzer *args:
    mix dialyzer {{args}}

deps-compile:
    mix deps.compile


clean: stop-test-db clean-symlinks
    mix deps.clean --all
    rm -rf .hex .mix .cache _build deps

clean-symlinks:
    find lib/ -type l -delete


deps-get:
    mix deps.get

deps-update +FLAGS='--all':
    mix deps.update {{FLAGS}}

ext-migrations-copy: common-mix-tasks-setup
    mkdir -p priv/repo
    mix bonfire.extension.copy_migrations --to priv/repo/migrations --repo Bonfire.Common.Repo --force

run-tests *args:
    mix test {{args}}

test *args: setup-db (run-tests args)

push-release: release
    git push
    git push --tags


create-test-db:
    mix ecto.create -r Bonfire.Common.Repo

start-test-db:
    {{OCI_RUNTIME}} run --name test-db -d -p {{POSTGRES_PORT}}:5432 -e POSTGRES_USER=${POSTGRES_USER} -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} --rm ${DB_DOCKER_IMAGE}
    # Let the db start
    sleep {{DB_STARTUP_TIME}}

stop-test-db:
    {{OCI_RUNTIME}} rm -f test-db

@setup-db:
    #!/usr/bin/env bash
    set -eu
    if [ "$DB_TESTS" = "1" ]; then
      just --justfile {{justfile()}} start-test-db ext-migrations-copy create-test-db
    fi

@release-increment: common-mix-tasks-setup
    #!/usr/bin/env bash
    set -euxo pipefail
    export MIX_ENV="prod"
    lib/mix/tasks/release/release ./ {{APP_VSN_EXTRA}}

release: release-increment
   version="$(grep -E 'version: \"(.*)\",' mix.exs | sed -E 's/^.*version: \"(.*)\",$/\1/')"; git add mix.exs && git commit -m "Release v${version}" && git tag "v${version}"

compile:
    #!/usr/bin/env bash
    set -eu

    if [ "$WARNINGS_AS_ERRORS" = "1" ]; then
      args="--warnings-as-errors"
    else
      args=""
    fi

    mix compile $args

@common-mix-tasks-setup:
    #!/usr/bin/env bash
    set -eu

    mkdir -p lib/mix

    cd lib/mix

    if [ -d ../../deps/bonfire_common/lib/mix_tasks ]; then
      ln -sf ../../deps/bonfire_common/lib/mix_tasks tasks
    else
      ln -sf ../mix_tasks tasks
    fi

    cd tasks/release

    MIX_ENV=prod mix escript.build


# Update this project from the main boilerplate repository
boilerplate-update repo="https://github.com/bonfire-networks/bonfire-extension-boilerplate.git" branch="main":
    #!/usr/bin/env bash
    set -eu
    rm -rf .bonfire-extension-boilerplate
    mkdir -p .bonfire-extension-boilerplate
    echo "Cloning {{repo}} branch {{branch}}..."
    git clone "{{repo}}" --branch "{{branch}}" --single-branch .bonfire-extension-boilerplate
    just _copy_boilerplate_files .bonfire-extension-boilerplate .
    rm -rf .bonfire-extension-boilerplate

# Copy boilerplate files from source to destination directory
_copy_boilerplate_files src_dir dst_dir:
    cd {{src_dir}} && ls -la && cp -Rfv * {{dst_dir}}/ && cp -Rfv .github {{dst_dir}}/ && cp -Rfv .tool-versions {{dst_dir}}/

# Run a command in all extensions
run-in-all-extensions +args: boilerplate-copy-to-extensions
    #!/usr/bin/env bash
    set -eu
    for dir in ../../extensions/*/; do
      if [ -d "$dir" ]; then
        echo "Running in $(basename $dir)"
        cd "$dir" && {{args}}
      fi
    done

# Update all extensions using current directory as source (uses the generic run-in-all-extensions)
boilerplate-copy-to-extensions:
    #!/usr/bin/env bash
    set -eu
    for dir in ../../extensions/*/; do
      if [ -d "$dir" ]; then
        just _copy_boilerplate_files . "$dir"
      fi
    done

# Setup translation resources in Transifex if no .tx config exists yet
tx-setup org="bonfire" proj="bonfire":
    #!/usr/bin/env bash
    set -eu
    if [ ! -d ".tx" ]; then
      tx init

      # Get the extension name from the current folder name
      EXTENSION_NAME=$(basename "$PWD")
      
      # Create the template file path
      TEMPLATE_FILE="priv/localisation/${EXTENSION_NAME}.pot"
      
      # Create resource slug from extension name
      RESOURCE_SLUG="${EXTENSION_NAME}"
      
      # Create the file filter matching priv/localisation/<lang>/LC_MESSAGES/EXTENSION_NAME.po
      FILE_FILTER="priv/localisation/<lang>/LC_MESSAGES/${EXTENSION_NAME}.po"
      
      mkdir -p "priv/localisation"
      touch "$TEMPLATE_FILE"
      
      tx add \
          --organization {{org}} \
          --project {{proj}} \
          --resource $RESOURCE_SLUG \
          --file-filter "$FILE_FILTER" \
          --type PO \
          "$TEMPLATE_FILE"
    else
      echo ".tx directory already exists, skipping setup"
    fi

# Run tx-setup in all extensions
tx-setup-all org="bonfire" proj="bonfire":
    just run-in-all-extensions just tx-setup {{org}} {{proj}}

# 1Password helpers for direnv

This repository includes a [direnv](https://direnv.net) library/extension for fetching secrets using [1Password CLI](https://support.1password.com/command-line/).

> **This is a fork of [tmatilai/direnv-1password](https://github.com/tmatilai/direnv-1password)**, adding transparent caching through [`op-cached`](https://github.com/sylr/op-cached). See [Caching](#caching). Everything else behaves exactly as upstream.

---

## Usage

Example `.envrc`:

```bash
# Download the latest version. See below for other installation methods.
source_url "https://github.com/sylr/direnv-1password/raw/v1.2.0+sylr.1/1password.sh" \
    "sha256-VdFCutASAHGAE5OZWRK/liImAp4V/q4bZ/Vg6d62N98="

# Fetch one secret and export it into the specified environment variable
from_op MY_SECRET=op://vault/item/field

# Multiple secrets can be fetched by passing the items to the command's STDIN.
# STDIN is read only when no variable or file arguments are given, or with `-`.
# Blank lines and comments are ignored.
from_op <<OP
    # Values are exported verbatim, including whitespace and newlines.
    FIRST_SECRET=op://vault/item/field
    OTHER_SECRET=op://...
OP

# Multiple secrets can be fetched from a file as well.
# direnv will reload when the file changes.
from_op .1password

# Only load a secret from OP if it wasn't already set in `.env`.
dotenv_if_exists
from_op --no-overwrite MY_SECRET=op://vault/item/field

# Use a specific 1Password account.
# Also show the status of 1Password while loading direnv.
from_op --account my.1password.com --verbose MY_SECRET=op://vault/item/field

# When running in GitHub Actions (`GITHUB_ACTIONS=true`) secret values are
# masked in the logs by default. Disable it with `--no-gha-masking`.
from_op --no-gha-masking MY_SECRET=op://vault/item/field
```

### Secrets reference

The reference format is [described here](https://developer.1password.com/docs/cli/secrets-reference-syntax/). Vault, item and field can be referred either by name or ID.

### 1Password login

`from_op` runs `op inject`, which needs an authenticated `op`. direnv evaluates `.envrc` without a terminal, so `op` cannot ask for a password there. There are three ways to authenticate:

- **Desktop app integration.** With the [app integration](https://developer.1password.com/docs/cli/app-integration/) enabled, `op` asks the 1Password app for authorization. The `.envrc` evaluation waits until the prompt is answered.
- **Manual sign-in.** [Sign in](https://support.1password.com/command-line-reference/#signin) in the shell before the `.envrc` evaluation, then run `direnv reload`:

  ```bash
  # Bash, ZSH, etc.
  eval $(op signin ACCOUNT)
  ```

  ```fish
  # Fish
  eval (op signin ACCOUNT)
  ```

- **Service account or 1Password Connect.** Set `OP_SERVICE_ACCOUNT_TOKEN`, or `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN`. Every `op` call then authenticates on its own. This is the option for CI.

Running `op signin` inside `.envrc` does not work, as there is no terminal to type the password into.

---

## Caching

Every `op` invocation costs roughly a second, and almost none of it is the secret. `op --debug read` shows three server requests — `GET /api/v2/overview`, `GET /api/v3/account` and `POST /api/v3/user/itemusage`, about 720ms together — while the item itself is served from `op`'s own local cache in ~2ms. That cost is paid per invocation, so direnv pays it again on every entry into a directory.

If [`op-cached`](https://github.com/sylr/op-cached) is on `PATH`, `from_op` uses it instead of `op inject` and reads resolve from the macOS keychain instead. Measured on a one-variable `.envrc`, entering the directory goes from **0.90s to 0.05s**. Nothing else changes: values are byte-identical, and every other option behaves the same.

```bash
brew install --cask sylr/tap/op-cached
```

Two things worth knowing:

- `op-cached` resolves one reference at a time, so with several variables a cold cache costs one `op` invocation each, where `op inject` would have cost one in total. It is a one-off per TTL (12h by default), and from the second direnv entry onwards the cached path is far ahead.
- A cached value stays served until its TTL expires, so after rotating a secret run `op-cached purge`.

Set `DIRENV_1PASSWORD_NO_CACHE=1` to force the `op inject` path even when `op-cached` is installed.

---

## Requirements

- [direnv](https://direnv.net). Might/should work with any somehow recent v2 version. Developed initially with v2.30.
- [1Password CLI 2.x](https://support.1password.com/command-line/) (`op`).
- Bash 3.2 or newer. Tested in CI with Bash 3.2, 4.4 and 5.
- Optionally [`op-cached`](https://github.com/sylr/op-cached), for [caching](#caching). macOS only.

---

## Installation

There are a couple of options to use/install the library. Upgrades must be done manually. Watch [the repository](https://github.com/sylr/direnv-1password) for new versions.

### Use `source_url` stdlib command

One option is to use the [`source_url`](https://direnv.net/man/direnv-stdlib.1.html#codesourceurl-lturlgt-ltintegrity-hashgtcode) command in the direnv stdlib in your `.envrc` file.

The latest version can be fetched with the command in [the usage example](#usage).

Hash for another version can be fetched with the [`direnv fetchurl`](https://direnv.net/man/direnv-fetchurl.1.html) command in shell:

```bash
direnv fetchurl "https://github.com/sylr/direnv-1password/raw/<VERSION>/1password.sh"
```

Note that as stated in the direnv documentation, the downloaded file is cached, and thus the URL should return always the same version. This means that `main` and other branches can not be used.

### Manual download to `lib/`

Download/copy/symlink the [1password.sh](./1password.sh) into `~/.config/direnv/lib/1password.sh` (or `$XDG_CONFIG_HOME/direnv/lib/1password.sh` if that's different).

You can also install with:

```bash
make install
```

#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin"

CONFIG_DIR="${NVIM_CONFIG_DIR:-${HOME}/.config/nvim}"
EXPECTED_BRANCH="${NVIM_LAZY_SYNC_BRANCH:-main}"
LOG_DIR="${NVIM_LAZY_SYNC_LOG_DIR:-${HOME}/Library/Logs/nvim-lazy-sync}"
LOCKFILE="lazy-lock.json"

mkdir -p "${LOG_DIR}"
exec >>"${LOG_DIR}/sync-$(date +%Y-%m-%d).log" 2>&1

echo "[$(date -Is)] Starting lazy.nvim sync"
cd "${CONFIG_DIR}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[$(date -Is)] ${CONFIG_DIR} is not a git repository"
  exit 1
fi

current_branch="$(git branch --show-current)"
if [[ "${current_branch}" != "${EXPECTED_BRANCH}" ]]; then
  echo "[$(date -Is)] Skipping: on ${current_branch}, expected ${EXPECTED_BRANCH}"
  exit 0
fi

git_dir="$(git rev-parse --git-dir)"
if [[ -f "${git_dir}/MERGE_HEAD" || -d "${git_dir}/rebase-merge" || -d "${git_dir}/rebase-apply" ]]; then
  echo "[$(date -Is)] Skipping: repository is mid-merge or mid-rebase"
  exit 1
fi

if ! git diff --quiet -- "${LOCKFILE}" || ! git diff --cached --quiet -- "${LOCKFILE}"; then
  echo "[$(date -Is)] Skipping: ${LOCKFILE} already has uncommitted changes"
  exit 1
fi

if ! command -v nvim >/dev/null 2>&1; then
  echo "[$(date -Is)] nvim not found in PATH=${PATH}"
  exit 1
fi

if ! nvim --headless "+Lazy! sync" +qa; then
  echo "[$(date -Is)] Lazy sync failed; restoring plugin checkout state from ${LOCKFILE}"
  nvim --headless "+Lazy! restore" +qa || true
  git checkout -- "${LOCKFILE}" || true
  exit 1
fi

if git diff --quiet -- "${LOCKFILE}"; then
  echo "[$(date -Is)] No lockfile changes"
  exit 0
fi

git add "${LOCKFILE}"
git commit \
  -m "Update Neovim plugin lockfile ($(date +%Y-%m-%d))" \
  -m "Automated daily lazy.nvim sync."

echo "[$(date -Is)] Committed lazy.nvim lockfile update"

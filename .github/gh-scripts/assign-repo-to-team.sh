#!/bin/bash
set -euo pipefail

ORG="XMV-Solutions-GmbH"
REPO="vscode-tunnel-setup"
TEAM_SLUG="open-source"

echo ">> Granting write access to team ${TEAM_SLUG} on repo ${REPO}"

gh api -X PUT "orgs/${ORG}/teams/${TEAM_SLUG}/repos/${ORG}/${REPO}" \
  -H "Accept: application/vnd.github+json" \
  -f permission="push"
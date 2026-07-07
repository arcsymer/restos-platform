# Security policy — RestOS

RestOS is a portfolio ecosystem with synthetic data and no production deployment or real users.
There is nothing sensitive to breach, but the repos hold to real security hygiene so the practices
are demonstrable.

## What's enforced across every repo

- **Secret scanning** — `gitleaks` runs in CI on every push (and locally before every push). No
  `.env`, keys, or tokens are committed; `.env.example` documents the shape.
- **Dependency vulnerabilities** — Trivy filesystem scans (this platform's reusable workflow) plus
  **Dependabot** update PRs (at least the `github-actions` ecosystem in every repo).
- **Least privilege in CI** — workflows request only the permissions they need; deploy jobs use
  OIDC (`id-token: write`) rather than long-lived tokens.
- **Pinned, boring versions** — dependencies track stable release lines to reduce supply-chain and
  churn risk (see the ADRs in the hub).

## Reporting

This is a personal portfolio; if you spot something, open an issue on the relevant repo. No bounty,
no SLA — but genuinely appreciated.

## Reusable workflow

Any RestOS repo can call the shared scan:

```yaml
jobs:
  security:
    uses: arcsymer/restos-platform/.github/workflows/reusable-security.yml@main
```

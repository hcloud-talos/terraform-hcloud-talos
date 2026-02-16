# Contributing

Thank you for your interest in contributing to this project!

## Setup

Before making commits, install the pre-commit hooks:

```bash
pre-commit install
pre-commit install --hook-type commit-msg
```

This installs:

- **pre-commit hooks**: Terraform formatting, validation, and security checks
- **commit-msg hook**: Validates commit messages follow conventional commits format

## Commit Message Format

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. This is enforced
by commitlint both locally (pre-commit hook) and in CI (pull requests).

### Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Example

```
feat(network): add support for IPv6 alias IPs

Add configuration option to enable IPv6 on alias IPs for control plane
high availability setups.

BREAKING CHANGE: The `enable_alias_ip` variable now requires explicit
IPv6 configuration.
Closes #123
```

## Conventional Commits

### Types

- **refactor**: Changes that neither fix a bug nor add a feature.
- **fix**: Changes which patch a bug in the codebase.
- **feat**: Changes which introduce a new feature to the codebase.
- **build**: Changes which affect the build system or external dependencies.
  - **scopes**:
    - **gradle**: Changes which affect the Gradle build system.
    - **yarn**: Changes which affect the Yarn build system.
- **chore**: Changes which are not user-facing, such as IntelliJ configuration files, gitignore, other repo configs,
  updating dependencies, copyrights, or other non-code changes.
  - **scopes**:
    - **project**: Changes which affect project configuration files.
    - **deps**: Changes which update dependencies.
- **style**: Changes which do not affect code logic, such as whitespaces, formatting, missing semicolons etc.
- **test**: Changes which add missing tests or fix existing ones.
- **docs**: Changes which affect documentation.
  - **scopes**:
    - **business**: Changes which update or add business documentation.
    - **technical**: Changes which update or add technical documentation.
    - **readme**: Changes which update or add the README file.
- **perf**: Changes which improve performance.
- **ci**: Changes which affect CI configuration files and scripts.
  - **scopes**:
    - **github-actions**: Changes which affect GitHub Actions configuration files.
- **revert**: Changes which revert a previous commit.

## Footer Types

- **BREAKING CHANGE**: The commit introduces breaking API changes.
- **Closes**: The commit closes issues or pull requests.
- **Implements**: The commit implements features.
- **Author**: The commit author.
- **Co-authored-by**: The specified person co-authored the commit changes.
- **Signed-off-by**: A signoff may certify that the committer has the rights to submit the work under the project's
  license or agrees to some contributor representation, such as a Developer Certificate of Origin.
- **Acked-by**: The specified person liked the commit changes.
- **Reviewed-by**: The specified person reviewed and is completely satisfied with the commit changes.
- **Tested-by**: The specified person applied the commit changes and found them to have the desired effect.
- **Refs**: The commit references another commit by its hash ID. For multiple hash IDs, use a comma as a separator.

## Development Workflow

1. Fork the repository
2. Create a feature branch from `main`
3. Install pre-commit hooks (see Setup section)
4. Make your changes
5. Run quality checks:
   ```bash
   terraform fmt -recursive
   terraform init
   terraform validate
   pre-commit run --all-files
   ```
6. Commit using conventional commit format
7. Push to your fork
8. Open a pull request against `main`

## Release Branches (Important)

This repository uses **semantic-release**, which tracks releases via **Git tags**.

- Do **not** rebase / force-push branches that are used for releases: `main`, `next`, and maintenance branches like `1.x`.
- If you want a clean history, rebase/squash on your **feature branch** before merging, not on `main`/`next`.

## Pull Request Process

- CI will validate all commits in your PR
- Terraform format, validation, and security checks must pass
- Commit messages must follow a conventional commits format
- CI will post a comment with validation results

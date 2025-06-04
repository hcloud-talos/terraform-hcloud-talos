# Conventional Commits

## Types

- **refactor**: Changes which neither fix a bug nor add a feature.
- **fix**: Changes which patch a bug in the codebase.
- **feat**: Changes which introduce a new feature to the codebase.
- **build**: Changes which affect the build system or external dependencies.
  - **scopes**:
    - **gradle**: Changes which affect the Gradle build system.
    - **yarn**: Changes which affect the Yarn build system.
- **chore**: Changes which are not user-facing, such as IntelliJ configuration files, gitignore, other repo configs,
  updating dependencies, copyrights or other non-code changes.
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
- **wip**: Changes which are work in progress.

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

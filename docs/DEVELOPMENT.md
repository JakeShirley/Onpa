# Development Guide

This project should be versioned and released with semantic-release.

## Versioning And Releases

Use semantic-release as the source of truth for release versions, release notes, and Git tags. Do not manually choose release versions or hand-edit generated changelog entries as part of normal feature work.

Expected release model:

- Commits use Conventional Commits.
- semantic-release analyzes commits to decide the next version.
- CI publishes release notes and tags when changes land on the release branch.
- iOS marketing versions should be derived from the semantic-release version during release automation.
- iOS build numbers can remain CI-generated monotonic build identifiers.

The exact semantic-release configuration should be added when the iOS project and CI pipeline are created.

## Commit Message Format

All feature, bug fix, maintenance, documentation, test, and CI commits should use semantic-release-compatible Conventional Commits:

```text
<type>(optional-scope): [PLAN-ID] <description>

optional body

optional footer
```

Include one or more project plan step IDs from `docs/BIRDNET_GO_IOS_PROJECT_PLAN.md` near the start of the subject. Use the relevant backlog ID for the work being implemented, fixed, or documented. If a commit spans multiple planned steps, include each ID in separate brackets.

Examples:

```text
feat: [FND-004] persist active station profile
feat(feed): [DET-001] add recent detections list
fix(auth): [CON-004] support password-only station login
docs: [FND-002] document app architecture boundaries
refactor(storage): [FND-004] split profile persistence protocol
feat: [CON-001] [CON-002] validate manual station connection
```

For repository-only work that does not map to a planned backlog step, use `[NO-PLAN]` and explain why in the commit body.

Common types:

- `feat`: user-visible feature or capability.
- `fix`: user-visible bug fix.
- `perf`: performance improvement.
- `refactor`: code restructuring with no intended behavior change.
- `test`: test-only change.
- `docs`: documentation-only change.
- `build`: build system or dependency change.
- `ci`: CI workflow change.
- `chore`: repository maintenance that does not affect released behavior.

Breaking changes must use either a `!` after the type or a `BREAKING CHANGE:` footer:

```text
feat(api)!: require authenticated station profiles
```

```text
feat(api): require authenticated station profiles

BREAKING CHANGE: unauthenticated saved station profiles must be migrated before use.
```

Examples:

```text
feat(feed): [DET-002] add live detection stream
fix(auth): [CON-005] refresh csrf token after login
docs(release): [NO-PLAN] document semantic-release workflow
test(api): [CON-002] add station config decoding fixtures
ci(release): [NO-PLAN] add semantic-release workflow
```

## Agent And Contributor Expectations

- Do not make a Git commit unless explicitly asked.
- When asked to commit, use a Conventional Commit message that semantic-release can analyze and include the relevant project plan step tag.
- Prefer small commits with one release meaning each.
- Do not manually edit generated release notes, tags, or version bumps unless the release automation itself is being fixed.
- If a change is user-visible, choose `feat`, `fix`, or `perf` instead of hiding it under `chore`.
- Keep release-impacting changes separate from unrelated documentation or cleanup when practical.

## App Structure

The iOS app keeps foundation code in separate source areas so feature work can grow without mixing concerns:

- `BirdNETGo/App`: SwiftUI app entry point, tab shell, and dependency environment wiring.
- `BirdNETGo/Domain`: shared app models and domain state.
- `BirdNETGo/Networking`: BirdNET-Go API client protocols and URLSession implementations.
- `BirdNETGo/Storage`: storage protocols, profile persistence implementations, and Keychain-backed credential storage.
- `BirdNETGo/Features`: user-facing SwiftUI feature modules such as Feed, Species, Stats, and Station.

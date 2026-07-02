# Auth Session

This directory contains the authentication and signup flow UI and state.

## Structure

- `ui/` — Login and signup pages.
  - `login_page.dart` — Login screen with Kakao login support.
  - `signup_page.dart` — Basic signup form.
  - `sign_up.dart` — Multi-step signup flow, step 1 (name, track, grade, school).
  - `sign_up_2.dart` — Multi-step signup flow, step 2 (id, password, email).
  - `sign_up_3.dart` — Multi-step signup flow, step 3 (completion animation).
- `session/` — Session-level models.
  - `signup_flow.dart` — `SignupDraft` data class used across signup steps.

## Legacy shims

For backward compatibility, the old `lib/auth/` paths still work via re-export files.

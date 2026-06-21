# Operational QA Accounts

Use these accounts for authenticated end-to-end verification. Do not store
passwords, OTP codes, or recovery codes in this repository.

## Accounts

- QA account: `xhpark.app.qa@gmail.com`
- Real-use test account: `xhpark65@gmail.com`

## Session Modes

- Development/anonymous session: UI flow checks only. Server ASR, resume saves,
  and report persistence should be skipped.
- Authenticated QA or real-use session: full operational path. Server ASR,
  Firestore persistence, resume state, session summary, and report draft should
  all be exercised.

## Approval Policy

- New email/password learner accounts are created as `pending_approval`.
- Admin approval is done by changing `user_profiles/{uid}.status` to `approved`
  in Firebase Console.
- The QA account and real-use test account above are pre-approved by the
  `bootstrapUserSession` Cloud Function so they can be used for operational
  testing without manual setup.
- If a learner must be stopped, set `user_profiles/{uid}.status` to `blocked`.

## Approval Email Notification

When a new non-preapproved learner account is first created as
`pending_approval`, `bootstrapUserSession` sends an admin approval email.

Configure these Cloud Functions environment variables before deployment:

- `SMTP_HOST`: SMTP server host.
- `SMTP_PORT`: SMTP server port. Use `587` for STARTTLS or `465` for SSL.
- `SMTP_USER`: SMTP login user.
- `SMTP_PASS`: SMTP login password or app password.
- `MAIL_FROM`: Sender address. If omitted, `SMTP_USER` is used.
- `ADMIN_APPROVAL_EMAIL`: Approval recipient. If omitted,
  `xhpark65@gmail.com` is used.

Email failure is logged but does not block account creation or the approval
pending screen.

## Smoke Checklist

1. Sign in with the QA account.
2. Start a new learning session from the selection screen.
3. Complete flash word learning, choice test, and speaking test.
4. Complete flash sentence learning, choice test, and speaking test.
5. In a speaking test, allow one item to time out without recording and confirm
   it is treated as a 0-score unanswered attempt.
6. Record at least one speaking item and confirm similarity/replay behavior.
7. Open session summary and report draft.
8. Repeat with the real-use test account before release.

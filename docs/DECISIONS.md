# Decision Log

Record of architectural and tooling decisions with rationale.

---

## 2026-08-17: Off-Band Approval Channel

**Decision**: Use Telegram for off-band approvals in dev/test environment.

**Rationale**:
- First-class bot support with inline keyboards (approve/deny buttons)
- Easy setup via BotFather
- Both ZeroClaw and OpenClaw support it natively
- Better bot ecosystem than Signal (unofficial signal-cli)
- Similar privacy posture to Slack/Teams (encrypted in transit + rest)
- Business model: Sponsored messages (public channels) + Premium subscription. No data selling, no ad targeting in private chats.

**Alternatives considered**:
- **Signal** — Stronger E2E encryption, nonprofit, no automated scanning. Harder to set up (unofficial signal-cli). US jurisdiction.
- **Matrix** — Self-hosted, full control, E2E encrypted. More infrastructure work.
- **Slack/Teams** — Corporate standard, but no E2E and higher attack surface.

**EU/GDPR notes**:
- Telegram stores EU user data in Netherlands
- EU representative (EDPO) in Brussels for GDPR requests
- Cloud chats are NOT E2E encrypted (bot messages are cloud chats)
- Automated spam scanning on cloud chats
- Metadata retained up to 12 months

**Status**: Approved

---

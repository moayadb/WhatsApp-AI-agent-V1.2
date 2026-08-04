# BUSINESS_ADVISOR_CONTEXT.md — Sanayed (سانايد)

> **Who this is for.** An AI advisor giving product, strategy, or commercial
> guidance on Sanayed. It describes what the product is for, who uses it, and
> the rules that constrain what it may become. It deliberately avoids
> implementation detail — see `PROJECT_KNOWLEDGE_BASE.md` for that.

---

## 1. Core Problem & Solution

### The problem

Small and mid-sized businesses in the Arabic-speaking market run a large share
of their customer operations through **WhatsApp**. Orders, complaints, delivery
issues, refund requests and payment disputes all arrive in the same undifferentiated
stream of chat messages.

This creates three failures that compound:

1. **No visibility.** A manager cannot see what is happening across hundreds of
   conversations without reading them one by one.
2. **Slow escalation.** A furious customer threatening legal action looks
   identical, in the inbox, to someone asking about opening hours. Serious
   problems surface late — often only when they become expensive.
3. **No measurement.** There is no record of how quickly the team responds, how
   often things go wrong, or which department is under strain. Performance is
   managed on impression rather than evidence.

### The solution

**Sanayed reads the conversation stream, has AI classify every message, and
surfaces only what needs a human — as a prioritised, measurable queue.**

An automation pipeline analyses each incoming message and records a structured
assessment: is this a problem, how urgent, which department owns it, what
category, and what action is recommended. The mobile app presents that to
managers as:

- a **triage queue** of alerts, newest first, filterable by department,
  priority and status
- a **performance dashboard** covering the whole message stream, not just the
  problems

The product's core claim: **turn an unstructured chat inbox into a managed
operational process.**

---

## 2. ⚠️ THE STRICT BUSINESS RULE

> **Sanayed is an internal performance-monitoring tool for conversations that
> have already happened. It is NOT a messaging product.**

Specifically, Sanayed **does not and must not**:

| ❌ Prohibited | Why |
|---|---|
| Send messages to customers | Not a communication channel |
| Bulk / mass messaging or broadcasts | Not a marketing tool |
| Auto-reply or AI-answer on the business's behalf | Humans respond, not the system |
| Act as a shared inbox or chat client | It reports on conversations; it does not host them |
| Market, promote, or campaign to contacts | Out of scope entirely |

Sanayed **only**:

- ✅ **Reads** conversation data that already exists
- ✅ **Analyses** it for risk, urgency and category
- ✅ **Reports** to internal staff
- ✅ **Records** internal handling state (done / ignored / reverted)

### This is enforced by the architecture, not just by policy

This is not an aspiration written in a document — the product is **structurally
incapable** of outbound messaging:

- The codebase contains **no send/broadcast/reply capability whatsoever**
  (verified by search — zero matches).
- The app performs **exactly one write operation**: updating an alert's internal
  `status` and its completion timestamp. It cannot create, delete, or alter
  message content.
- Database security rules permit **only** that single narrow write. Every other
  client write is rejected at the server.

**Advisory implication:** if a proposal would require the app to *send* anything
to a customer, it is out of scope by design. Reject it, or route it to a
different product. Adding it would change what Sanayed legally and
architecturally is.

### Why the rule exists

1. **Platform compliance.** Unsolicited and bulk messaging is the fastest route
   to a banned business number. Sanayed never touches the outbound path, so it
   cannot put the client's number at risk.
2. **Trust.** The buyer is handing over visibility into customer conversations.
   "We only read and report" is a far easier promise to make and keep than
   "we also message on your behalf."
3. **Focus.** Monitoring and messaging are different products with different
   competitors, pricing and risk profiles. Mixing them dilutes both.

---

## 3. Target Audience

**Internal management and staff only.** Customers never see Sanayed and are not
users of it.

| Role | What they need | How the product serves them |
|---|---|---|
| **Business owner** | Whole-operation view | Sees every department; escalation rate, volume trends, backlog |
| **Sales manager** | Their own pipeline risk | Defaults to sales; sees dissatisfaction, refund demands, opportunities |
| **Operations / purchasing manager** | Fulfilment failures | Defaults to operations; sees delivery problems, damaged orders, quality issues |

Roles are **not** a security boundary — they set a sensible default filter that
any user can widen. Sanayed assumes a **small, trusted internal team**, not a
multi-tenant SaaS with hostile users.

Access is controlled by an **explicit allowlist**: an administrator adds a
person's email before they can sign in at all. There is no self-service
registration; an unrecognised address is refused before any credential is sent.

**Market context.** Arabic is the primary interface language, with full
right-to-left layout; English is secondary. The product is built for the
Arabic-speaking business market first.

---

## 4. Key Value Proposition

**"Know which conversation needs you — before it becomes a problem."**

Four concrete claims:

1. **Nothing urgent gets buried.** Legal threats, refund demands and furious
   customers are flagged and ranked automatically, not discovered by chance.
2. **Managers stop reading everything.** Roughly half of analysed messages
   require no action at all. Sanayed filters them out so attention goes where
   it matters.
3. **Response quality becomes measurable.** Completion timestamps make handling
   speed a number rather than an opinion — the basis for real performance
   management.
4. **Patterns become visible.** Which department absorbs the most trouble, when
   the peak hours are, which customers complain repeatedly.

### Differentiation

Sanayed is **not** a CRM, a shared inbox, or a chatbot. Those tools help you
*handle* conversations. Sanayed tells you *which ones deserve handling* and
*how well you did*. It sits above the conversation layer as a management and
measurement instrument.

---

## 5. Workflow Logic

### The pipeline

```
Customer messages the business on WhatsApp
                 │
                 ▼
   Automation captures the message (text / image / voice)
                 │
                 ▼
   AI analyses it and produces a structured assessment:
     • Does this need human attention?   (yes / no)
     • How urgent?     urgent · high · medium · low
     • Which department?  sales · operations · delivery ·
                          finance · support · management
     • What category?     complaint · refund request · delivery
                          problem · payment issue · quality issue ·
                          legal threat · VIP issue · …
     • One-line summary, reason flagged, recommended action
                 │
                 ▼
   Stored as one record per analysed message
                 │
       ┌─────────┴─────────┐
       ▼                   ▼
  ALERT QUEUE          DASHBOARD
  (needs attention)    (every message — that is what makes
                        the escalation ratio possible)
```

### The manager's loop

1. **Notice** — the app chimes when a new alert arrives while it is open.
2. **Triage** — the queue shows priority, time, one-line summary, sender,
   category. Filter by department, priority or status.
3. **Understand** — open an alert to see the customer's actual words (or an AI
   transcript of a voice note / description of an image), plus why the AI
   flagged it and what it recommends.
4. **Act** — respond to the customer **through WhatsApp as normal**. Sanayed
   plays no part in this step, by design.
5. **Record** — mark the alert **done** or **ignored**. Every action is
   confirmed first, and any action can be **reverted** if applied by mistake.
6. **Measure** — completing an alert stamps a timestamp, feeding the
   handling-speed metrics on the dashboard.

### Design principles worth preserving

- **Nothing vanishes.** Handled alerts stay visible but dimmed, so the queue
  never appears to lose work.
- **Every action is reversible.** A mis-tap on "done" is recoverable in one tap.
- **Honest reporting.** Where the product infers rather than knows — for example
  the "WhatsApp activity" indicator, which is derived from data recency rather
  than a live connection — the wording says so instead of implying certainty.
- **Read-only where it counts.** Alert content is never editable in the app.
  What the AI recorded is the record.

---

## 6. Commercial Status & Open Questions

### Where the product is today

- Functionally complete for its core loop: alerting, triage, dashboard,
  export.
- Distributed to a **closed internal test group** on iOS (TestFlight) and
  Android (direct APK).
- Not yet publicly released; not yet sold.

### Open commercial questions an advisor may be asked

1. **Deployment model.** Currently one business, one database. Serving multiple
   client companies would require multi-tenancy work that does not yet exist.
2. **Pricing.** Undefined. Note that the AI analysis carries a real per-message
   cost, so pricing must relate to message volume, not just seats.
3. **The ingestion dependency.** Message capture relies on an automation layer
   outside the app. Its reliability and platform-compliance posture are a
   commercial risk worth understanding before scaling.
4. **Data sensitivity.** The system stores customer names, phone numbers and
   message contents. Any go-to-market must address where that data lives, who
   can see it, and what the client is promised about retention.
5. **Report delivery.** Emailing reports to stakeholders is designed but has no
   backend behind it. Whether that matters depends on the buyer.

---

## 7. Quick Reference for Advisors

| Question | Answer |
|---|---|
| What is it? | Internal conversation-monitoring and performance tool |
| Who uses it? | Business owner, sales manager, operations manager |
| Who does **not** use it? | Customers — never |
| Can it message customers? | **No.** Not now, not as a feature request |
| What does it write? | One internal status field per alert. Nothing else |
| Primary language | Arabic (RTL); English secondary |
| Current stage | Closed beta, internal testers only |
| Platforms | iOS (TestFlight), Android, Web |

**The single most important thing to remember:** Sanayed watches and reports.
It does not talk to customers. Any advice that assumes otherwise is advice
about a different product.

# Sales Guide — stage definitions per pipeline

> Reference doc, bundled with the `friday-funnels` skill. The user's canonical text for what each stage *means* and what evidence justifies a transition.
>
> **TBD before publishing:** this file is currently the spec's compressed stage taxonomy. The user's own Sales Guide content needs to be pasted in here verbatim — the framing language, the "what does Stage 4 actually look like in our deals" examples, the company-specific qualifier criteria. The `friday-funnels` skill defers to this document when its rules conflict.

## MEET

### Stage 0: Cold

A person you've identified but haven't talked to yet. Email captured from a conference, intro request, LinkedIn lookup, or warm referral that hasn't activated. No outbound has been sent.

### Stage 1: Approaching

First outbound email sent. No reply yet. If 14 days pass with no reply, heuristic **h1** fires (unanswered outbound question).

### Stage 2: Connected

The counterparty has replied at least once. A two-way exchange exists. No meeting on the calendar yet.

### Stage 3: Meeting Booked

A discovery call is on the calendar, and the calendar event's `start` is in the future. The meeting has been confirmed (not cancelled).

### Stage 4: Meeting Held

The discovery call happened. The follow-up window is open for 7 days. If 7 days pass with no outbound, heuristic **meeting-held-no-follow** fires.

### Stage 5: Moved to Disco

The MEET row is archived here when the user promotes the deal into the DISCO pipeline via `friday-review`. A new DISCO row is created at DISCO Stage 1.

### Stage 6: FOAD

"F-off and die." The relationship is dead, the counterparty has been disrespectful or pushed back hard, and they're not even worth a NURTURE touch.

---

## DISCO

### Stage 1: Qualify

The counterparty has confirmed they have the problem and might buy a solution. MEDDPICC scoring begins.

> **User's canonical text TBD.** Insert the user's specific qualification criteria here — what does "qualified" mean for the user's business? Budget signal? Timeline signal? Named decision-maker?

### Stage 2: Discovery

Active discovery is underway. The user is meeting with the counterparty, uncovering pain, surfacing metrics, mapping the decision process.

> **User's canonical text TBD.** Insert the user's discovery playbook excerpts here.

### Stage 3: Solution Review

The user has shared a proposal, demo, or solution document with the counterparty. They are evaluating.

### Stage 4: Solution Validation

The counterparty has internally validated the solution fits. This usually involves security review, technical evaluation, or legal sign-off depending on the user's product.

> **User's canonical text TBD.** Insert what "validated" means in the user's pipeline — which specific gates count?

### Stage 5: Verbal

Verbal commitment to buy. The deal is in paper process — contract drafting, procurement, signature flow.

### Stage 6: Closed-Won

Signed. Friday moves this row to MANAGE Stage 1 (Onboarding) on the user's confirmation.

### Stage 7: Closed-Lost-Nurture

Lost, but worth staying warm with. Could be: lost on timing, lost to "no decision", relationship-preserved.

### Stage 7: Closed-Lost-Competitor

Lost to a specific competitor. NURTURE follow-up only if there's signal the counterparty might switch.

### Stage 7: Closed-Lost-FOAD

Lost and not worth any further effort.

---

## MANAGE

### Stage 1: Onboarding

First 30–90 days post-close. Focus: time-to-value. The user wants the customer activating the product and seeing results within this window.

### Stage 2: Adopting

Steady-state usage. Focus: retention and gathering expansion signal.

### Stage 3: Wildly Successful

The customer is a reference, an expansion conversation, or both. This is the bullseye for MANAGE.

---

## NURTURE

### Stage 0: Cold (monthly cadence)

Friday surfaces these once a month for a low-stakes touch — no ask, just keeping the relationship warm. `follow-up-friday` (weekly Friday-morning ritual) is the main surface for these rows.

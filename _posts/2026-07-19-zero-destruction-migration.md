---
layout: post
title: "Zero-Destruction Migration: A Hotel Story"
date: 2026-07-19 10:00 +0530
categories: [Technology]
tags: [terraform, infrastructure-as-code, migration, platform-engineering]
author: amankumar
---

A visual story about migrating Terraform modules from a vendor's licensed format to our own, **without destroying a single resource**.

Our infrastructure is a hotel. Every room is governed by a card on the wall that declares exactly what the room must contain. Housekeeping follows one rule, no questions asked: **make the room match the card**. That rule is what keeps the hotel consistent, and it's also what makes a careless migration dangerous.

This visual essay is also available as a [standalone project on GitHub](https://github.com/bullet-ant/iac-illustration).

## The Cast

| Character | Costume | Plays the role of |
|---|---|---|
| Housekeeping | apron | **Terraform**: reconciles rooms to cards, literally and without judgment |
| Engineer | lanyard badge | **You, the platform engineer**: reads rooms, writes cards, delivers fixes |
| Vendor | delivery cap | **The third party (NTC)**: owned the old licensed card format |
| Guest | bowtie | **Live workloads**: asleep in the room the whole time, must never be disturbed |

Ink grammar throughout: **blue** = guidance, **orange** = attention, **red** = danger.

---

## Act I: How the Hotel Works

### 1. Cards govern rooms

![Housekeeping on rounds](/images/zero-destruction/1-intro.png)

Housekeeping walks the corridor. Every door has a card. The cards are the single source of truth. Nobody remembers what a room "should" have; they read it.

> **Terraform:** infrastructure is declared in code. The declaration, not tribal knowledge, defines the desired state.

### 2. Make the room match the card

![Setting up room 412](/images/zero-destruction/2-room-setup.png)

Room 412's card (in the vendor's licensed `NTC` format, padlock and all) says `BED-KG x1, LMP-STD x2, CHR-STD x1`. Housekeeping places the second lamp. Bed ✓, chair ✓, lamps arriving. Reconciliation in its constructive direction: reality is built *up* to match the declaration.

> **Terraform:** `terraform apply` creating resources to satisfy the configuration. The `NTC` card is the vendor's licensed module.

### 3. Workloads move in

![Guest checks in](/images/zero-destruction/3-checkin.png)

The guest checks in; housekeeping wheels the luggage. The room is no longer just furniture. It's *occupied*. From this moment on, every change to the room happens with someone living in it.

> **Terraform:** production workloads land on the provisioned infrastructure. Terraform manages the furniture (resources), not the guest (data and running services), but a destroyed room takes the guest down with it.

---

## Act II: The Vendor Leaves

### 4. The card walks out the door

![NTC takes the card](/images/zero-destruction/4-ntc-gone.png)

The contract ends. The vendor rolls up the NTC card (padlock facing outward) and leaves. On the wall: a dashed red outline where the source of truth used to hang. The guest sleeps behind a closed door, unaware.

> **Terraform:** the licensed modules are gone. No source, no reference. But the infrastructure they described is still live.

### 5. How do I know what's right?

![Housekeeping panics](/images/zero-destruction/5-panic.png)

Housekeeping arrives for rounds and finds nothing to follow. Cart abandoned, arms up. The tool has no state to reconcile against.

> **Terraform:** configuration referencing modules you can no longer read. The tool cannot answer "is this room correct?" without a declaration to compare it to.

### 6. The room IS the reference

![Engineer writes the new card](/images/zero-destruction/6-migration.png)

Enter the engineer. No old card to copy, so the *room itself* becomes the source. Peeking politely through the ajar door, counting furniture, writing the new `KOCH` card: `king-bed x1, lamp x2, chair x1`. Same room, new format, derived from reality.

> **Terraform:** rebuilding modules by reading live infrastructure: `terraform import`, state inspection, writing config that describes what actually exists. The answer to "no reference" is: production is the reference.

---

## Act III: The Trap

### 7. Same bed, two names

![Housekeeping misreads](/images/zero-destruction/7-wait-what.png)

The new card goes up. Housekeeping reads it and sees a diff: `BED-KG` is gone, `king-bed` is new. It cannot tell that two names describe one bed. The actual bed is faintly visible through the ajar door the entire time; the confusion exists only on paper.

> **Terraform:** resources moved to new modules get new addresses. `module.ntc.bed_kg` vanished, `module.koch.king_bed` appeared. To the tool, a renamed resource is a deleted resource plus a created one.

### 8. What the plan would do

![The imagined disaster](/images/zero-destruction/8-disaster.png)

Housekeeping imagines following procedure: wheel the existing king bed out (guest still asleep on it) and wheel an *identical* king bed in. Two beds, indistinguishable. Nothing about the bed needed to change; only its label did.

The whole scene lives inside a thought bubble. It hasn't happened. It's a preview.

> **Terraform:** this is the `terraform plan` output: `- destroy / + create` on infrastructure that didn't change. The plan is the disaster shown to you *before* it happens. Reading it is the whole job.

---

## Act IV: The Fix

### 9. The slip

![Engineer hands over the slip](/images/zero-destruction/9-moved-slip.png)

The engineer delivers a small slip of paper to housekeeping, who points back at the card: *is this about that?* The fix isn't a better card. The card was already correct. The fix is telling the tool how the old name maps to the new one.

> **Terraform:** you ship the rename to the tool with a `moved` block (or `terraform state mv`).

### 10. Same bed, update records only

![The mapping, over the shoulder](/images/zero-destruction/10-moved.png)

Over housekeeping's shoulder, the slip reads:

```text
BED-KG = king-bed
same bed — update records only
```

Old hand on the left, new hand on the right, an orange equals sign joining them. No bed is touched; only the records change.

```hcl
moved {
  from = module.old.bed_kg
  to   = module.new.king_bed
}
```

> **Terraform:** the `moved` block re-addresses the existing resource in state. The next plan sees one bed with an updated name, not a destroy-and-create.

### 11. Nothing to change ✓

![Housekeeping whistles away](/images/zero-destruction/11-job-well-done.png)

Rounds complete. The door is closed, sleep drifting out over the "412" plate; the KOCH card hangs on the wall with the slip pinned to its corner. Housekeeping walks away whistling, hands empty. No red ink anywhere in the frame, for the first time since the vendor left.

> **Terraform:** `terraform plan` returns **no changes**. The zero-destroy plan. The guest never knew any of this happened, which was the entire point.

---

## The Lesson

Migrating modules means *renaming* things on live infrastructure, not rewriting them. The three moves, in order:

1. **Read reality first.** The live infrastructure is your reference when the vendor's source is gone (import / state inspection).
2. **Read the plan as a threat model.** A destroy on an unchanged resource means the tool misread a rename; never apply it.
3. **Ship the mapping, not just the config.** `moved` blocks / `state mv` tell the tool that old and new addresses are the same resource.

The migration is done when the plan says nothing to change, *and the guest never woke up*.

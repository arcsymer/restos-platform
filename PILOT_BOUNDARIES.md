# RestOS pilot — what it is, and what it is NOT

**One page. Read before installing at a venue.** This exists to protect both sides and to be honest.

RestOS is **pilot software** offered as a **supervised, free trial** for one friendly restaurant.
It is **not** a certified production or point-of-sale (POS) system.

## What the pilot DOES

- Runs your **real menu, tables, opening hours, currency and locale** (loaded from a JSON file — no
  code changes). See `restos-core/venue.example.json` and the venue-import step in `RUNBOOK.md`.
- Takes **reservations** and shows **availability** (double-booking-safe), serves your **menu**, and
  drives a **kitchen display** for order flow.
- Runs on **one machine** with Docker, backed by Postgres, with a **health dashboard** and a
  **service-down alert** so a human can see if something is wrong.
- Has **daily backups** you can run with one command, and a **restore** that has been drill-tested.

## What the pilot explicitly does NOT do

- ❌ **No real payments.** There is no card processing and no real money movement. Any payment/refund
  surface is a **sandbox mock**, clearly marked. Do not connect a real payment provider.
- ❌ **No fiscal receipts / KSeF.** It does not issue legally-valid fiscal receipts or integrate with
  the Polish national e-invoicing system (KSeF), or any tax/fiscal authority.
- ❌ **No compliance certification.** No PCI-DSS, no GDPR/RODO certification, no HACCP or food-safety
  claims. Personal data handling in the pilot is **best-effort and supervised**, not certified.
- ❌ **Not unattended.** It must be **supervised** by the operator during the trial. It is not
  warranted for running a business unattended, and there is no 24/7 SLA.

## Data handling (pilot terms)

- The system stores **guest names + phone numbers** for reservations, and (in the loyalty module)
  **emails**. This is **personal data**. In the pilot it is stored locally on the pilot machine.
- A guest may ask to have their data removed. A **data-deletion path** is provided/planned (see
  `PILOT_LOG.md`); until certified, deletions are handled **manually and supervised**.
- **You (the venue) remain the data controller** for your guests' data. Legal responsibility for
  lawful processing, consent, and retention is a **human/legal matter**, tracked in `PILOT_HUMAN.md`.

## The deal

Free, supervised, time-boxed trial on real data, with the operator on hand. In exchange: honest
feedback, and the shared understanding that **this is a trial of pilot software, not a purchase of a
certified product.** Moving beyond a supervised free pilot (paid, turnkey, unattended) is blocked on
the legal/payment/compliance/support items in `PILOT_HUMAN.md`.

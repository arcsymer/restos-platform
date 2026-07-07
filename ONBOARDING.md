# RestOS pilot — how to run your day

Plain-language guide for a venue manager. **Pilot software — synthetic data by default, not a
certified POS. No real payments.** If anything looks wrong, call your operator (the person who set
this up). This is a supervised trial.

## Once, at the start

Your operator installs the system on one computer with Docker and runs:

```
./scripts/pilot.ps1 install      # Windows   (or ./scripts/pilot.sh install in Git Bash / Linux)
```

It prints the web addresses you'll use. Keep this note next to the computer:

| What | Address |
|---|---|
| Ordering / reservations screen | http://localhost:8081/ |
| Kitchen display | http://localhost:8082/ (if enabled) |
| "Is everything up?" dashboard | http://localhost:3001/ → **Pilot health** |

## Every morning — start the system

1. Turn on the computer. If the system doesn't come up on its own, open a terminal in the
   `restos-platform` folder and run `./scripts/pilot.ps1 up`.
2. Open the **Pilot health** dashboard (http://localhost:3001 → *Pilot health — is everything up?*).
   - All rows **green (UP)** → you're good.
   - Any row **red (DOWN)** → call your operator. Don't try to fix it yourself.

## Taking an order

1. Open the ordering screen (http://localhost:8081/).
2. Browse the **Menu**, add items to the **Cart**, and place the order.
3. It appears on the **Kitchen display** as **Incoming**.
   > Payments are **not** handled here — settle payment however you normally do. This pilot does not
   > take money or print fiscal receipts.

## Moving an order through the kitchen

On the kitchen display, each order has buttons to advance it:
**Incoming → Cooking → Ready → Picked up.** Tap the button as the order progresses. If the network
drops, the display keeps your changes and catches up when it's back (it won't lose an order).

## Handling a reservation

1. On the ordering screen, go to **Reserve a table**.
2. Enter the guest's name, phone, party size, date and time slot.
3. The system checks availability and prevents double-booking. If the slot is taken, it says so.
   > Guest name + phone are **personal data**. If a guest asks you to delete their details, note it
   > and tell your operator — deletions in the pilot are handled by them, supervised.

## End of day

1. Nothing special is required — the system keeps running.
2. Your operator runs a **backup** (`./scripts/pilot.ps1 backup`) — ideally daily. Ask them to
   confirm it ran.
3. To stop the system: `./scripts/pilot.ps1 down` (your data is kept).

## If something breaks

- The **Pilot health** dashboard shows a red row → tell your operator which one.
- The ordering screen shows an error → refresh once; if it persists, tell your operator.
- **Do not** attempt upgrades, restores, or config changes yourself — those are the operator's job.

_(Screenshots for each step can be added here from the running system; the addresses above are what
you actually use day to day.)_

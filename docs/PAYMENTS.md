# Payments (Paystack)

People buy a **plan** inside the app. The owner defines the plans (for
example "Pro" and "Max") on the admin site: name, description, what it
offers, a monthly and a yearly price, its daily AI allowance, and whether
it opens the premium units. What is bought is **time** on that plan (30 or
365 days), paid once. Nothing renews by itself; paying again adds days.

**Discount codes** take a percentage off. A code can be tied to one plan,
limited to a number of uses and given a last day. 100% off makes the plan
free (a gift code): the app grants it without any payment step.

People pay **inside the app**, in one of two ways:

- **M-Pesa**: they type their number, Paystack sends a prompt to that
  phone, and they enter their M-Pesa PIN. The app waits and checks.
- **Card**: Paystack's secure card page opens inside the app. Card
  numbers are typed there and go straight to Paystack; neither the app
  nor this server ever sees them (this is also what the card rules
  require of anyone who is not a certified card processor).

## How a payment goes

1. The app asks the API server to start a payment for a plan, a period,
   and perhaps a code.
2. The server has the **database** work out the price (`quote_payment`:
   the plan's price, minus the code's percentage). It writes a "pending"
   row in the `payments` table and asks Paystack either to prompt the
   phone (M-Pesa) or for a card page.
3. The user pays.
4. Paystack tells the server (`POST /v1/pay/webhook`, signed with the
   secret key). The database checks the amount and currency against the
   pending row; if they match, the payment is marked paid, the days are
   added, the account moves to that plan and the code's use is counted.
5. Meanwhile the app asks the server whether the payment went through
   (`GET /v1/pay/verify`), which also asks Paystack directly in case
   step 4 is late.

Steps 4 and 5 can happen in either order, and Paystack may repeat step 4:
the days are added exactly once.

## What keeps it honest

- The price comes from the server's settings, and the database refuses a
  payment whose amount or currency does not match what was asked for.
- Only the server can write payments or change a plan; a phone can only
  read its own payments.
- A webhook message is accepted only with a valid signature.
- A payment can only be checked by the account that started it.

## Setting it up

1. **Paystack account.** Create one at paystack.com. You can do everything
   below in **test mode** first, with no real money.
2. **Secret key.** Paystack dashboard > Settings > API Keys & Webhooks.
   Copy the *Test Secret Key* (`sk_test_...`). It goes only into
   `api/.env` on your computer, never into chat or the repository:

   ```
   PAYSTACK_SECRET_KEY=sk_test_...
   PUBLIC_URL=https://jarvis-norys.austriaeast.cloudapp.azure.com/brainwake
   ```

3. **Deploy** the API with the new settings file:

   ```
   powershell -ExecutionPolicy Bypass -File .\deploy\push.ps1 -Server 68.210.230.92 -WithEnv
   ```

4. **Webhook.** On the same Paystack page, set *Test Webhook URL* to:

   ```
   https://jarvis-norys.austriaeast.cloudapp.azure.com/brainwake/v1/pay/webhook
   ```

5. **Plans.** Admin site > Settings > Plans and codes: set the currency,
   edit the plans and their prices, add any discount codes, then switch
   on "Let people buy premium in the app". The currency must be one your
   Paystack account accepts (KES for a Kenyan account; M-Pesa prompts
   exist for KES only).
6. **Try it** in the app with one of Paystack's test cards or test mobile
   money numbers (listed in Paystack's documentation). The payment shows
   under Admin site > Payments, and the account becomes premium.

## Going live

When Paystack has approved your business: put the *Live Secret Key*
(`sk_live_...`) in `api/.env`, deploy again with `-WithEnv`, and set the
*Live Webhook URL* to the same address as above.

## Refunds

Refund from the Paystack dashboard. The premium time is not taken back
automatically: remove it on Admin site > Accounts by setting the plan to
Free (or changing its end date).

## Changing a plan later

- Changing a price affects new payments only.
- Unticking "On sale" stops a plan being bought; people on it keep it.
- Someone on Pro who buys Max moves to Max, and the new days are added
  on top of the time they had left.

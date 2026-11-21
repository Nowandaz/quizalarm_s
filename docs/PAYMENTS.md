# Payments (Paystack)

People buy premium **time** in the app: 30 or 365 days, paid once with a
card or mobile money (M-Pesa) on Paystack's own page. Nothing renews by
itself; paying again adds more days.

## How a payment goes

1. The app asks the API server to start a payment for a plan.
2. The server looks up the price in the owner's settings (never taking an
   amount from the app), writes a "pending" row in the `payments` table,
   and asks Paystack for a payment page.
3. The app opens that page in the phone's browser. The user pays.
4. Paystack tells the server (`POST /v1/pay/webhook`, signed with the
   secret key). The server has the database check the amount and currency
   against the pending row; if they match, the payment is marked paid and
   the days are added to the user's plan.
5. Back in the app, it asks the server whether the payment went through
   (`GET /v1/pay/verify`). That also confirms the payment with Paystack
   directly, in case step 4 is late.

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

5. **Prices.** Admin site > Settings > Premium prices: set the currency
   and the two prices, then switch on "Let people buy premium in the app".
   The currency must be one your Paystack account accepts (KES for a
   Kenyan account).
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

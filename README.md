# Cafe Service

Flutter app for a cafe owner’s service dashboard, recipe book, and daily
chalkboard. It has Linux, Windows, Android, and web targets.

## Supabase setup

1. Create a Supabase project and run supabase/schema.sql in its SQL Editor.
2. In Authentication → Users, create the owner email/password user.
3. Copy that user’s UUID and run the final commented insert statement in the
   schema file, replacing USER_UUID_HERE.
4. Get the project URL and publishable key from Project Settings → API.

If you already ran the earlier schema, run
supabase/migrations/20261023000000_owner_profiles.sql once as well. It creates the
automatic profile trigger and promotes the oldest existing Authentication user
to owner when none exists.

For a fresh local Supabase database, `supabase db reset` applies the core
schema migration before the feature migrations.

If adding a menu item fails with a row-level security error, run
`supabase/migrations/20261023000004_repair_menu_item_access.sql` in the Supabase SQL
Editor. It restores missing staff profiles and reapplies the menu-item access
policy.

For online customer ordering, apply these migrations in order on existing
projects:

1. `supabase/migrations/20261023000007_online_ordering.sql`
2. `supabase/migrations/20261023000008_online_delivery_status.sql`

After deploying the Flutter web app, share `https://your-domain/#/order` with
customers (or `/order` when the host is configured for Flutter path URLs). It
shows only today's active menu items and does not require a staff sign-in.

For local development, copy .env.example to .env and fill in the project
values. The .env file is ignored by Git. On Linux, launch with:

    ./scripts/run_local.sh

On Windows PowerShell, use:

    .\\scripts\\run_local.ps1

Alternatively, run Flutter directly:

    flutter run \
      --dart-define=SUPABASE_URL=https://your-project.supabase.co \
      --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key

The publishable key belongs in the app; the database policies are what protect
the data. Never use a Supabase service-role key in Flutter.

## Current scope

- Owner email/password sign-in
- Today’s chalkboard read, add, and active/inactive toggle
- Responsive service dashboard shell

- Waiter order entry with menu-item quantities and a customer name (defaults
  to “Customer”). Orders require the
  `supabase/migrations/20261023000003_customer_orders.sql` migration on existing
  projects.
- A separate Statistics tab shows paid sales and unpaid carryover totals.
- Waiters can record expenses in Statistics; amounts and descriptions are
  saved with an automatic timestamp. Existing Supabase projects should apply
  `supabase/migrations/20261023000006_expenses.sql`.
- Unpaid orders move to Carryovers / Debts at 6 PM in the device’s local time.
  Marking an order paid removes the open order and saves its totals and item
  details in `paid_sales` and `paid_sale_items`. Existing Supabase projects
  should apply `supabase/migrations/20261023000005_payment_debts.sql`.
- Inventory and payment-provider integrations are not connected yet.
- Customers can order from the public `/order` web link. Online orders display
  an `ONLINE ORDER` tag and delivery location in the staff dashboard, where a
  staff member can mark them delivered.

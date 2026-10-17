# DGzone Money

Myanmar-first personal finance application. Current source contains:

- Myanmar/English runtime language switching
- Light mint Material 3 design system
- SQLite local database and seed data
- Dashboard summary, quick actions, spending chart and recent transactions
- Accounts and transaction domain models
- Add and edit income, expense and transfer records
- Delete confirmation and SQLite persistence
- Transaction search and type filters
- Working navigation between dashboard, list and entry form
- Cash, bank, mobile wallet, credit and savings account CRUD
- Live account balances derived from transactions
- Account-to-account transfers with source and destination
- Monthly budget CRUD and category spending progress
- Automatic SQLite schema migration from Phase 2
- Monthly income, expense and savings reports
- Weekly bar chart and expense category breakdown
- PDF, Excel and CSV report export/share
- Weekly, monthly and yearly recurring transactions
- Due-soon reminders and automatic posting of due recurring records
- Reusable Quick Templates for income, expense and transfer entry
- One-tap template form fill with editable amount, account and date
- Dedicated searchable Templates screen with expense, income and transfer tabs
- Create, edit and delete templates independently from transaction entry
- Templates may store a zero amount for variable-value transactions
- Latest-created transactions are always shown first
- Transaction lists and dashboard totals refresh immediately after add/edit/delete
- Posting a due recurring item keeps its rule and advances its next due date;
  weekly, monthly and yearly updates are committed atomically to prevent duplicates
- Template Management is available from Settings
- Protected full data reset with language preference preserved
- Receipt photo attachment from camera or gallery
- Optional current GPS coordinates or manually entered location
- Full-screen amount calculator with quick-value keys and arithmetic
- Calculator entry for every money amount field, including templates,
  accounts, budgets and recurring transactions
- Tap-to-open receipt images with full-screen pan and zoom
- App-wide Myanmar/English text switching, including Settings and forms
- Working notification permission toggle with OS-state verification, recurring
  reminder rescheduling, per-reminder error isolation and clear permission
  feedback without incorrectly rolling the Settings switch back
- Bottom navigation opens recurring management directly. Scheduled income and
  expenses are separated from receivable/payable debts; debt due dates are
  optional, while scheduled rules retain their cadence and advance automatically
- Adding from the receivable/payable tabs automatically assigns income/expense;
  the unnecessary transaction-type selector is shown only for scheduled rules
- Recurring schedules support weekly, monthly, yearly and a custom number of
  days; custom schedules advance the next date by the chosen interval
- Dark mode uses high-contrast light text, dark cards and adaptive secondary
  text/surfaces throughout transaction, recurring, report and Settings screens
- Google Drive app-private cloud sync, manual sync/restore, daily automatic
  backup and five-version retention; plus secure startup PIN lock, salted PIN
  hashing in encrypted storage, biometric unlock, lifecycle auto-lock,
  failed-attempt throttling, background privacy cover and security preferences,
  live in-page language and appearance setting updates without reopening Settings,
  app-wide currency and date-format preferences, scheduled recurring reminders,
  periodic background recurring/backup maintenance, working report header share,
  and complete in-app help and privacy information pages,
  dark mode, currency, date format, notifications and management shortcuts
- CSV/XLSX import with automatic/manual column mapping, preview, account
  selection and duplicate detection
- PDF/Excel/CSV export plus verified ZIP backup/restore including receipt images
- Custom income and expense category management with colors, icons, search,
  editing, deletion, ordering and per-category totals; includes 96 categorized
  icon choices for daily life, transport, home, finance, health, education,
  entertainment and business
- Month-based transaction timeline UI with search, filters, monthly summary,
  day groups, category colors/icons and receipt access
- Monthly, quarterly, six-month and yearly report periods with summary cards,
  comparison bars, expense donut chart, insights and PDF/Excel export
- Detailed recurring and reminder dashboard with receivable/payable filters,
  monthly totals, next-due summary, category icons, account labels, due-state
  alerts, cycle progress, enable controls and one-tap posting of due entries
- Detailed account management dashboard with net balance, assets/liabilities,
  hidden-balance mode, transfer and adjustment actions, account-number masking,
  custom colors/icons, credit limits and savings-goal progress
- First-run guided onboarding with a clean transaction database, mandatory
  first-account setup, backup restore entry point and a three-step quick guide;
  transaction entry redirects to Account Management when no account exists
- Automatic SQLite schema migration to Phase 4

## Run

1. Install a current stable Flutter release (3.29 or newer recommended).
2. In this folder, run `flutter create --platforms=android,ios .` once to
   generate the standard platform runner files.
3. Run `flutter pub get`.
4. Run `flutter run` for an attached Android device.
5. Run `flutter build apk --release` to create a release APK.

Device biometric authentication still needs its production platform
integration.

## Google Drive cloud setup

Cloud backup uses the signed-in user's hidden Google Drive `appDataFolder`.
Before a release build, enable Google Drive API in Google Cloud, configure the
OAuth consent screen, and add an Android OAuth client whose package name and
SHA-1 match the release application. The app requests only `drive.appdata` and
email scopes; it cannot read or modify the user's normal Drive documents.

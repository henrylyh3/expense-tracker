// Public deployment configuration. Invitation credentials only go in URL fragments.
const guestWebUrl = String.fromEnvironment(
  'GUEST_WEB_URL',
  defaultValue: 'https://expense-tracker-guest.pages.dev/',
);

/// Configuration for the AG-UI backend the transport talks to.
library;

/// Path of the Pawtfolio A2UI route on the backend.
///
/// The trailing slash is load-bearing: without it the backend issues a 307
/// redirect that breaks the browser's CORS preflight on web. Must match the
/// backend mount prefix (`/pawtfolio`).
const String kA2uiEndpointPath = 'pawtfolio/';

/// Base URL of the AG-UI backend.
///
/// Defaults to the deployed Railway backend so a plain `flutter build apk`
/// (or web build) targets production. Override at build time with
/// `--dart-define=AG_UI_BASE_URL=...` — e.g. `http://localhost:8002` for a
/// local backend, or the host-forwarded port when running Flutter web in a
/// dev container.
const String kA2uiBaseUrl = String.fromEnvironment(
  'AG_UI_BASE_URL',
  defaultValue: 'https://pawtfolio-production.up.railway.app',
);

/// URL of the pet's photo, served by the backend (`/static/pet.jpg`) — loaded
/// over HTTP, not bundled into the app.
const String kPetImageUrl = '$kA2uiBaseUrl/static/pet.jpg';

/// URL of the pet identity token (name/species/breed) — owned by the backend,
/// not hardcoded in the app.
const String kPetInfoUrl = '$kA2uiBaseUrl/pet';

export function extractShareToken(pathname) {
  const match = String(pathname).match(/^\/trip\/([^/]+)\/?$/u);
  if (!match) return null;
  try {
    const token = decodeURIComponent(match[1]).trim();
    return token || null;
  } catch {
    return null;
  }
}

export function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

export function normalizePublicTrip(payload) {
  if (!payload || typeof payload !== 'object' || !Array.isArray(payload.days)) {
    throw new Error('Invalid shared trip response.');
  }
  return {
    title: typeof payload.title === 'string' && payload.title.trim()
      ? payload.title.trim()
      : 'Shared Vietnam itinerary',
    allowCopy: payload.allow_copy === true,
    expiresAt: typeof payload.expires_at === 'string' ? payload.expires_at : '',
    days: payload.days.map((day, index) => ({
      day: Number.isFinite(Number(day?.day)) ? Number(day.day) : index + 1,
      date: typeof day?.date === 'string' ? day.date : '',
      places: Array.isArray(day?.places)
        ? day.places.map((place) => ({
            name: typeof place?.name === 'string' ? place.name : 'Scheduled stop',
            slot: typeof place?.slot === 'string' ? place.slot : '',
            startTime: typeof place?.start_time === 'string' ? place.start_time : '',
            endTime: typeof place?.end_time === 'string' ? place.end_time : '',
            latitude: finiteNumber(place?.latitude),
            longitude: finiteNumber(place?.longitude),
            imageUrl: representativeImage(place),
          }))
        : [],
    })),
  };
}

function finiteNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function representativeImage(place) {
  const gallery = Array.isArray(place?.gallery) ? place.gallery : [];
  const cover = gallery.find((item) => item?.type === 'cover' && item?.url);
  const candidate = cover?.url || gallery.find((item) => item?.url)?.url || place?.cover_image;
  return typeof candidate === 'string' && /^https:\/\//u.test(candidate) ? candidate : null;
}

async function start() {
  const root = document.querySelector('#app');
  const token = extractShareToken(window.location.pathname);
  const baseUrl = window.TRIP_SHARE_CONFIG?.functionBaseUrl?.replace(/\/+$/u, '');
  if (!root || !token || !baseUrl) {
    renderUnavailable(root, 'This share link is not configured correctly.');
    return;
  }

  try {
    const response = await fetch(`${baseUrl}/public/${encodeURIComponent(token)}`, {
      headers: { Accept: 'application/json' },
      cache: 'no-store',
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(body.error || 'Shared trip is unavailable.');
    renderTrip(root, normalizePublicTrip(body), token);
  } catch (error) {
    renderUnavailable(root, error instanceof Error ? error.message : 'Shared trip is unavailable.');
  }
}

function renderTrip(root, trip, token) {
  root.replaceChildren();
  const header = element('header', 'hero');
  header.append(
    element('span', 'eyebrow', 'HELLOVIETNAM · SHARED TRIP'),
    element('h1', '', trip.title),
    element(
      'p',
      'subtitle',
      `${trip.days.length} day itinerary${trip.expiresAt ? ` · Available until ${formatDate(trip.expiresAt)}` : ''}`,
    ),
  );

  const actions = element('div', 'actions');
  const openButton = element('a', 'primary-button', trip.allowCopy ? 'Open app & copy trip' : 'Open in HelloVietnam');
  openButton.href = `com.hellovietnam.app://shared-trip?token=${encodeURIComponent(token)}`;
  const copyButton = element('button', 'secondary-button', 'Copy link');
  copyButton.type = 'button';
  copyButton.addEventListener('click', async () => {
    await navigator.clipboard.writeText(window.location.href);
    copyButton.textContent = 'Copied';
    window.setTimeout(() => { copyButton.textContent = 'Copy link'; }, 1500);
  });
  actions.append(openButton, copyButton);
  header.append(actions);
  root.append(header);

  const dayList = element('main', 'days');
  for (const day of trip.days) {
    const details = element('details', 'day-card');
    if (day.day === 1) details.open = true;
    const summary = element('summary', 'day-summary');
    summary.append(
      element('strong', '', `Day ${day.day}`),
      element('span', '', day.date || `${day.places.length} stops`),
    );
    details.append(summary);
    const places = element('div', 'places');
    for (const place of day.places) places.append(placeCard(place));
    if (day.places.length === 0) places.append(element('p', 'empty', 'No scheduled stops.'));
    details.append(places);
    dayList.append(details);
  }
  root.append(dayList, element('footer', '', 'Plan your own journey with HelloVietnam.'));
}

function placeCard(place) {
  const card = element('article', 'place-card');
  if (place.imageUrl) {
    const image = document.createElement('img');
    image.src = place.imageUrl;
    image.alt = '';
    image.loading = 'lazy';
    card.append(image);
  }
  const content = element('div', 'place-content');
  content.append(
    element('h2', '', place.name),
    element('p', '', timeLabel(place)),
  );
  if (place.latitude != null && place.longitude != null) {
    const map = element('a', 'map-link', 'View map');
    map.href = `https://www.openstreetmap.org/?mlat=${place.latitude}&mlon=${place.longitude}#map=16/${place.latitude}/${place.longitude}`;
    map.target = '_blank';
    map.rel = 'noopener noreferrer';
    content.append(map);
  }
  card.append(content);
  return card;
}

function timeLabel(place) {
  if (place.startTime && place.endTime) return `${place.startTime} – ${place.endTime}`;
  return place.slot || 'Flexible time';
}

function renderUnavailable(root, message) {
  if (!root) return;
  root.replaceChildren();
  const card = element('main', 'unavailable');
  card.append(
    element('div', 'unavailable-icon', '↗'),
    element('h1', '', 'This itinerary is unavailable'),
    element('p', '', message),
    element('p', 'hint', 'The owner may have revoked the link or it may have expired.'),
  );
  root.append(card);
}

function element(tag, className = '', text = '') {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text) node.textContent = text;
  return node;
}

function formatDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString();
}

if (typeof document !== 'undefined') start();

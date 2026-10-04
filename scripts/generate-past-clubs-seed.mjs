#!/usr/bin/env node
/**
 * Generate a sanitized, deterministic past-clubs seed migration from the
 * official master list CSV.
 *
 * Usage:
 *   node scripts/generate-past-clubs-seed.mjs
 *   node scripts/generate-past-clubs-seed.mjs --additional-only
 *
 * Requires:
 *   local-input/JFSS_Official_Clubs_Masterlist_2025-2026.csv
 *
 * Never commit the raw CSV. local-input/ is gitignored.
 */

import { createHash, createHmac } from "node:crypto";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");
const CSV_PATH = join(
  ROOT,
  "local-input",
  "JFSS_Official_Clubs_Masterlist_2025-2026.csv",
);
const OUT_PATH = join(
  ROOT,
  "supabase",
  "migrations",
  "20260725070000_seed_past_clubs.sql",
);

const SCHOOL_YEAR = "2026-2027";
const NAMESPACE = "jfss-past-clubs-2025-2026-v1";

const NAME_FIXES = new Map([
  ["Ceative Writing Club", "Creative Writing Club"],
  ["John Fraser's Law CLub", "John Fraser's Law Club"],
  ["Fraser chefs", "Fraser Chefs"],
  ["Fraser ESports", "Fraser Esports"],
  [
    "John Fraser Secondary School's Badminton Club",
    "Badminton Club",
  ],
  ["Fraser Threads", "JFSS Threads"],
]);

const EXPECTED_NAMED_ROWS = 84;
const EXPECTED_CANONICAL_CLUBS = 83;

const ADDITIONAL_CANONICAL = new Set([
  "Badminton Club",
  "Computer Science Club",
  "Fraser Dance Crew",
  "FraserHacks",
  "JFAS - John Fraser Advocacy Society",
  "JFSS Physics Club",
  "JFSS Pre-Vet Club",
  "Positive Space",
  "Project Link",
]);

const FACE_NAMES = new Set([
  "F.A.C.E. (Fraser Ambassadors of Community Engagement)",
  "Fraser Aces",
]);

function slugify(name) {
  return String(name ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function uuidFromKey(key) {
  const digest = createHmac("sha256", NAMESPACE).update(key).digest();
  const bytes = Buffer.from(digest.subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function sqlString(value) {
  if (value == null || value === "") return "null";
  return `'${String(value).replace(/'/g, "''")}'`;
}

function sqlTextArray(values) {
  if (!values?.length) return "'{}'::text[]";
  return `array[${values.map((v) => sqlString(v)).join(", ")}]::text[]`;
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    const next = text[i + 1];

    if (inQuotes) {
      if (ch === '"' && next === '"') {
        field += '"';
        i += 1;
      } else if (ch === '"') {
        inQuotes = false;
      } else {
        field += ch;
      }
      continue;
    }

    if (ch === '"') {
      inQuotes = true;
    } else if (ch === ",") {
      row.push(field);
      field = "";
    } else if (ch === "\n" || (ch === "\r" && next === "\n")) {
      row.push(field);
      field = "";
      if (row.some((cell) => String(cell).trim() !== "")) {
        rows.push(row);
      }
      row = [];
      if (ch === "\r") i += 1;
    } else if (ch !== "\r") {
      field += ch;
    }
  }

  if (field.length || row.length) {
    row.push(field);
    if (row.some((cell) => String(cell).trim() !== "")) {
      rows.push(row);
    }
  }

  return rows;
}

function normalizeHeader(h) {
  return String(h ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "");
}

function pick(row, keys) {
  for (const key of keys) {
    if (row[key] != null && String(row[key]).trim() !== "") {
      return String(row[key]).trim();
    }
  }
  return null;
}

function isPdsbStudentEmail(email) {
  if (!email) return true;
  const e = email.trim().toLowerCase();
  if (!e.includes("@")) return true;
  // Student-style numeric local parts are personal.
  if (/^\d+@pdsb\.net$/.test(e)) return true;
  return false;
}

function looksLikePersonalInstagram(handle, clubName) {
  if (!handle) return true;
  const h = handle.replace(/^@/, "").toLowerCase();
  if (!h) return true;
  // Ambiguous personal-looking handles without club keywords.
  const clubTokens = String(clubName || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 2 && !["club", "the", "and", "of"].includes(t));
  if (clubTokens.some((t) => h.includes(t))) return false;
  if (h.includes("jfss") || h.includes("fraser") || h.includes("club")) {
    return false;
  }
  return true;
}

function clubTokens(clubName) {
  return String(clubName || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .split(/\s+/)
    .filter(
      (token) =>
        token.length > 2 &&
        !["club", "the", "and", "for", "john", "activity"].includes(token),
    );
}

function safeClubEmail(raw, clubName) {
  if (!raw) return null;
  const text = raw.trim();
  const candidates = [];
  const pattern =
    /(?:^|[\s,;])((?:club|official)\s+)?email\s*:\s*([a-z0-9._%+-]+@[a-z0-9.-]+\.(?:com|org|ca|net))\b/gi;
  let match;

  while ((match = pattern.exec(text)) !== null) {
    const context = text
      .slice(Math.max(0, match.index - 24), match.index + match[0].length)
      .toLowerCase();
    if (
      context.includes("leader email") ||
      context.includes("student email") ||
      context.includes("president email") ||
      context.includes("supervisor email")
    ) {
      continue;
    }

    const email = match[2].toLowerCase();
    if (
      !/^[a-z0-9._%+-]+@[a-z0-9.-]+\.(?:com|org|ca|net)$/.test(email)
    ) {
      continue;
    }
    if (isPdsbStudentEmail(email) || email.endsWith("@pdsb.net")) continue;

    const local = email.split("@")[0];
    const explicitlyClub = Boolean(match[1]);
    const looksOperated =
      explicitlyClub ||
      local.includes("jfss") ||
      local.includes("fraser") ||
      local.includes("club") ||
      clubTokens(clubName).some((token) => local.includes(token));

    if (looksOperated) candidates.push(email);
  }

  return [...new Set(candidates)].length === 1 ? candidates[0] : null;
}

function safeInstagram(raw, clubName) {
  if (!raw) return null;
  const match = raw.match(
    /(?:^|[\s,;])(?:(?:club|official)\s+)?instagram(?:\s+handle)?\s*:\s*@?([a-z0-9_.]+)/i,
  );
  if (!match) return null;
  const handle = match[1];
  if (looksLikePersonalInstagram(handle, clubName)) return null;
  return handle;
}

function ensureDescription(text, clubName) {
  const trimmed = (text || "").trim();
  if (trimmed.length >= 10) return trimmed.slice(0, 10000);
  return `Historical record for ${clubName} from the Past Clubs master list.`;
}

if (!existsSync(CSV_PATH)) {
  console.error(
    [
      "STOP: Master-list CSV not found.",
      `Expected: ${CSV_PATH}`,
      "Place JFSS_Official_Clubs_Masterlist_2025-2026.csv in local-input/",
      "Do not invent club records. Seed migration was not written.",
    ].join("\n"),
  );
  process.exit(1);
}

const raw = readFileSync(CSV_PATH, "utf8");
const matrix = parseCsv(raw);
if (matrix.length < 2) {
  console.error("STOP: CSV has no data rows.");
  process.exit(1);
}

const headerIndex = matrix.findIndex((row) =>
  row.some((cell) => normalizeHeader(cell) === "club_name"),
);
if (headerIndex < 0) {
  console.error("STOP: Could not find the CLUB NAME header row.");
  process.exit(1);
}

const headers = matrix[headerIndex].map(normalizeHeader);
const dataRows = matrix.slice(headerIndex + 1).map((cells) => {
  const obj = {};
  headers.forEach((h, i) => {
    obj[h] = cells[i] ?? "";
  });
  return obj;
});

const nameKeys = [
  "club_name",
  "name",
  "official_club_name",
  "club",
  "clubs",
];
const descKeys = [
  "description",
  "club_description",
  "about",
  "purpose",
];
const scheduleKeys = [
  "meeting_schedule",
  "schedule",
  "meeting_times",
  "when",
];
const locationKeys = [
  "meeting_location",
  "location",
  "where",
  "room",
];
const emailKeys = [
  "club_email",
  "email",
  "contact_email",
  "public_email",
  "contact_information",
];
const igKeys = [
  "instagram",
  "instagram_handle",
  "ig",
  "club_instagram",
  "contact_information",
];

const named = [];
for (const row of dataRows) {
  const sourceName = pick(row, nameKeys);
  if (!sourceName) continue;
  named.push({
    sourceName,
    description: pick(row, descKeys),
    schedule: pick(row, scheduleKeys),
    location: pick(row, locationKeys),
    email: pick(row, emailKeys),
    instagram: pick(row, igKeys),
  });
}

if (named.length !== EXPECTED_NAMED_ROWS) {
  console.error(
    `STOP: Expected ${EXPECTED_NAMED_ROWS} named club records, parsed ${named.length}. Seed aborted.`,
  );
  process.exit(1);
}

const normalizations = [];
const faceRows = [];
const otherRows = [];

for (const row of named) {
  let canonical = row.sourceName;
  if (NAME_FIXES.has(row.sourceName)) {
    canonical = NAME_FIXES.get(row.sourceName);
    normalizations.push(`${row.sourceName} → ${canonical}`);
  }

  if (FACE_NAMES.has(row.sourceName) || FACE_NAMES.has(canonical)) {
    faceRows.push({ ...row, canonicalHint: canonical });
  } else {
    otherRows.push({ ...row, canonical });
  }
}

if (faceRows.length !== 2) {
  console.error(
    `STOP: Expected exactly 2 F.A.C.E./Fraser Aces rows to merge, found ${faceRows.length}.`,
  );
  process.exit(1);
}

const facePreferred =
  faceRows.find((r) =>
    r.sourceName.startsWith("F.A.C.E."),
  ) || faceRows[0];
const faceOther = faceRows.find((r) => r !== facePreferred);

const merged = {
  canonical: "Fraser Aces (F.A.C.E.)",
  sourceNames: [...new Set(faceRows.map((r) => r.sourceName))],
  aliases: [
    "Fraser Aces",
    "F.A.C.E. (Fraser Ambassadors of Community Engagement)",
    "F.A.C.E.",
  ],
  description: ensureDescription(
    facePreferred.description || faceOther?.description,
    "Fraser Aces (F.A.C.E.)",
  ),
  schedule: facePreferred.schedule || faceOther?.schedule || null,
  location: facePreferred.location || faceOther?.location || null,
  email:
    safeClubEmail(facePreferred.email, "Fraser Aces") ||
    safeClubEmail(faceOther?.email, "Fraser Aces") ||
    null,
  instagram:
    safeInstagram(facePreferred.instagram, "Fraser Aces") ||
    safeInstagram(faceOther?.instagram, "Fraser Aces") ||
    null,
};

normalizations.push(
  `MERGE ${faceRows.map((r) => r.sourceName).join(" + ")} → ${merged.canonical}`,
);

const clubs = [
  merged,
  ...otherRows.map((row) => ({
    canonical: row.canonical,
    sourceNames: [row.sourceName],
    aliases:
      row.sourceName !== row.canonical ? [row.sourceName] : [],
    description: ensureDescription(row.description, row.canonical),
    schedule: row.schedule,
    location: row.location,
    email: safeClubEmail(row.email, row.canonical),
    instagram: safeInstagram(row.instagram, row.canonical),
  })),
];

if (clubs.length !== EXPECTED_CANONICAL_CLUBS) {
  console.error(
    `STOP: Expected ${EXPECTED_CANONICAL_CLUBS} canonical clubs after merge, got ${clubs.length}.`,
  );
  process.exit(1);
}

// Robotics Club and The Robotics Club must remain separate.
const robotics = clubs.filter((c) =>
  ["Robotics Club", "The Robotics Club"].includes(c.canonical),
);
if (robotics.length !== 2) {
  console.warn(
    `WARN: Expected both 'Robotics Club' and 'The Robotics Club'. Found: ${robotics
      .map((c) => c.canonical)
      .join(", ") || "(none)"}`,
  );
}

const slugCounts = new Map();
for (const club of clubs) {
  let slug = slugify(club.canonical);
  if (!slug) {
    console.error(`STOP: Could not slugify ${club.canonical}`);
    process.exit(1);
  }
  const count = slugCounts.get(slug) || 0;
  if (count > 0) {
    slug = `${slug}-${count + 1}`;
    normalizations.push(`Slug collision avoided for ${club.canonical} → ${slug}`);
  }
  slugCounts.set(slugify(club.canonical), count + 1);
  club.slug = slug;
  club.id = uuidFromKey(`club:${club.canonical.toLowerCase()}`);
}

const additionalOnly = process.argv.includes("--additional-only");
const additionalOutPath = join(
  ROOT,
  "supabase",
  "migrations",
  "20260903183000_seed_additional_past_clubs.sql",
);

let clubsToWrite = clubs;
let expectedResolved = EXPECTED_CANONICAL_CLUBS;
let outPath = OUT_PATH;
let sourceNote = `Source rows: ${EXPECTED_NAMED_ROWS} → canonical clubs: ${EXPECTED_CANONICAL_CLUBS}`;

if (additionalOnly) {
  clubsToWrite = clubs.filter((c) => ADDITIONAL_CANONICAL.has(c.canonical));
  if (clubsToWrite.length !== ADDITIONAL_CANONICAL.size) {
    const found = clubsToWrite.map((c) => c.canonical).join(", ");
    console.error(
      `STOP: Expected ${ADDITIONAL_CANONICAL.size} additional clubs, got ${clubsToWrite.length}: ${found || "(none)"}`,
    );
    process.exit(1);
  }
  expectedResolved = ADDITIONAL_CANONICAL.size;
  outPath = additionalOutPath;
  sourceNote = `Additional past clubs from 2025-2026 reapplication form (${expectedResolved} clubs)`;
}

const lines = [];
lines.push("-- =========================================================");
lines.push("-- Sanitized Past Clubs seed (generated; do not hand-edit)");
lines.push(`-- ${sourceNote}`);
lines.push(`-- School year: ${SCHOOL_YEAR}`);
lines.push(`-- Generated: ${new Date().toISOString()}`);
lines.push("-- =========================================================");
lines.push("");
lines.push("-- Normalizations applied:");
for (const note of normalizations) {
  lines.push(`-- - ${note.replace(/\n/g, " ")}`);
}
lines.push("");
lines.push("do $$");
lines.push("declare");
lines.push("  v_year text := public.get_current_club_school_year();");
lines.push("begin");
lines.push("  if v_year is distinct from '2026-2027' then");
lines.push(
  "    raise notice 'Seeding annual rows for setting year % (expected 2026-2027)', v_year;",
);
lines.push("  end if;");
lines.push("end $$;");
lines.push("");

for (const club of clubsToWrite) {
  lines.push(`-- ${club.canonical}`);
  lines.push("do $club_seed$");
  lines.push("declare");
  lines.push("  v_club_id uuid;");
  lines.push("  v_is_imported_seed boolean;");
  lines.push("begin");
  lines.push("  select id, is_imported_seed");
  lines.push("  into v_club_id, v_is_imported_seed");
  lines.push("  from public.clubs");
  lines.push("  where");
  lines.push(`    id = ${sqlString(club.id)}`);
  lines.push(`    or lower(name) = lower(${sqlString(club.canonical)})`);
  lines.push(`    or slug = ${sqlString(club.slug)}`);
  lines.push(
    `  order by (id = ${sqlString(club.id)}) desc, is_imported_seed desc`,
  );
  lines.push("  limit 1;");
  lines.push("");
  lines.push("  if v_club_id is null then");
  lines.push("    insert into public.clubs (");
  lines.push(
    "      id, name, slug, short_description, description, contact_email,",
  );
  lines.push(
    "      instagram_handle, meeting_location, meeting_schedule, status,",
  );
  lines.push(
    "      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names",
  );
  lines.push("    )");
  lines.push("    values (");
  lines.push(`      ${sqlString(club.id)},`);
  lines.push(`      ${sqlString(club.canonical)},`);
  lines.push(`      ${sqlString(club.slug)},`);
  lines.push(`      ${sqlString((club.description || "").slice(0, 220))},`);
  lines.push(`      ${sqlString(club.description)},`);
  lines.push(`      ${sqlString(club.email)},`);
  lines.push(`      ${sqlString(club.instagram)},`);
  lines.push(`      ${sqlString(club.location)},`);
  lines.push(`      ${sqlString(club.schedule)},`);
  lines.push("      'APPROVED',");
  lines.push("      null,");
  lines.push("      'Past Clubs',");
  lines.push("      true,");
  lines.push("      true,");
  lines.push(`      ${sqlTextArray(club.sourceNames)}`);
  lines.push("    )");
  lines.push("    returning id into v_club_id;");
  lines.push("  elsif v_is_imported_seed then");
  lines.push("    update public.clubs");
  lines.push("    set");
  lines.push(`      name = ${sqlString(club.canonical)},`);
  lines.push(`      slug = ${sqlString(club.slug)},`);
  lines.push(
    `      short_description = ${sqlString((club.description || "").slice(0, 220))},`,
  );
  lines.push(`      description = ${sqlString(club.description)},`);
  lines.push(`      contact_email = ${sqlString(club.email)},`);
  lines.push(`      instagram_handle = ${sqlString(club.instagram)},`);
  lines.push(`      meeting_location = ${sqlString(club.location)},`);
  lines.push(`      meeting_schedule = ${sqlString(club.schedule)},`);
  lines.push("      source_label = 'Past Clubs',");
  lines.push("      eligible_for_reapplication = true,");
  lines.push(`      source_names = ${sqlTextArray(club.sourceNames)}`);
  lines.push("    where id = v_club_id;");
  lines.push("  else");
  lines.push(
    "    -- Preserve manually managed profile data; only mark it eligible.",
  );
  lines.push("    update public.clubs");
  lines.push("    set eligible_for_reapplication = true");
  lines.push("    where id = v_club_id;");
  lines.push("  end if;");
  lines.push("");
  lines.push(
    "  insert into public.club_school_years (club_id, school_year, status)",
  );
  lines.push(`  values (v_club_id, ${sqlString(SCHOOL_YEAR)}, 'INACTIVE')`);
  lines.push("  on conflict (club_id, school_year) do nothing;");
  lines.push("");

  for (const alias of club.aliases) {
    lines.push("  insert into public.club_aliases (club_id, alias)");
    lines.push(`  values (v_club_id, ${sqlString(alias)})`);
    lines.push("  on conflict do nothing;");
    lines.push("");
  }
  lines.push("end");
  lines.push("$club_seed$;");
  lines.push("");
}

lines.push("do $$");
lines.push("declare");
lines.push("  v_resolved_count integer;");
lines.push("begin");
lines.push("  with expected(name, slug) as (");
lines.push("    values");
clubsToWrite.forEach((club, index) => {
  const suffix = index === clubsToWrite.length - 1 ? "" : ",";
  lines.push(
    `      (${sqlString(club.canonical)}, ${sqlString(club.slug)})${suffix}`,
  );
});
lines.push("  ), resolved as (");
lines.push("    select distinct c.id");
lines.push("    from expected e");
lines.push("    join public.clubs c");
lines.push("      on lower(c.name) = lower(e.name) or c.slug = e.slug");
lines.push("    join public.club_school_years csy");
lines.push("      on csy.club_id = c.id");
lines.push(`     and csy.school_year = ${sqlString(SCHOOL_YEAR)}`);
lines.push("    where c.eligible_for_reapplication = true");
lines.push("  )");
lines.push("  select count(*) into v_resolved_count from resolved;");
lines.push(`  if v_resolved_count < ${expectedResolved} then`);
lines.push(
  `    raise exception 'Past clubs seed incomplete: expected ${expectedResolved} resolved canonical clubs, found %', v_resolved_count;`,
);
lines.push("  end if;");
lines.push("end $$;");
lines.push("");

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, lines.join("\n"), "utf8");

console.log("Sanitized seed migration written:");
console.log(`  ${outPath}`);
console.log(`Parsed named rows: ${named.length}`);
console.log(`Canonical clubs: ${clubs.length}`);
if (additionalOnly) {
  console.log(`Additional clubs written: ${clubsToWrite.length}`);
}
console.log("Normalizations:");
for (const note of normalizations) {
  console.log(`  - ${note}`);
}
console.log(
  `Checksum: ${createHash("sha256").update(lines.join("\n")).digest("hex").slice(0, 16)}`,
);

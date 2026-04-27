#!/usr/bin/env node
"use strict";

const crypto = require("node:crypto");
const http = require("node:http");
const zlib = require("node:zlib");

const RECENT = [
  {
    id: 301,
    date: "2026-04-26",
    time: "18:11:03",
    timestamp: "2026-04-26T18:11:03Z",
    source: { id: "porch", type: "rtsp", displayName: "Porch Mic" },
    beginTime: "2026-04-26T18:10:58Z",
    endTime: "2026-04-26T18:11:08Z",
    scientificName: "Turdus migratorius",
    commonName: "American Robin",
    speciesCode: "amerob",
    confidence: 0.94,
    verified: "unverified",
    locked: false,
    isNewSpecies: false,
    timeOfDay: "Golden hour",
  },
  {
    id: 302,
    date: "2026-04-26",
    time: "17:56:12",
    timestamp: "2026-04-26T17:56:12Z",
    source: { id: "garden", type: "rtsp", displayName: "Garden Mic" },
    beginTime: "2026-04-26T17:56:07Z",
    endTime: "2026-04-26T17:56:17Z",
    scientificName: "Cardinalis cardinalis",
    commonName: "Northern Cardinal",
    speciesCode: "norcar",
    confidence: 0.89,
    verified: "unverified",
    locked: false,
    isNewSpecies: false,
    timeOfDay: "Afternoon",
  },
  {
    id: 303,
    date: "2026-04-26",
    time: "17:27:00",
    timestamp: "2026-04-26T17:27:00Z",
    source: { id: "oak", type: "rtsp", displayName: "Oak Canopy" },
    beginTime: "2026-04-26T17:26:55Z",
    endTime: "2026-04-26T17:27:05Z",
    scientificName: "Cyanocitta cristata",
    commonName: "Blue Jay",
    speciesCode: "blujay",
    confidence: 0.86,
    verified: "unverified",
    locked: false,
    isNewSpecies: true,
    timeOfDay: "Afternoon",
  },
];

const DAILY = [
  {
    scientific_name: "Turdus migratorius",
    common_name: "American Robin",
    species_code: "amerob",
    count: 18,
    hourly_counts: [0, 0, 0, 1, 2, 5, 4, 2, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0],
    high_confidence: true,
    first_heard: "03:42:10",
    latest_heard: "18:11:03",
    is_new_species: false,
  },
  {
    scientific_name: "Cyanocitta cristata",
    common_name: "Blue Jay",
    species_code: "blujay",
    count: 11,
    hourly_counts: [0, 0, 0, 0, 1, 1, 3, 2, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0, 0],
    high_confidence: true,
    first_heard: "04:58:41",
    latest_heard: "17:27:00",
    is_new_species: true,
  },
  {
    scientific_name: "Cardinalis cardinalis",
    common_name: "Northern Cardinal",
    species_code: "norcar",
    count: 9,
    hourly_counts: [0, 0, 0, 0, 0, 3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 0],
    high_confidence: true,
    first_heard: "05:08:23",
    latest_heard: "17:56:12",
    is_new_species: false,
  },
  {
    scientific_name: "Poecile atricapillus",
    common_name: "Black-capped Chickadee",
    species_code: "bkcchi",
    count: 5,
    hourly_counts: [0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0],
    high_confidence: false,
    first_heard: "05:39:18",
    latest_heard: "17:02:48",
    is_new_species: false,
  },
];

const SPECIES = [
  {
    commonName: "American Robin",
    scientificName: "Turdus migratorius",
    speciesCode: "amerob",
    rarity: "Common",
    detectionCount: 18,
    latestDetection: "2026-04-26T18:11:03Z",
  },
  {
    commonName: "Blue Jay",
    scientificName: "Cyanocitta cristata",
    speciesCode: "blujay",
    rarity: "Common",
    detectionCount: 11,
    latestDetection: "2026-04-26T17:27:00Z",
  },
  {
    commonName: "Northern Cardinal",
    scientificName: "Cardinalis cardinalis",
    speciesCode: "norcar",
    rarity: "Common",
    detectionCount: 9,
    latestDetection: "2026-04-26T17:56:12Z",
  },
  {
    commonName: "Black-capped Chickadee",
    scientificName: "Poecile atricapillus",
    speciesCode: "bkcchi",
    rarity: "Expected",
    detectionCount: 5,
    latestDetection: "2026-04-26T17:02:48Z",
  },
];

const SPECIES_DETECTIONS = [
  RECENT[0],
  {
    id: 304,
    date: "2026-04-26",
    time: "06:22:10",
    timestamp: "2026-04-26T06:22:10Z",
    source: { id: "porch", type: "rtsp", displayName: "Porch Mic" },
    beginTime: "2026-04-26T06:22:05Z",
    endTime: "2026-04-26T06:22:15Z",
    scientificName: "Turdus migratorius",
    commonName: "American Robin",
    speciesCode: "amerob",
    confidence: 0.91,
    verified: "unverified",
    locked: false,
    isNewSpecies: false,
    timeOfDay: "Dawn",
  },
  {
    id: 305,
    date: "2026-04-26",
    time: "05:12:44",
    timestamp: "2026-04-26T05:12:44Z",
    source: { id: "garden", type: "rtsp", displayName: "Garden Mic" },
    beginTime: "2026-04-26T05:12:39Z",
    endTime: "2026-04-26T05:12:49Z",
    scientificName: "Turdus migratorius",
    commonName: "American Robin",
    speciesCode: "amerob",
    confidence: 0.88,
    verified: "unverified",
    locked: false,
    isNewSpecies: false,
    timeOfDay: "Dawn",
  },
];

const APP_CONFIG = {
  csrfToken: "mock-csrf-token",
  security: {
    enabled: false,
    accessAllowed: true,
    authConfig: { basicEnabled: false, enabledProviders: [] },
    publicAccess: { liveAudio: true },
  },
  version: "mock-station",
  basePath: "/",
};

function sendJson(response, payload) {
  const body = Buffer.from(JSON.stringify(payload));
  response.writeHead(200, {
    "Content-Type": "application/json",
    "Content-Length": body.length,
  });
  response.end(body);
}

function sendPng(response, body) {
  response.writeHead(200, {
    "Content-Type": "image/png",
    "Content-Length": body.length,
  });
  response.end(body);
}

function sendAudio(response) {
  const body = Buffer.from("524946462400000057415645666d74201000000001000100401f0000401f0000010008006461746100000000", "hex");
  response.writeHead(200, {
    "Content-Type": "audio/wav",
    "Content-Length": body.length,
  });
  response.end(body);
}

function sendNotFound(response) {
  response.writeHead(404);
  response.end();
}

function sendStream(request, response) {
  response.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });
  response.write("event: connected\ndata: {}\n\n");

  const interval = setInterval(() => {
    if (response.writableEnded) {
      clearInterval(interval);
      return;
    }
    response.write("event: heartbeat\ndata: {}\n\n");
  }, 5000);

  request.on("close", () => clearInterval(interval));
}

function sendSpeciesDetections(response, searchParams) {
  const species = (searchParams.get("species") || "").toLowerCase();
  const detections = SPECIES_DETECTIONS.filter((item) => {
    return item.commonName.toLowerCase() === species || item.scientificName.toLowerCase() === species || (item.speciesCode || "").toLowerCase() === species;
  });

  sendJson(response, {
    data: detections,
    total: detections.length,
    limit: Number(searchParams.get("numResults") || 20),
    offset: Number(searchParams.get("offset") || 0),
    current_page: 1,
    total_pages: 1,
  });
}

function sendDetection(response, idText) {
  const detectionId = Number(idText);
  if (!Number.isInteger(detectionId)) {
    sendNotFound(response);
    return;
  }

  const detection = [...RECENT, ...SPECIES_DETECTIONS].find((item) => item.id === detectionId);
  if (!detection) {
    sendNotFound(response);
    return;
  }

  sendJson(response, detection);
}

function handleRequest(request, response) {
  const url = new URL(request.url, "http://127.0.0.1");
  const path = url.pathname;

  if (request.method === "POST") {
    if (path === "/api/v2/auth/login") {
      sendJson(response, { success: true, message: "Logged in.", username: "mock", redirectUrl: "/ui/" });
    } else if (path === "/api/v2/auth/logout") {
      sendJson(response, { success: true, message: "Logged out." });
    } else if (path.startsWith("/api/v2/spectrogram/") && path.endsWith("/generate")) {
      sendJson(response, { data: { status: "generated", queuePosition: null, message: null, path: "mock" }, error: "", message: "ok" });
    } else {
      sendNotFound(response);
    }
    return;
  }

  if (request.method !== "GET") {
    sendNotFound(response);
    return;
  }

  if (path === "/api/v2/ping") {
    sendJson(response, { status: "ok" });
  } else if (path === "/api/v2/app/config") {
    sendJson(response, APP_CONFIG);
  } else if (path === "/api/v2/analytics/species/daily") {
    sendJson(response, DAILY.slice(0, Number(url.searchParams.get("limit") || DAILY.length)));
  } else if (path === "/api/v2/detections/recent") {
    sendJson(response, RECENT.slice(0, Number(url.searchParams.get("limit") || RECENT.length)));
  } else if (path === "/api/v2/detections/stream") {
    sendStream(request, response);
  } else if (path === "/api/v2/detections") {
    sendSpeciesDetections(response, url.searchParams);
  } else if (path.startsWith("/api/v2/detections/") && path.endsWith("/time-of-day")) {
    sendJson(response, { timeOfDay: "Golden hour" });
  } else if (path.startsWith("/api/v2/detections/")) {
    sendDetection(response, path.split("/").at(-1));
  } else if (path === "/api/v2/species") {
    sendJson(response, { species: SPECIES });
  } else if (path === "/api/v2/media/species-image") {
    sendPng(response, makeSpeciesPng(url.searchParams.get("name") || "bird"));
  } else if (path === "/api/v2/media/species-image/info") {
    sendJson(response, { authorName: "Mock Station", licenseName: "Test image", sourceProvider: "BirdNET-Go" });
  } else if (path.startsWith("/api/v2/audio/")) {
    sendAudio(response);
  } else if (path.startsWith("/api/v2/spectrogram/") && path.endsWith("/status")) {
    sendJson(response, { data: { status: "exists", queuePosition: null, message: null, path: "mock" }, error: "", message: "ok" });
  } else if (path.startsWith("/api/v2/spectrogram/")) {
    sendPng(response, makeSpectrogramPng());
  } else if (path.startsWith("/api/v2/weather/detection/")) {
    sendJson(response, {
      time_of_day: "Golden hour",
      daily: { date: "2026-04-26", sunrise: "05:58", sunset: "19:44", country: "US", city_name: "Local Station" },
      hourly: { time: "18:00", temperature: 18.2, humidity: 58, wind_speed: 3.2, weather_main: "Clear", weather_desc: "clear sky" },
    });
  } else {
    sendNotFound(response);
  }
}

function makeSpeciesPng(name) {
  const digest = crypto.createHash("sha256").update(name).digest();
  const base = [digest[0], digest[1], digest[2]];
  const accent = [digest[3], digest[4], digest[5]];
  const width = 96;
  const height = 96;
  const rows = [];

  for (let y = 0; y < height; y += 1) {
    rows.push(0);
    for (let x = 0; x < width; x += 1) {
      const dx = x - width / 2;
      const dy = y - height / 2;
      const radius = Math.sqrt(dx * dx + dy * dy);
      const wing = Math.abs(dx * 0.8 + dy * 0.35) < 16 && radius > 13 && radius < 36;
      const body = ((dx + 8) * (dx + 8)) / 410 + ((dy + 2) * (dy + 2)) / 720 < 1;
      const head = ((dx - 18) * (dx - 18)) / 160 + ((dy - 12) * (dy - 12)) / 160 < 1;
      const beak = x > 65 && y > 34 && y < 45 && x - 65 > Math.abs(y - 40);

      let pixel;
      if (beak) {
        pixel = [238, 157, 45];
      } else if (head || body) {
        pixel = accent;
      } else if (wing) {
        pixel = accent.map((channel) => Math.max(0, channel - 35));
      } else {
        const shade = 230 + Math.trunc(((x + y) / (width + height)) * 22);
        pixel = base.map((channel) => Math.trunc(channel * 0.18 + shade * 0.82));
      }

      rows.push(...pixel);
    }
  }

  return makePng(width, height, Buffer.from(rows));
}

function makeSpectrogramPng() {
  const width = 640;
  const height = 240;
  const rows = [];

  for (let y = 0; y < height; y += 1) {
    rows.push(0);
    for (let x = 0; x < width; x += 1) {
      const harmonic = (x * 7 + y * 11) % 61;
      const band = Math.abs(height - y - (52 + (x % 170) * 0.42)) < 10 || Math.abs(height - y - (118 + (x % 130) * 0.25)) < 7;
      const pulse = band && harmonic < 28 ? 60 : 0;
      rows.push(18 + Math.trunc(pulse / 4), 36 + pulse, 46 + Math.trunc(pulse / 2));
    }
  }

  return makePng(width, height, Buffer.from(rows));
}

function makePng(width, height, rows) {
  return Buffer.concat([
    Buffer.from("89504e470d0a1a0a", "hex"),
    makeChunk("IHDR", Buffer.concat([uint32(width), uint32(height), Buffer.from([8, 2, 0, 0, 0])])),
    makeChunk("IDAT", zlib.deflateSync(rows)),
    makeChunk("IEND", Buffer.alloc(0)),
  ]);
}

function makeChunk(kind, data) {
  const kindBuffer = Buffer.from(kind, "ascii");
  return Buffer.concat([uint32(data.length), kindBuffer, data, uint32(crc32(Buffer.concat([kindBuffer, data])))]);
}

function uint32(value) {
  const buffer = Buffer.alloc(4);
  buffer.writeUInt32BE(value >>> 0);
  return buffer;
}

const CRC_TABLE = Array.from({ length: 256 }, (_, index) => {
  let value = index;
  for (let bit = 0; bit < 8; bit += 1) {
    value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  }
  return value >>> 0;
});

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function parseArgs(argv) {
  const args = { host: "127.0.0.1", port: 18081 };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--host" && argv[index + 1]) {
      args.host = argv[index + 1];
      index += 1;
    } else if (value === "--port" && argv[index + 1]) {
      args.port = Number(argv[index + 1]);
      index += 1;
    }
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
const server = http.createServer(handleRequest);

server.listen(args.port, args.host, () => {
  console.log(`Mock BirdNET-Go station listening on http://${args.host}:${args.port}`);
});

process.on("SIGTERM", () => server.close(() => process.exit(0)));
process.on("SIGINT", () => server.close(() => process.exit(0)));
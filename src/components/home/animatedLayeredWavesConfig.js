export const WAVE_ANIM = {
  upperDurationMin: 1.5,
  upperDurationMax: 2.5,
  lowerDurationMin: 1.5,
  lowerDurationMax: 2.5,
  upperYAmp: 34,
  lowerYAmp: 28,
  upperXAmp: 14,
  lowerXAmp: 10,
};

export const HOME_BG = "#213659";
export const HOME_UPPER_FILL = "#3364c8";
export const HOME_LOWER_FILL = "#457fec";

export const HOME_UPPER_BASE = [
  { cmd: "M", x: 0, y: 198, lockX: true },
  { cmd: "L", x: 25, y: 181.2 },
  {
    cmd: "C",
    c1x: 50,
    c1y: 164.3,
    c2x: 100,
    c2y: 130.7,
    x: 150,
    y: 122.3,
  },
  {
    cmd: "C",
    c1x: 200,
    c1y: 114,
    c2x: 250,
    c2y: 131,
    x: 300,
    y: 160.2,
  },
  {
    cmd: "C",
    c1x: 350,
    c1y: 189.3,
    c2x: 400,
    c2y: 230.7,
    x: 450,
    y: 216.5,
  },
  {
    cmd: "C",
    c1x: 500,
    c1y: 202.3,
    c2x: 550,
    c2y: 132.7,
    x: 600,
    y: 135.5,
  },
  {
    cmd: "C",
    c1x: 650,
    c1y: 138.3,
    c2x: 700,
    c2y: 213.7,
    x: 750,
    y: 228.3,
  },
  {
    cmd: "C",
    c1x: 800,
    c1y: 243,
    c2x: 850,
    c2y: 197,
    x: 875,
    y: 174,
  },
  { cmd: "L", x: 900, y: 151, lockX: true },
];

export const HOME_LOWER_BASE = [
  { cmd: "M", x: 0, y: 275, lockX: true },
  { cmd: "L", x: 25, y: 271.3 },
  {
    cmd: "C",
    c1x: 50,
    c1y: 267.7,
    c2x: 100,
    c2y: 260.3,
    x: 150,
    y: 243.2,
  },
  {
    cmd: "C",
    c1x: 200,
    c1y: 226,
    c2x: 250,
    c2y: 199,
    x: 300,
    y: 181,
  },
  {
    cmd: "C",
    c1x: 350,
    c1y: 163,
    c2x: 400,
    c2y: 154,
    x: 450,
    y: 165.5,
  },
  {
    cmd: "C",
    c1x: 500,
    c1y: 177,
    c2x: 550,
    c2y: 209,
    x: 600,
    y: 233,
  },
  {
    cmd: "C",
    c1x: 650,
    c1y: 257,
    c2x: 700,
    c2y: 273,
    x: 750,
    y: 266.7,
  },
  {
    cmd: "C",
    c1x: 800,
    c1y: 260.3,
    c2x: 850,
    c2y: 231.7,
    x: 875,
    y: 217.3,
  },
  { cmd: "L", x: 900, y: 203, lockX: true },
];

export const CLUBS_WAVE_LOCAL = [
  { cmd: "M", x: 0, y: 118, lockX: true },
  { cmd: "L", x: 60, y: 122 },
  {
    cmd: "C",
    c1x: 180,
    c1y: 130,
    c2x: 320,
    c2y: 145,
    x: 460,
    y: 175,
  },
  {
    cmd: "C",
    c1x: 580,
    c1y: 200,
    c2x: 660,
    c2y: 255,
    x: 760,
    y: 262,
  },
  {
    cmd: "C",
    c1x: 820,
    c1y: 266,
    c2x: 860,
    c2y: 240,
    x: 885,
    y: 220,
  },
  { cmd: "L", x: 900, y: 210, lockX: true },
];

export const CLUBS_WAVE_ANIM = {
  durationMin: 1.2,
  durationMax: 2.0,
  yAmp: 16,
  xAmp: 8,
};

export const HOME_WAVE_LAYERS = [
  {
    base: HOME_UPPER_BASE,
    fill: HOME_UPPER_FILL,
    durationMin: WAVE_ANIM.upperDurationMin,
    durationMax: WAVE_ANIM.upperDurationMax,
    yAmp: WAVE_ANIM.upperYAmp,
    xAmp: WAVE_ANIM.upperXAmp,
  },
  {
    base: HOME_LOWER_BASE,
    fill: HOME_LOWER_FILL,
    durationMin: WAVE_ANIM.lowerDurationMin,
    durationMax: WAVE_ANIM.lowerDurationMax,
    yAmp: WAVE_ANIM.lowerYAmp,
    xAmp: WAVE_ANIM.lowerXAmp,
  },
];

export const CLUBS_WAVE_LAYERS = [
  {
    base: CLUBS_WAVE_LOCAL,
    fill: "#3364C8",
    durationMin: CLUBS_WAVE_ANIM.durationMin,
    durationMax: CLUBS_WAVE_ANIM.durationMax,
    yAmp: CLUBS_WAVE_ANIM.yAmp,
    xAmp: CLUBS_WAVE_ANIM.xAmp,
  },
];

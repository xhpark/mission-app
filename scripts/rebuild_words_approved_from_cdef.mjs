import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const COLS = {
  category: 0, // A
  orderNo: 1, // B
  koreanMeaning: 2, // C
  foreignWord: 3, // D
  phoneticText: 4, // E
  hangulPronunciation: 5, // F
  englishMeaning: 6, // G
  wordType: 7, // H
  linkedSentenceIds: 8, // I
  nativeAudioFile: 9, // J
  nativeAudioStatus: 10, // K
  wordId: 11, // L
  note: 12, // M
  sourceFile: 13, // N
};

const KEEP_COLS = [
  COLS.koreanMeaning,
  COLS.foreignWord,
  COLS.phoneticText,
  COLS.hangulPronunciation,
];

function normalize(value) {
  if (value === null || value === undefined) return "";
  return String(value).trim();
}

function hasAnyCdef(row) {
  return KEEP_COLS.some((col) => normalize(row[col]) !== "");
}

function hasCoreWord(row) {
  return normalize(row[COLS.koreanMeaning]) !== "" || normalize(row[COLS.foreignWord]) !== "";
}

function cdefKey(row) {
  return KEEP_COLS.map((col) => normalize(row[col])).join("||");
}

function parseIntSafe(value) {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  const parsed = Number.parseInt(normalize(value), 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function splitSentenceIds(raw) {
  return normalize(raw)
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);
}

function inferCategoryFromRow(row) {
  const category = normalize(row[COLS.category]).toLowerCase();
  if (category === "daily" || category === "mission") return category;

  const linked = normalize(row[COLS.linkedSentenceIds]).toUpperCase();
  if (linked.includes("THS_D")) return "daily";
  if (linked.includes("THS_M")) return "mission";

  const wordId = normalize(row[COLS.wordId]).toUpperCase();
  if (wordId.startsWith("THW_D")) return "daily";
  if (wordId.startsWith("THW_M")) return "mission";

  return "";
}

function makeWordId(category, orderNo) {
  const prefix = category === "mission" ? "THW_M" : "THW_D";
  return `${prefix}${String(orderNo).padStart(3, "0")}`;
}

function chooseLongest(values) {
  let best = "";
  for (const v of values) {
    const cur = normalize(v);
    if (cur.length > best.length) best = cur;
  }
  return best;
}

async function main() {
  const inputPath = process.argv[2] ?? "D:/proj/thai_upload_bundle_final_v2.xlsx";
  const outputPath = process.argv[3] ?? inputPath;
  const sourceFileName = "thai_upload_bundle_final_v2.xlsx";

  const blob = await FileBlob.load(inputPath);
  const workbook = await SpreadsheetFile.importXlsx(blob);
  const sheet = workbook.worksheets.getItem("words_approved");

  const range = sheet.getRange("A1:N400");
  const values = range.values;
  const header = values[0] ?? [];
  const rows = values.slice(1);

  const groups = new Map();
  let sourceRowIndex = 0;

  for (const row of rows) {
    sourceRowIndex += 1;
    if (!hasAnyCdef(row)) continue;
    if (!hasCoreWord(row)) continue;
    const key = cdefKey(row);
    if (!key || key === "||||||") continue;

    if (!groups.has(key)) {
      groups.set(key, {
        primaryCdef: KEEP_COLS.map((col) => row[col]),
        categoryVotes: [],
        orderCandidates: [],
        englishCandidates: [],
        wordTypeCandidates: [],
        sentenceIdSet: new Set(),
        noteCandidates: [],
        seenIndex: sourceRowIndex,
      });
    }

    const g = groups.get(key);
    g.categoryVotes.push(inferCategoryFromRow(row));
    const orderParsed = parseIntSafe(row[COLS.orderNo]);
    if (orderParsed !== null && orderParsed > 0) g.orderCandidates.push(orderParsed);
    const english = normalize(row[COLS.englishMeaning]);
    if (english) g.englishCandidates.push(english);
    const wordType = normalize(row[COLS.wordType]).toLowerCase();
    if (wordType) g.wordTypeCandidates.push(wordType);
    for (const id of splitSentenceIds(row[COLS.linkedSentenceIds])) {
      g.sentenceIdSet.add(id);
    }
    const note = normalize(row[COLS.note]);
    if (note) g.noteCandidates.push(note);
  }

  const records = [];
  for (const [, g] of groups.entries()) {
    const voteMission = g.categoryVotes.filter((v) => v === "mission").length;
    const voteDaily = g.categoryVotes.filter((v) => v === "daily").length;
    const category = voteMission > voteDaily ? "mission" : "daily";

    const englishMeaning = chooseLongest(g.englishCandidates);
    const note = chooseLongest(g.noteCandidates);
    const sentenceIds = Array.from(g.sentenceIdSet.values());
    sentenceIds.sort((a, b) => a.localeCompare(b));

    let wordType = "word";
    if (g.wordTypeCandidates.includes("particle")) wordType = "particle";
    else if (g.wordTypeCandidates.includes("expression")) wordType = "expression";
    else if (g.wordTypeCandidates.includes("word")) wordType = "word";

    const preferredOrder = g.orderCandidates.length > 0 ? Math.min(...g.orderCandidates) : null;

    records.push({
      cdef: g.primaryCdef,
      category,
      preferredOrder,
      englishMeaning,
      wordType,
      linkedSentenceIds: sentenceIds.join(", "),
      note,
      seenIndex: g.seenIndex,
    });
  }

  const byCategory = {
    daily: [],
    mission: [],
  };
  for (const r of records) {
    byCategory[r.category].push(r);
  }

  const sortRecords = (a, b) => {
    const ao = a.preferredOrder ?? Number.MAX_SAFE_INTEGER;
    const bo = b.preferredOrder ?? Number.MAX_SAFE_INTEGER;
    if (ao !== bo) return ao - bo;
    return a.seenIndex - b.seenIndex;
  };

  byCategory.daily.sort(sortRecords);
  byCategory.mission.sort(sortRecords);

  let dailySeq = 1;
  for (const r of byCategory.daily) {
    r.orderNo = dailySeq;
    r.wordId = makeWordId("daily", dailySeq);
    dailySeq += 1;
  }

  let missionSeq = 1;
  for (const r of byCategory.mission) {
    r.orderNo = missionSeq;
    r.wordId = makeWordId("mission", missionSeq);
    missionSeq += 1;
  }

  const finalRows = [...byCategory.daily, ...byCategory.mission].map((r) => {
    const row = Array(14).fill(null);
    row[COLS.category] = r.category;
    row[COLS.orderNo] = r.orderNo;
    row[COLS.koreanMeaning] = r.cdef[0];
    row[COLS.foreignWord] = r.cdef[1];
    row[COLS.phoneticText] = r.cdef[2];
    row[COLS.hangulPronunciation] = r.cdef[3];
    row[COLS.englishMeaning] = r.englishMeaning || null;
    row[COLS.wordType] = r.wordType;
    row[COLS.linkedSentenceIds] = r.linkedSentenceIds || null;
    row[COLS.nativeAudioFile] = `audio/words/${r.wordId}.mp3`;
    row[COLS.nativeAudioStatus] = "pending_generation";
    row[COLS.wordId] = r.wordId;
    row[COLS.note] = r.note || null;
    row[COLS.sourceFile] = sourceFileName;
    return row;
  });

  sheet.getRange("A1:N400").clear({ applyTo: "contents" });
  sheet.getRange("A1:N1").values = [header.slice(0, 14)];
  if (finalRows.length > 0) {
    sheet.getRange(`A2:N${finalRows.length + 1}`).values = finalRows;
  }

  const output = await SpreadsheetFile.exportXlsx(workbook);
  await output.save(outputPath);

  const summary = {
    inputPath,
    outputPath,
    totalOutputRows: finalRows.length,
    dailyRows: byCategory.daily.length,
    missionRows: byCategory.mission.length,
    preservedCdefRows: finalRows.length,
    rules: {
      cdefImmutable: true,
      nonCdefRebuilt: ["A", "B", "G", "H", "I", "J", "K", "L", "M", "N"],
      resequencedOrderPerCategory: true,
    },
  };

  // eslint-disable-next-line no-console
  console.log(JSON.stringify(summary, null, 2));
}

await main();

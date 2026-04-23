import fs from "node:fs/promises";
import path from "node:path";
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

function norm(v) {
  if (v === null || v === undefined) return "";
  return String(v).trim();
}

function nonEmptyCount(row) {
  return row.reduce((acc, v) => (norm(v) ? acc + 1 : acc), 0);
}

function groupKey(row) {
  return [
    norm(row[COLS.koreanMeaning]),
    norm(row[COLS.foreignWord]),
    norm(row[COLS.phoneticText]),
    norm(row[COLS.hangulPronunciation]),
  ].join("||");
}

function inferCategory(record) {
  const current = norm(record[COLS.category]).toLowerCase();
  if (current === "daily" || current === "mission") {
    return current;
  }
  const wordId = norm(record[COLS.wordId]).toUpperCase();
  if (wordId.startsWith("THW_D")) return "daily";
  if (wordId.startsWith("THW_M")) return "mission";
  const linked = norm(record[COLS.linkedSentenceIds]).toUpperCase();
  if (linked.includes("THS_D")) return "daily";
  if (linked.includes("THS_M")) return "mission";
  return "";
}

function parseOrder(v) {
  if (typeof v === "number" && Number.isFinite(v)) return Math.trunc(v);
  const n = Number.parseInt(norm(v), 10);
  return Number.isFinite(n) ? n : null;
}

function makeWordId(category, orderNo) {
  const prefix = category === "mission" ? "THW_M" : "THW_D";
  return `${prefix}${String(orderNo).padStart(3, "0")}`;
}

async function main() {
  const inputPath = "D:/proj/thai_upload_bundle_final_v2.xlsx";
  const outputPath = "D:/proj/thai_upload_bundle_final_v2_words_reorganized.xlsx";

  const blob = await FileBlob.load(inputPath);
  const workbook = await SpreadsheetFile.importXlsx(blob);
  const sheet = workbook.worksheets.getItem("words_approved");

  const range = sheet.getRange("A1:N300");
  const values = range.values;
  const header = values[0];
  const dataRows = values.slice(1);

  const groups = new Map();

  for (const row of dataRows) {
    const key = groupKey(row);
    if (!key || key === "||||||") {
      continue;
    }
    if (!groups.has(key)) {
      groups.set(key, []);
    }
    groups.get(key).push(row);
  }

  const merged = [];
  for (const [, rows] of groups.entries()) {
    rows.sort((a, b) => nonEmptyCount(b) - nonEmptyCount(a));
    const canonical = [...rows[0]];
    for (const r of rows.slice(1)) {
      for (let c = 0; c < 14; c += 1) {
        if (!norm(canonical[c]) && norm(r[c])) {
          canonical[c] = r[c];
        }
      }
    }
    merged.push(canonical);
  }

  // 1) category inference
  for (const r of merged) {
    if (!norm(r[COLS.category])) {
      r[COLS.category] = inferCategory(r);
    }
  }

  // 2) orderNo normalization by category
  const byCategory = {
    daily: [],
    mission: [],
    other: [],
  };
  for (const r of merged) {
    const cat = inferCategory(r);
    if (cat === "daily") byCategory.daily.push(r);
    else if (cat === "mission") byCategory.mission.push(r);
    else byCategory.other.push(r);
  }

  const sortByOrderThenWord = (a, b) => {
    const ao = parseOrder(a[COLS.orderNo]);
    const bo = parseOrder(b[COLS.orderNo]);
    if (ao !== null && bo !== null && ao !== bo) return ao - bo;
    if (ao !== null && bo === null) return -1;
    if (ao === null && bo !== null) return 1;
    return norm(a[COLS.foreignWord]).localeCompare(norm(b[COLS.foreignWord]));
  };

  byCategory.daily.sort(sortByOrderThenWord);
  byCategory.mission.sort(sortByOrderThenWord);
  byCategory.other.sort(sortByOrderThenWord);

  const resequence = (rows, category) => {
    let seq = 1;
    for (const r of rows) {
      const parsed = parseOrder(r[COLS.orderNo]);
      r[COLS.category] = category;
      if (parsed === null || parsed <= 0) {
        r[COLS.orderNo] = seq;
      } else {
        r[COLS.orderNo] = parsed;
        seq = Math.max(seq, parsed);
      }
      seq += 1;
    }
  };

  resequence(byCategory.daily, "daily");
  resequence(byCategory.mission, "mission");

  // 3) derived fields
  const finalize = (rows, category) => {
    for (const r of rows) {
      let orderNo = parseOrder(r[COLS.orderNo]);
      if (orderNo === null || orderNo <= 0) {
        orderNo = 1;
        r[COLS.orderNo] = orderNo;
      }
      if (!norm(r[COLS.wordId])) {
        r[COLS.wordId] = makeWordId(category, orderNo);
      }
      if (!norm(r[COLS.nativeAudioFile])) {
        r[COLS.nativeAudioFile] = `audio/words/${norm(r[COLS.wordId])}.mp3`;
      }
      if (!norm(r[COLS.nativeAudioStatus])) {
        r[COLS.nativeAudioStatus] = "pending_generation";
      }
      if (!norm(r[COLS.wordType])) {
        r[COLS.wordType] = "word";
      }
      if (!norm(r[COLS.sourceFile])) {
        r[COLS.sourceFile] = "thai_upload_bundle_final_v2.xlsx";
      }
    }
  };

  finalize(byCategory.daily, "daily");
  finalize(byCategory.mission, "mission");
  // Drop orphan fragment rows that cannot be mapped to daily/mission.
  const droppedOrphans = byCategory.other.length;
  const cleaned = [...byCategory.daily, ...byCategory.mission];

  // rewrite table area
  sheet.getRange("A1:N300").clear({ applyTo: "contents" });
  sheet.getRange("A1:N1").values = [header];
  if (cleaned.length > 0) {
    const writeRange = sheet.getRange(`A2:N${cleaned.length + 1}`);
    writeRange.values = cleaned.map((r) => r.slice(0, 14));
  }

  const output = await SpreadsheetFile.exportXlsx(workbook);
  await output.save(outputPath);

  const summary = {
    inputPath,
    outputPath,
    beforeDataRows: dataRows.filter((r) => r.some((v) => norm(v))).length,
    afterDataRows: cleaned.length,
    droppedRows: dataRows.filter((r) => r.some((v) => norm(v))).length - cleaned.length,
    droppedOrphans,
    categoryCounts: {
      daily: byCategory.daily.length,
      mission: byCategory.mission.length,
      other: 0,
    },
  };
  await fs.writeFile(
    path.resolve("scripts", "reorganize_words_approved.summary.json"),
    JSON.stringify(summary, null, 2),
    "utf8",
  );
}

await main();

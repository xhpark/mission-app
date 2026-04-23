import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

function norm(v) {
  if (v === null || v === undefined) return "";
  return String(v).trim();
}

async function main() {
  const workbookPath =
    process.argv[2] ??
    "D:/proj/thai_upload_bundle_final_v2.words_approved_rebuilt.xlsx";
  const outputPath =
    process.argv[3] ?? "scripts/words_approved_tts_input.json";

  const blob = await FileBlob.load(workbookPath);
  const workbook = await SpreadsheetFile.importXlsx(blob);
  const sheet = workbook.worksheets.getItem("words_approved");
  const values = sheet.getRange("A1:N400").values;

  const header = values[0] ?? [];
  const rows = values.slice(1);

  const COL = {
    category: 0,
    orderNo: 1,
    koreanMeaning: 2,
    foreignWord: 3,
    phoneticText: 4,
    hangulPronunciation: 5,
    englishMeaning: 6,
    wordType: 7,
    linkedSentenceIds: 8,
    nativeAudioFile: 9,
    nativeAudioStatus: 10,
    wordId: 11,
    note: 12,
    sourceFile: 13,
  };

  const items = [];
  let seq = 0;
  for (const row of rows) {
    const thai = norm(row[COL.foreignWord]);
    const korean = norm(row[COL.koreanMeaning]);
    if (!thai && !korean) {
      continue;
    }
    seq += 1;
    const existingId = norm(row[COL.wordId]);
    const fallbackId = `THW_XLSX_${String(seq).padStart(3, "0")}`;
    items.push({
      rowNo: seq + 1,
      wordId: existingId || fallbackId,
      thaiWord: thai,
      category: norm(row[COL.category]),
      orderNo: norm(row[COL.orderNo]),
      koreanMeaning: korean,
      sourceFile: norm(row[COL.sourceFile]),
    });
  }

  const out = {
    workbookPath,
    sheetName: "words_approved",
    header,
    totalItems: items.length,
    items,
  };
  await fs.writeFile(outputPath, JSON.stringify(out, null, 2), "utf8");
  // eslint-disable-next-line no-console
  console.log(
    JSON.stringify(
      {
        workbookPath,
        outputPath,
        totalItems: items.length,
        uniqueWordIds: new Set(items.map((i) => i.wordId)).size,
        missingThaiWordCount: items.filter((i) => !i.thaiWord).length,
      },
      null,
      2,
    ),
  );
}

await main();

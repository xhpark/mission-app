import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

async function main() {
  const workbookPath =
    process.argv[2] ?? "D:/proj/thai_upload_bundle_final_v2.xlsx";
  const tag = process.argv[3] ?? "default";
  const blob = await FileBlob.load(workbookPath);
  const workbook = await SpreadsheetFile.importXlsx(blob);

  const sheets = await workbook.inspect({
    kind: "sheet",
    include: "id,name",
    maxChars: 8000,
  });
  await fs.writeFile(
    path.resolve("scripts", `inspect_words_approved.${tag}.sheets.ndjson`),
    sheets.ndjson,
    "utf8",
  );

  const table = await workbook.inspect({
    kind: "table",
    sheetId: "words_approved",
    range: "A1:Z120",
    include: "values",
    tableMaxRows: 120,
    tableMaxCols: 26,
    maxChars: 200000,
  });
  await fs.writeFile(
    path.resolve("scripts", `inspect_words_approved.${tag}.table.ndjson`),
    table.ndjson,
    "utf8",
  );
}

await main();

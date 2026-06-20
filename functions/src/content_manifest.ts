// Server-side access to the generated content manifest. The manifest is the
// authoritative source for grading answers, expected speaking text, and per-mode
// item counts so that Cloud Functions never trust client-supplied answer keys.

import {thaiContentManifest} from "./generated/thai_content_manifest";

interface ManifestItem {
  type: "sentence" | "word";
  expectedText: string;
}

interface ManifestContentSet {
  category: string;
  level: string;
  modeTotals: Record<string, number>;
  items: Record<string, ManifestItem>;
}

const contentSets =
  thaiContentManifest.contentSets as unknown as Record<string, ManifestContentSet>;

export function manifestSourceHash(): string {
  return thaiContentManifest.sourceHash;
}

export function getManifestContentSet(
  contentSetId: string,
): ManifestContentSet | null {
  return contentSets[contentSetId] ?? null;
}

export function getManifestItem(
  contentSetId: string,
  itemId: string,
): ManifestItem | null {
  const set = contentSets[contentSetId];
  if (!set) {
    return null;
  }
  return set.items[itemId] ?? null;
}

export function getManifestModeTotal(
  contentSetId: string,
  mode: string,
): number | null {
  const set = contentSets[contentSetId];
  if (!set) {
    return null;
  }
  const total = set.modeTotals[mode];
  return typeof total === "number" && total > 0 ? total : null;
}

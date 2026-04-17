export interface SeedSentenceItem {
  itemId: string;
  order: number;
  thaiText: string;
  nativeText: string;
  pronunciation: string;
  hint: string;
  audioUrl: string;
}

export interface SeedContentSet {
  contentSetId: string;
  title: string;
  description: string;
  category: "daily" | "mission";
  level: "beginner" | "intermediate" | "advanced";
  mode: "sentence_learning";
  locale: "th-TH";
  items: SeedSentenceItem[];
}

export const seedContentSets: SeedContentSet[] = [
  {
    contentSetId: "daily-beginner-default",
    title: "Daily Basics",
    description: "Beginner Thai greetings and simple daily phrases.",
    category: "daily",
    level: "beginner",
    mode: "sentence_learning",
    locale: "th-TH",
    items: [
      {
        itemId: "daily-beginner-001",
        order: 1,
        thaiText: "Sawasdee krap",
        nativeText: "Hello.",
        pronunciation: "sa-wat-dee krap",
        hint: "A polite and common greeting in Thai.",
        audioUrl: "",
      },
      {
        itemId: "daily-beginner-002",
        order: 2,
        thaiText: "Khob khun krap",
        nativeText: "Thank you.",
        pronunciation: "khob-khun krap",
        hint: "Use this to express thanks politely.",
        audioUrl: "",
      },
      {
        itemId: "daily-beginner-003",
        order: 3,
        thaiText: "Pai duay kan",
        nativeText: "Let us go together.",
        pronunciation: "pai duay kan",
        hint: "A simple phrase for moving or traveling together.",
        audioUrl: "",
      },
    ],
  },
  {
    contentSetId: "mission-beginner-default",
    title: "Mission Conversation",
    description: "Beginner phrases for simple mission and ministry settings.",
    category: "mission",
    level: "beginner",
    mode: "sentence_learning",
    locale: "th-TH",
    items: [
      {
        itemId: "mission-beginner-001",
        order: 1,
        thaiText: "Rao maa chuay kan",
        nativeText: "We came to help together.",
        pronunciation: "rao maa chuay kan",
        hint: "A gentle phrase for introducing shared service.",
        audioUrl: "",
      },
      {
        itemId: "mission-beginner-002",
        order: 2,
        thaiText: "Rao yak athithan duay kan",
        nativeText: "We want to pray together.",
        pronunciation: "rao yak a-thi-than duay kan",
        hint: "Useful when inviting someone to pray together.",
        audioUrl: "",
      },
      {
        itemId: "mission-beginner-003",
        order: 3,
        thaiText: "Phra chao rak khun",
        nativeText: "God loves you.",
        pronunciation: "phra-chao rak khun",
        hint: "A core encouragement phrase in mission conversation.",
        audioUrl: "",
      },
    ],
  },
];

export function getSeedContentSet(contentSetId: string): SeedContentSet | undefined {
  return seedContentSets.find((set) => set.contentSetId === contentSetId);
}

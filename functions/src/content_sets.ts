export interface SeedSentenceItem {
  itemId: string;
  order: number;
  thaiText: string;
  nativeText: string;
  pronunciation: string;
  hint: string;
  audioUrl: string;
}

export interface SeedWordItem {
  wordId: string;
  order: number;
  foreignText: string;
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
  version: number;
  season: string;
  isActive: boolean;
  supportsExpansion: boolean;
  sentences: SeedSentenceItem[];
  words: SeedWordItem[];
}

export const seedContentSets: SeedContentSet[] = [
  {
    contentSetId: "daily-beginner-default",
    title: "일상 회화 - 초급",
    description: "한국인 학습자를 위한 태국어 일상 핵심 문장/단어.",
    category: "daily",
    level: "beginner",
    mode: "sentence_learning",
    locale: "th-TH",
    version: 3,
    season: "default",
    isActive: true,
    supportsExpansion: false,
    sentences: [
      {
        itemId: "daily-beginner-001",
        order: 1,
        thaiText: "สวัสดี (ครับ/ค่ะ)",
        nativeText: "안녕하세요",
        pronunciation: "sa-wat-dee (khrap/kha)",
        hint: "기본 인사 표현",
        audioUrl: "",
      },
      {
        itemId: "daily-beginner-002",
        order: 2,
        thaiText: "ขอบคุณ (ครับ/ค่ะ)",
        nativeText: "감사합니다",
        pronunciation: "khop-khun (khrap/kha)",
        hint: "감사 표현",
        audioUrl: "",
      },
      {
        itemId: "daily-beginner-003",
        order: 3,
        thaiText: "ไม่ใช่ (ครับ/ค่ะ)",
        nativeText: "아니요",
        pronunciation: "mai chai (khrap/kha)",
        hint: "부정 응답",
        audioUrl: "",
      },
    ],
    words: [
      {
        wordId: "daily-word-001",
        order: 1,
        foreignText: "สวัสดี",
        nativeText: "안녕하세요",
        pronunciation: "sa-wat-dee",
        hint: "인사",
        audioUrl: "",
      },
      {
        wordId: "daily-word-002",
        order: 2,
        foreignText: "ขอบคุณ",
        nativeText: "감사합니다",
        pronunciation: "khop-khun",
        hint: "감사",
        audioUrl: "",
      },
      {
        wordId: "daily-word-003",
        order: 3,
        foreignText: "ไม่ใช่",
        nativeText: "아니요",
        pronunciation: "mai chai",
        hint: "부정",
        audioUrl: "",
      },
    ],
  },
  {
    contentSetId: "mission-beginner-default",
    title: "미션 회화 - 초급",
    description: "한국인 학습자를 위한 태국어 미션 핵심 문장/단어.",
    category: "mission",
    level: "beginner",
    mode: "sentence_learning",
    locale: "th-TH",
    version: 3,
    season: "default",
    isActive: true,
    supportsExpansion: false,
    sentences: [
      {
        itemId: "mission-beginner-001",
        order: 1,
        thaiText: "พระเยซูรักคุณ",
        nativeText: "예수님은 당신을 사랑합니다",
        pronunciation: "phra-yesu rak khun",
        hint: "핵심 미션 문장",
        audioUrl: "",
      },
      {
        itemId: "mission-beginner-002",
        order: 2,
        thaiText: "เราอยากอธิษฐานด้วยกัน",
        nativeText: "함께 기도하고 싶어요",
        pronunciation: "rao yak a-thit-than duai kan",
        hint: "기도 제안 문장",
        audioUrl: "",
      },
      {
        itemId: "mission-beginner-003",
        order: 3,
        thaiText: "พระเจ้าทรงรักคุณ",
        nativeText: "하나님은 당신을 사랑합니다",
        pronunciation: "phra-chao song rak khun",
        hint: "복음 핵심 문장",
        audioUrl: "",
      },
    ],
    words: [
      {
        wordId: "mission-word-001",
        order: 1,
        foreignText: "พระเยซู",
        nativeText: "예수님",
        pronunciation: "phra-yesu",
        hint: "미션 핵심 단어",
        audioUrl: "",
      },
      {
        wordId: "mission-word-002",
        order: 2,
        foreignText: "รัก",
        nativeText: "사랑하다",
        pronunciation: "rak",
        hint: "핵심 동사",
        audioUrl: "",
      },
      {
        wordId: "mission-word-003",
        order: 3,
        foreignText: "อธิษฐาน",
        nativeText: "기도하다",
        pronunciation: "a-thit-than",
        hint: "신앙 표현",
        audioUrl: "",
      },
    ],
  },
];

export function getSeedContentSet(contentSetId: string): SeedContentSet | undefined {
  return seedContentSets.find((set) => set.contentSetId === contentSetId);
}

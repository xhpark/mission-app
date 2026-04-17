import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import {getSeedContentSet} from "./content_sets";

admin.initializeApp();
setGlobalOptions({region: "asia-northeast3", maxInstances: 10});

const db = admin.firestore();

type ReportGateStage = "none" | "warning" | "forced";
type StudyCategory = "daily" | "mission";
type StudyLevel = "beginner" | "intermediate" | "advanced";
type StudyMode =
  | "sentence_learning"
  | "sentence_test"
  | "flash_word_learning"
  | "flash_word_test"
  | "flash_sentence_learning"
  | "flash_sentence_test";

interface BootstrapUserSessionData {
  userId: string;
  deviceId: string;
}

interface StartStudySessionData {
  userId: string;
  contentSetId: string;
  category: StudyCategory;
  level: StudyLevel;
  mode: StudyMode;
}

interface GetSentenceLearningItemData {
  userId: string;
  sessionId: string;
}

interface CompleteSentenceStudyData {
  userId: string;
  sessionId: string;
  itemId: string;
}

interface SentenceItemPayload {
  itemId: string;
  order: number;
  thaiText: string;
  nativeText: string;
  pronunciation: string;
  hint: string;
  audioUrl: string;
}

function requireAuthenticatedUser(authUid: string | undefined, userId: string): void {
  if (!authUid) {
    throw new HttpsError("unauthenticated", "AUTH_REQUIRED");
  }

  if (authUid !== userId) {
    throw new HttpsError("permission-denied", "USER_MISMATCH");
  }
}

function ensureString(value: unknown, fieldName: string): string {
  if (typeof value != "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }

  return value.trim();
}

function isStudyCategory(value: string): value is StudyCategory {
  return value === "daily" || value === "mission";
}

function isStudyLevel(value: string): value is StudyLevel {
  return value === "beginner" || value === "intermediate" || value === "advanced";
}

function isStudyMode(value: string): value is StudyMode {
  return [
    "sentence_learning",
    "sentence_test",
    "flash_word_learning",
    "flash_word_test",
    "flash_sentence_learning",
    "flash_sentence_test",
  ].includes(value);
}

function buildFallbackSentenceItem(contentSetId: string) {
  return {
    itemId: `${contentSetId}-intro`,
    order: 1,
    thaiText: "สวัสดีครับ",
    nativeText: "Hello.",
    pronunciation: "sa-wat-dee krap",
    hint: "A polite and simple Thai greeting used in everyday conversation.",
    audioUrl: "",
  };
}

function buildFallbackSentenceItems(contentSetId: string): SentenceItemPayload[] {
  return [
    {
      itemId: `${contentSetId}-intro-1`,
      order: 1,
      thaiText: "Sawasdee krap",
      nativeText: "Hello.",
      pronunciation: "sa-wat-dee krap",
      hint: "A polite and simple Thai greeting used in everyday conversation.",
      audioUrl: "",
    },
    {
      itemId: `${contentSetId}-intro-2`,
      order: 2,
      thaiText: "Khob khun krap",
      nativeText: "Thank you.",
      pronunciation: "khob-khun krap",
      hint: "A polite phrase used to express thanks.",
      audioUrl: "",
    },
    {
      itemId: `${contentSetId}-intro-3`,
      order: 3,
      thaiText: "Pai duay kan",
      nativeText: "Let us go together.",
      pronunciation: "pai duay kan",
      hint: "A simple invitation phrase for moving together.",
      audioUrl: "",
    },
  ];
}

async function resolveSentenceItems(contentSetId: string): Promise<SentenceItemPayload[]> {
  const itemsQuery = db
    .collection(`content_sets/${contentSetId}/items`)
    .orderBy("order", "asc");

  const itemsSnap = await itemsQuery.get();
  if (itemsSnap.empty) {
    return getSeedContentSet(contentSetId)?.items ?? buildFallbackSentenceItems(contentSetId);
  }

  const fallbackItems =
    getSeedContentSet(contentSetId)?.items ?? buildFallbackSentenceItems(contentSetId);
  return itemsSnap.docs.map((doc, index) => {
    const fallback = fallbackItems[index] ?? fallbackItems[fallbackItems.length - 1];
    const data = doc.data();
    return {
      ...fallback,
      ...data,
      itemId: doc.id,
      order: typeof data.order === "number" ? data.order : index + 1,
    };
  });
}

function buildSentenceItemResponse(
  sessionId: string,
  contentSetId: string,
  item: SentenceItemPayload,
  totalSteps: number,
  sessionCompleted = false,
) {
  return {
    sessionId,
    contentSetId,
    ...item,
    sessionCompleted,
    progress: {
      currentStep: item.order,
      totalSteps,
    },
  };
}

async function resolveReportGateStage(userId: string): Promise<{
  learningBlocked: boolean;
  reportGateStage: ReportGateStage;
}> {
  const reportStateRef = db.doc(`user_report_state/${userId}`);
  const reportStateSnap = await reportStateRef.get();
  const reportState = reportStateSnap.data() ?? {};

  const learningBlocked = reportState.learningBlocked === true;
  const reportGateStage = (reportState.reportGateStage as ReportGateStage | undefined) ?? "none";

  return {
    learningBlocked,
    reportGateStage,
  };
}

export const bootstrapUserSession = onCall<BootstrapUserSessionData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const deviceId = ensureString(request.data?.deviceId, "deviceId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const userProfileRef = db.doc(`user_profiles/${userId}`);
  const runtimeRef = db.doc(`user_runtime/${userId}`);
  const resumeQuery = db.collection(`resume_states/${userId}/draft`).limit(1);

  const [profileSnap, runtimeSnap, resumeSnap, reportGate] = await Promise.all([
    userProfileRef.get(),
    runtimeRef.get(),
    resumeQuery.get(),
    resolveReportGateStage(userId),
  ]);

  if (!profileSnap.exists) {
    await userProfileRef.set(
      {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "approved",
        deviceId,
      },
      {merge: true},
    );
  }

  if (!runtimeSnap.exists) {
    await runtimeRef.set(
      {
        appState: "active",
        learningBlocked: reportGate.learningBlocked,
        reportGateStage: reportGate.reportGateStage,
        deviceId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  } else {
    await runtimeRef.set(
      {
        appState: "active",
        learningBlocked: reportGate.learningBlocked,
        reportGateStage: reportGate.reportGateStage,
        deviceId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }

  return {
    approved: (profileSnap.data()?.status as string | undefined) !== "blocked",
    learningBlocked: reportGate.learningBlocked,
    reportGateStage: reportGate.reportGateStage,
    hasResume: !resumeSnap.empty,
    resumeSummary: resumeSnap.empty ? null : resumeSnap.docs[0].data(),
  };
});

export const startStudySession = onCall<StartStudySessionData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const contentSetId = ensureString(request.data?.contentSetId, "contentSetId");
  const category = ensureString(request.data?.category, "category");
  const level = ensureString(request.data?.level, "level");
  const mode = ensureString(request.data?.mode, "mode");

  requireAuthenticatedUser(request.auth?.uid, userId);

  if (!isStudyCategory(category)) {
    throw new HttpsError("invalid-argument", "INVALID_CATEGORY");
  }

  if (!isStudyLevel(level)) {
    throw new HttpsError("invalid-argument", "INVALID_LEVEL");
  }

  if (!isStudyMode(mode)) {
    throw new HttpsError("invalid-argument", "INVALID_MODE");
  }

  const reportGate = await resolveReportGateStage(userId);
  if (reportGate.learningBlocked) {
    throw new HttpsError("failed-precondition", "LEARNING_BLOCKED");
  }

  const sessionRef = db.collection(`study_sessions/${userId}/sessions`).doc();
  const startedAt = admin.firestore.Timestamp.now();

  await db.runTransaction(async (transaction) => {
    transaction.set(sessionRef, {
      sessionId: sessionRef.id,
      userId,
      contentSetId,
      category,
      level,
      mode,
      startedAt,
      status: "active",
    });

    transaction.set(
      db.doc(`user_runtime/${userId}`),
      {
        currentMode: mode,
        currentContentSetId: contentSetId,
        currentSessionId: sessionRef.id,
        appState: "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  return {
    sessionId: sessionRef.id,
    startedAt: startedAt.toDate().toISOString(),
  };
});

export const getSentenceLearningItem = onCall<GetSentenceLearningItemData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const sessionRef = db.doc(`study_sessions/${userId}/sessions/${sessionId}`);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists) {
    throw new HttpsError("not-found", "SESSION_NOT_FOUND");
  }

  const sessionData = sessionSnap.data() ?? {};
  const contentSetId = ensureString(sessionData.contentSetId, "contentSetId");
  const mode = ensureString(sessionData.mode, "mode");

  if (mode !== "sentence_learning" && mode !== "sentence_test") {
    throw new HttpsError("failed-precondition", "MODE_NOT_SUPPORTED");
  }

  const items = await resolveSentenceItems(contentSetId);
  const itemData = items[0];

  await sessionRef.set(
    {
      currentItemId: itemData.itemId,
      currentItemOrder: itemData.order,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return buildSentenceItemResponse(sessionId, contentSetId, itemData, items.length);
});

export const completeSentenceStudy = onCall<CompleteSentenceStudyData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  const itemId = ensureString(request.data?.itemId, "itemId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const sessionRef = db.doc(`study_sessions/${userId}/sessions/${sessionId}`);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists) {
    throw new HttpsError("not-found", "SESSION_NOT_FOUND");
  }

  const sessionData = sessionSnap.data() ?? {};
  const contentSetId = ensureString(sessionData.contentSetId, "contentSetId");
  const mode = ensureString(sessionData.mode, "mode");
  const currentItemId = ensureString(sessionData.currentItemId ?? itemId, "currentItemId");

  if (mode !== "sentence_learning") {
    throw new HttpsError("failed-precondition", "MODE_NOT_SUPPORTED");
  }

  if (currentItemId !== itemId) {
    throw new HttpsError("failed-precondition", "ITEM_MISMATCH");
  }

  const items = await resolveSentenceItems(contentSetId);
  const currentIndex = items.findIndex((item) => item.itemId === itemId);
  if (currentIndex === -1) {
    throw new HttpsError("not-found", "ITEM_NOT_FOUND");
  }

  const currentItem = items[currentIndex];
  const nextItem = currentIndex + 1 < items.length ? items[currentIndex + 1] : null;
  const completedItemRef = sessionRef.collection("completed_items").doc(itemId);

  await db.runTransaction(async (transaction) => {
    transaction.set(
      completedItemRef,
      {
        itemId,
        order: currentItem.order,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    if (nextItem) {
      transaction.set(
        sessionRef,
        {
          currentItemId: nextItem.itemId,
          currentItemOrder: nextItem.order,
          status: "active",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      return;
    }

    transaction.set(
      sessionRef,
      {
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  if (nextItem) {
    return buildSentenceItemResponse(sessionId, contentSetId, nextItem, items.length);
  }

  return buildSentenceItemResponse(
    sessionId,
    contentSetId,
    currentItem,
    items.length,
    true,
  );
});

import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import {GoogleAuth} from "google-auth-library";

// Deployment marker: triggers full function update for runtime migration.

admin.initializeApp();
setGlobalOptions({region: "asia-northeast3", maxInstances: 10});

const db = admin.firestore();
const defaultActiveContentSetId = "daily-beginner-default";
const defaultAdminContact = "010-0000-0000";

type ReportGateStage = "none" | "warning" | "forced";
type UserStatus = "pending_approval" | "approved" | "blocked";
type StudyCategory = "daily" | "mission";
type StudyLevel = "beginner" | "intermediate" | "advanced";
type StudyMode =
  | "sentence_learning"
  | "sentence_test"
  | "flash_word_learning"
  | "flash_word_test"
  | "flash_sentence_learning"
  | "flash_sentence_test";
type SpeakingEvalMode = "sentence_test_speaking" | "flash_sentence_test_speaking";

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

interface SubmitChoiceTestItemData {
  userId: string;
  sessionId: string;
  itemId: string;
  selectedIndex: number;
  correctIndex: number;
  elapsedSeconds?: number;
}

interface GenerateReportPreviewData {
  userId: string;
  sessionId: string;
}

interface CompleteReportSubmissionData {
  userId: string;
  sessionId: string;
  reflection: string;
  speakingCompleted: boolean;
  listeningCompleted: boolean;
}

interface ResumeStateData {
  userId: string;
  sessionId: string;
  route: string;
}

interface DiscardResumeStateData {
  userId: string;
  sessionId: string;
}

interface AbandonStudySessionData {
  userId: string;
  sessionId: string;
  reason?: string;
}

interface EvaluateSpeakingAttemptData {
  userId: string;
  sessionId: string;
  itemId: string;
  mode: SpeakingEvalMode;
  expectedText: string;
  audioPath: string;
  durationMs?: number;
}

interface SubmitOnDeviceSpeakingFallbackData {
  userId: string;
  sessionId: string;
  itemId: string;
  mode: SpeakingEvalMode;
  expectedText: string;
  transcript: string;
  audioPath?: string;
  engine?: string;
  durationMs?: number;
}

interface SpeechToTextResponse {
  results?: Array<{
    alternatives?: Array<{
      transcript?: string;
    }>;
  }>;
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

function isWordMode(mode: StudyMode): boolean {
  return mode === "flash_word_learning" || mode === "flash_word_test";
}

function isSpeakingEvalMode(value: string): value is SpeakingEvalMode {
  return value === "sentence_test_speaking" || value === "flash_sentence_test_speaking";
}

function assertOwnedAudioPath(audioPath: string, userId: string, sessionId: string): void {
  const normalized = audioPath.trim();
  const expectedPrefix = `speaking_attempts/${userId}/${sessionId}/`;
  if (!normalized.startsWith(expectedPrefix) || normalized.includes("..")) {
    throw new HttpsError("permission-denied", "AUDIO_PATH_NOT_OWNED");
  }
}

function normalizeForSimilarity(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]/gu, "")
    .trim();
}

function levenshteinDistance(a: string, b: string): number {
  if (a === b) {
    return 0;
  }
  if (a.length === 0) {
    return b.length;
  }
  if (b.length === 0) {
    return a.length;
  }

  const previous = new Array<number>(b.length + 1);
  const current = new Array<number>(b.length + 1);
  for (let j = 0; j <= b.length; j += 1) {
    previous[j] = j;
  }

  for (let i = 1; i <= a.length; i += 1) {
    current[0] = i;
    for (let j = 1; j <= b.length; j += 1) {
      const substitutionCost = a[i - 1] === b[j - 1] ? 0 : 1;
      current[j] = Math.min(
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + substitutionCost,
      );
    }
    for (let j = 0; j <= b.length; j += 1) {
      previous[j] = current[j];
    }
  }
  return previous[b.length];
}

function calculateSimilarityScore(expected: string, transcript: string): number {
  const normalizedExpected = normalizeForSimilarity(expected);
  const normalizedTranscript = normalizeForSimilarity(transcript);
  if (normalizedExpected.length === 0 || normalizedTranscript.length === 0) {
    return 0;
  }
  const maxLen = Math.max(normalizedExpected.length, normalizedTranscript.length);
  const distance = levenshteinDistance(normalizedExpected, normalizedTranscript);
  const ratio = Math.max(0, 1 - distance / maxLen);
  return Math.round(ratio * 100);
}

async function transcribeThaiSpeech({
  projectId,
  audioBase64,
}: {
  projectId: string;
  audioBase64: string;
}): Promise<string> {
  const auth = new GoogleAuth({scopes: ["https://www.googleapis.com/auth/cloud-platform"]});
  const client = await auth.getClient();
  const tokenResult = await client.getAccessToken();
  const accessToken = typeof tokenResult === "string" ? tokenResult : tokenResult?.token;
  if (!accessToken) {
    throw new Error("STT_ACCESS_TOKEN_MISSING");
  }

  const endpoint =
    `https://speech.googleapis.com/v2/projects/${projectId}` +
    "/locations/global/recognizers/_:recognize";
  const fetchFn = (globalThis as {fetch: (...args: unknown[]) => Promise<{
    ok: boolean;
    status: number;
    json: () => Promise<unknown>;
  }>}).fetch;
  const response = await fetchFn(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      config: {
        autoDecodingConfig: {},
        languageCodes: ["th-TH"],
        model: "short",
      },
      content: audioBase64,
    }),
  });

  if (!response.ok) {
    throw new Error(`STT_HTTP_${response.status}`);
  }
  const body = await response.json() as SpeechToTextResponse;
  const transcript = body.results?.[0]?.alternatives?.[0]?.transcript?.trim() ?? "";
  return transcript;
}

function buildFallbackSentenceItem(contentSetId: string) {
  return {
    itemId: `${contentSetId}-intro`,
    order: 1,
    thaiText: "สวัสดีครับ",
    nativeText: "Hello.",
    pronunciation: "sa-wat-dee krap",
    hint: "A polite and simple Thai greeting used in everyday conversation.",
    audioPath: "",
    audioUrl: "",
  };
}

async function resolveModeTotalItems(
  contentSetId: string,
  mode: StudyMode,
): Promise<number> {
  const contentSetSnap = await db.doc(`content_sets/${contentSetId}`).get();
  const contentSetData = contentSetSnap.data() ?? {};
  const modeCounts = contentSetData.itemCountByMode as Record<string, unknown> | undefined;
  const countedFromMap = modeCounts?.[mode];
  if (typeof countedFromMap === "number" && countedFromMap > 0) {
    return countedFromMap;
  }

  const sentenceItemCount = contentSetData.sentenceItemCount;
  if (
    typeof sentenceItemCount === "number" &&
    sentenceItemCount > 0 &&
    (
      mode === "sentence_learning" ||
      mode === "sentence_test" ||
      mode === "flash_sentence_learning" ||
      mode === "flash_sentence_test"
    )
  ) {
    return sentenceItemCount;
  }

  if (isWordMode(mode)) {
    const wordsSnap = await db.collection(`content_sets/${contentSetId}/words`).get();
    if (!wordsSnap.empty) {
      return wordsSnap.size;
    }
    const wordItemCount = contentSetData.wordItemCount;
    if (typeof wordItemCount === "number" && wordItemCount > 0) {
      return wordItemCount;
    }
    return 0;
  }

  return 0;
}

async function resolveUserStatus(userId: string): Promise<UserStatus> {
  const profileSnap = await db.doc(`user_profiles/${userId}`).get();
  const rawStatus = profileSnap.data()?.status;

  if (rawStatus === "approved" || rawStatus === "blocked" || rawStatus === "pending_approval") {
    return rawStatus;
  }

  return "pending_approval";
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

  let userStatus: UserStatus =
    (profileSnap.data()?.status as UserStatus | undefined) ?? "pending_approval";

  if (!profileSnap.exists) {
    userStatus = "pending_approval";
    await userProfileRef.set(
      {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: userStatus,
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
    status: userStatus,
    approved: userStatus == "approved",
    learningBlocked: reportGate.learningBlocked,
    reportGateStage: reportGate.reportGateStage,
    hasResume: !resumeSnap.empty,
    resumeSummary: resumeSnap.empty ? null : resumeSnap.docs[0].data(),
    activeContentSetId:
      (runtimeSnap.data()?.activeContentSetId as string | undefined) ?? defaultActiveContentSetId,
    adminContact: defaultAdminContact,
  };
});

export const startStudySession = onCall<StartStudySessionData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const contentSetId = ensureString(request.data?.contentSetId, "contentSetId");
  const category = ensureString(request.data?.category, "category");
  const level = ensureString(request.data?.level, "level");
  const mode = ensureString(request.data?.mode, "mode");

  requireAuthenticatedUser(request.auth?.uid, userId);
  const userStatus = await resolveUserStatus(userId);

  if (userStatus === "blocked") {
    throw new HttpsError("permission-denied", "USER_BLOCKED");
  }

  if (userStatus !== "approved") {
    throw new HttpsError("failed-precondition", "PENDING_APPROVAL");
  }

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

  const resolvedTotalItems = await resolveModeTotalItems(contentSetId, mode);

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
        activeContentSetId: contentSetId,
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
    totalItems: resolvedTotalItems,
  };
});

export const submitChoiceTestItem = onCall<SubmitChoiceTestItemData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  const itemId = ensureString(request.data?.itemId, "itemId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const selectedIndex = Number(request.data?.selectedIndex ?? -1);
  const correctIndex = Number(request.data?.correctIndex ?? -1);
  const elapsedSeconds = Number(request.data?.elapsedSeconds ?? 0);
  if (Number.isNaN(selectedIndex) || Number.isNaN(correctIndex)) {
    throw new HttpsError("invalid-argument", "INVALID_CHOICE_PAYLOAD");
  }

  const score = selectedIndex === correctIndex ? 1 : 0;
  const attemptRef = db.doc(`test_results/${userId}/attempts/${sessionId}`);
  await attemptRef.set(
    {
      userId,
      sessionId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await attemptRef.collection("items").doc(itemId).set(
    {
      userId,
      sessionId,
      itemId,
      mode: "choice",
      selectedIndex,
      correctIndex,
      score,
      elapsedSeconds,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {
    sessionId,
    itemId,
    score,
    correct: score === 1,
  };
});

export const evaluateSpeakingAttempt = onCall<EvaluateSpeakingAttemptData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  const itemId = ensureString(request.data?.itemId, "itemId");
  const expectedText = ensureString(request.data?.expectedText, "expectedText");
  const audioPath = ensureString(request.data?.audioPath, "audioPath");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const rawMode = ensureString(request.data?.mode, "mode");
  if (!isSpeakingEvalMode(rawMode)) {
    throw new HttpsError("invalid-argument", "INVALID_SPEAKING_MODE");
  }
  assertOwnedAudioPath(audioPath, userId, sessionId);

  const sessionSnap = await db.doc(`study_sessions/${userId}/sessions/${sessionId}`).get();
  if (!sessionSnap.exists) {
    throw new HttpsError("not-found", "SESSION_NOT_FOUND");
  }

  const mode = rawMode;
  const threshold = 70;
  const durationMs = Number(request.data?.durationMs ?? 0);

  let transcript = "";
  let similarityScore = 0;
  let passed = false;
  let errorCode: string | null = null;
  let message = "발음 평가를 완료했습니다.";

  try {
    const bucket = admin.storage().bucket();
    const [audioBuffer] = await bucket.file(audioPath).download();
    if (audioBuffer.length === 0) {
      throw new Error("EMPTY_AUDIO");
    }
    const projectId = process.env.GCLOUD_PROJECT ?? admin.app().options.projectId;
    if (!projectId) {
      throw new Error("PROJECT_ID_MISSING");
    }

    transcript = await transcribeThaiSpeech({
      projectId,
      audioBase64: audioBuffer.toString("base64"),
    });
    similarityScore = calculateSimilarityScore(expectedText, transcript);
    passed = similarityScore >= threshold;
    message = passed ? "발음 평가를 통과했습니다." : "발음 평가 점수가 부족합니다. 다시 시도해 주세요.";
  } catch (error) {
    errorCode = "STT_UNAVAILABLE";
    passed = false;
    similarityScore = 0;
    message = "음성 인식 엔진 장애로 평가를 완료하지 못했습니다.";
    console.error("evaluateSpeakingAttempt failed", {
      userId,
      sessionId,
      itemId,
      mode,
      audioPath,
      error,
    });
  }

  const attemptRef = db.doc(`test_results/${userId}/attempts/${sessionId}`);
  await attemptRef.set(
    {
      userId,
      sessionId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await attemptRef.collection("items").doc(`${itemId}_${mode}`).set(
    {
      userId,
      sessionId,
      itemId,
      mode,
      expectedText,
      transcript,
      similarityScore,
      passed,
      threshold,
      audioPath,
      durationMs: Number.isFinite(durationMs) ? durationMs : 0,
      errorCode,
      evaluatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {
    userId,
    sessionId,
    itemId,
    mode,
    transcript,
    similarityScore,
    passed,
    threshold,
    errorCode,
    message,
  };
});

export const submitOnDeviceSpeakingFallback = onCall<SubmitOnDeviceSpeakingFallbackData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  const itemId = ensureString(request.data?.itemId, "itemId");
  const expectedText = ensureString(request.data?.expectedText, "expectedText");
  const transcript = ensureString(request.data?.transcript, "transcript");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const rawMode = ensureString(request.data?.mode, "mode");
  if (!isSpeakingEvalMode(rawMode)) {
    throw new HttpsError("invalid-argument", "INVALID_SPEAKING_MODE");
  }

  const sessionSnap = await db.doc(`study_sessions/${userId}/sessions/${sessionId}`).get();
  if (!sessionSnap.exists) {
    throw new HttpsError("not-found", "SESSION_NOT_FOUND");
  }

  const mode = rawMode;
  const threshold = 70;
  const similarityScore = calculateSimilarityScore(expectedText, transcript);
  const passed = similarityScore >= threshold;
  const durationMs = Number(request.data?.durationMs ?? 0);
  const audioPathRaw = request.data?.audioPath;
  const audioPath =
    typeof audioPathRaw === "string" && audioPathRaw.trim().length > 0 ? audioPathRaw.trim() : "";
  if (audioPath.length > 0) {
    assertOwnedAudioPath(audioPath, userId, sessionId);
  }
  const engineRaw = request.data?.engine;
  const engine = typeof engineRaw === "string" && engineRaw.trim().length > 0 ?
    engineRaw.trim() :
    "sherpa_onnx";

  const attemptRef = db.doc(`test_results/${userId}/attempts/${sessionId}`);
  await attemptRef.set(
    {
      userId,
      sessionId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await attemptRef.collection("items").doc(`${itemId}_${mode}`).set(
    {
      userId,
      sessionId,
      itemId,
      mode,
      expectedText,
      transcript,
      similarityScore,
      passed,
      threshold,
      audioPath,
      durationMs: Number.isFinite(durationMs) ? durationMs : 0,
      onDeviceFallback: true,
      fallbackEngine: engine,
      errorCode: null,
      evaluatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {
    userId,
    sessionId,
    itemId,
    mode,
    transcript,
    similarityScore,
    passed,
    threshold,
    errorCode: null,
    message: passed ? "온디바이스 ASR 평가를 통과했습니다." : "온디바이스 ASR 평가 점수가 부족합니다.",
  };
});

export const generateReportPreview = onCall<GenerateReportPreviewData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const sessionSnap = await db.doc(`study_sessions/${userId}/sessions/${sessionId}`).get();
  if (!sessionSnap.exists) {
    throw new HttpsError("not-found", "SESSION_NOT_FOUND");
  }

  const sessionData = sessionSnap.data() ?? {};
  const startedAt = sessionData.startedAt instanceof admin.firestore.Timestamp ?
    sessionData.startedAt.toDate().toISOString() : "";

  const preview = {
    sessionId,
    contentSetId: sessionData.contentSetId ?? "",
    category: sessionData.category ?? "",
    level: sessionData.level ?? "",
    mode: sessionData.mode ?? "",
    startedAt,
    summary: "학습 요약이 준비되었습니다. 리포트를 작성해 제출하세요.",
  };

  await db.doc(`reports/${userId}/report_previews/${sessionId}`).set(
    {
      ...preview,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return preview;
});

export const completeReportSubmission = onCall<CompleteReportSubmissionData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  const reflection = ensureString(request.data?.reflection, "reflection");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const speakingCompleted = request.data?.speakingCompleted === true;
  const listeningCompleted = request.data?.listeningCompleted === true;
  const reportId = `${sessionId}-${Date.now()}`;

  await db.doc(`reports/${userId}/report_history/${reportId}`).set({
    reportId,
    sessionId,
    userId,
    reflection,
    speakingCompleted,
    listeningCompleted,
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.doc(`user_report_state/${userId}`).set(
    {
      learningBlocked: false,
      reportGateStage: "none",
      lastReportSubmittedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {
    reportId,
    sessionId,
    accepted: true,
  };
});

export const saveResumeState = onCall<ResumeStateData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  const route = ensureString(request.data?.route, "route");
  requireAuthenticatedUser(request.auth?.uid, userId);

  await db.doc(`resume_states/${userId}/draft/${sessionId}`).set(
    {
      userId,
      sessionId,
      route,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {saved: true, sessionId, route};
});

export const discardResumeState = onCall<DiscardResumeStateData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  await db.doc(`resume_states/${userId}/draft/${sessionId}`).delete();
  return {deleted: true, sessionId};
});

export const abandonStudySession = onCall<AbandonStudySessionData>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const reasonRaw = request.data?.reason;
  const reason = typeof reasonRaw === "string" && reasonRaw.trim().length > 0 ?
    reasonRaw.trim() :
    "user_started_new_session";

  const sessionRef = db.doc(`study_sessions/${userId}/sessions/${sessionId}`);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists) {
    throw new HttpsError("not-found", "SESSION_NOT_FOUND");
  }

  await sessionRef.set(
    {
      status: "abandoned",
      abandonedAt: admin.firestore.FieldValue.serverTimestamp(),
      abandonReason: reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await db.doc(`resume_states/${userId}/draft/${sessionId}`).delete();

  return {abandoned: true, sessionId, reason};
});

export const checkWeeklyReportGate = onCall<{userId: string}>(async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const stateRef = db.doc(`user_report_state/${userId}`);
  const snap = await stateRef.get();
  const state = snap.data() ?? {};
  const reportGateStage = (state.reportGateStage as ReportGateStage | undefined) ?? "none";
  const learningBlocked = state.learningBlocked === true;

  return {
    reportGateStage,
    learningBlocked,
  };
});

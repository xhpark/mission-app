import * as admin from "firebase-admin";
import nodemailer from "nodemailer";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {setGlobalOptions} from "firebase-functions/v2";
import {GoogleAuth} from "google-auth-library";
import {
  getManifestItem,
  getManifestModeTotal,
} from "./content_manifest";

// Deployment marker: triggers full function update for runtime migration.

admin.initializeApp();
setGlobalOptions({
  region: "asia-northeast3",
  maxInstances: 10,
  // Callable requests must reach the function before Firebase Auth can be
  // validated in code. Cloud Run-level 401s would otherwise block valid users.
  invoker: "public",
});

const db = admin.firestore();
const defaultActiveContentSetId = "daily-beginner-default";

// Operator identity and pre-approved accounts are provided through environment
// configuration (functions/.env, see functions/.env.example) so that real PII is
// never committed to source control.
function envString(name: string, fallback = ""): string {
  const value = process.env[name];
  return typeof value === "string" && value.trim().length > 0 ?
    value.trim() :
    fallback;
}

function envEmailSet(name: string): Set<string> {
  return new Set(
    envString(name)
      .split(",")
      .map((entry) => normalizeEmail(entry))
      .filter((entry) => entry.length > 0),
  );
}

const defaultAdminContact = envString("ADMIN_CONTACT", "000-0000-0000");
const defaultAdminApprovalEmail = normalizeEmail(envString("ADMIN_APPROVAL_EMAIL"));
const defaultAdminLearnerName = envString("ADMIN_DEFAULT_NAME");
const defaultAdminLearnerPhone = envString("ADMIN_DEFAULT_PHONE");
const preApprovedTestEmails = envEmailSet("PREAPPROVED_TEST_EMAILS");

// App Check is enforced on every callable by default. Set ENFORCE_APP_CHECK=false
// in a development project's functions/.env to allow non-attested clients locally.
const callableOptions = {
  enforceAppCheck: envString("ENFORCE_APP_CHECK", "true") !== "false",
};

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
type SpeakingEvalMode =
  | "sentence_test_speaking"
  | "flash_word_test_speaking"
  | "flash_sentence_test_speaking";

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
  totalItems?: number;
}

interface SubmitChoiceTestItemData {
  userId: string;
  sessionId: string;
  itemId: string;
  selectedItemId?: string;
  selectedIndex?: number;
  correctIndex?: number;
  elapsedSeconds?: number;
}

interface GenerateReportPreviewData {
  userId: string;
  sessionId: string;
}

interface CompleteReportSubmissionData {
  userId: string;
  sessionId: string;
  completedItems?: number;
  assessmentApplicable?: boolean;
  correctAnswers?: number;
  attemptedAnswers?: number;
  averageSimilarity?: number | null;
  completedAt?: string;
  durationSeconds?: number;
}

interface AdminDashboardData {
  adminUserId: string;
}

interface GetTodayLinkData {
  dateKey?: string;
}

interface SetTodayLinkData {
  adminUserId: string;
  dateKey?: string;
  url: string;
  title: string;
}

interface RecordTodayLinkClickData {
  dateKey?: string;
}

interface GetTodayLinkClicksData {
  adminUserId: string;
  dateKey?: string;
}

interface StartSimilarityEventData {
  adminUserId: string;
  contentSetId: string;
  itemId: string;
}

interface EndSimilarityEventData {
  adminUserId: string;
  eventId: string;
}

interface GetSimilarityEventData {
  adminUserId: string;
  eventId?: string;
}

interface AddLearnerRosterEntriesData {
  adminUserId: string;
  entries: {name: string; phone: string}[];
}

interface GetLearnerRosterData {
  adminUserId: string;
}

interface DeleteLearnerRosterEntryData {
  adminUserId: string;
  rosterId: string;
}

interface ApproveUserData {
  adminUserId: string;
  targetUserId: string;
}

interface UpdateLearnerProfileData {
  userId: string;
  learnerName: string;
  learnerPhone: string;
}

interface FindLearnerEmailData {
  learnerName: string;
  learnerPhone: string;
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
  audioPath?: string;
  audioBase64?: string;
  mimeType?: string;
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

interface SessionReportStats {
  choiceAttemptCount: number;
  choiceCorrectCount: number;
  choiceAccuracy: number | null;
  speakingAttemptCount: number;
  speakingPassedCount: number;
  speakingPassRate: number | null;
  averageSimilarity: number | null;
  sttFailureCount: number;
  // Number of distinct content items (sentences/words) attempted, not the
  // number of recorded attempt documents. Modes like sentence_test record two
  // attempt documents per item (one "choice", one "*_speaking"), so
  // choiceAttemptCount + speakingAttemptCount double-counts completion
  // against totalItems (which is sized per item, not per stage).
  completedItemCount: number;
}

function requireAuthenticatedUser(authUid: string | undefined, userId: string): void {
  if (!authUid) {
    throw new HttpsError("unauthenticated", "AUTH_REQUIRED");
  }

  if (authUid !== userId) {
    throw new HttpsError("permission-denied", "USER_MISMATCH");
  }
}

function authTokenEmail(authToken: unknown): string {
  if (authToken === null || typeof authToken !== "object") {
    return "";
  }

  const token = authToken as Record<string, unknown>;
  return normalizeEmail(token.email);
}

function authTokenEmailVerified(authToken: unknown): boolean {
  if (authToken === null || typeof authToken !== "object") {
    return false;
  }

  const token = authToken as Record<string, unknown>;
  return token.email_verified === true || token.emailVerified === true;
}

function ensureString(value: unknown, fieldName: string): string {
  if (typeof value != "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }

  return value.trim();
}

function optionalString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function optionalPositiveInteger(value: unknown): number | null {
  if (value === undefined || value === null) {
    return null;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new HttpsError("invalid-argument", "INVALID_TOTAL_ITEMS");
  }

  return parsed;
}

function optionalNonNegativeInteger(value: unknown, fieldName: string): number | null {
  if (value === undefined || value === null) {
    return null;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new HttpsError("invalid-argument", `${fieldName} must be a non-negative integer`);
  }

  return parsed;
}

function optionalPercentage(value: unknown, fieldName: string): number | null {
  if (value === undefined || value === null) {
    return null;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 100) {
    throw new HttpsError("invalid-argument", `${fieldName} must be between 0 and 100`);
  }

  return Math.round(parsed);
}

function calculatePercent(numerator: number, denominator: number): number | null {
  if (denominator <= 0) {
    return null;
  }

  return Math.round((numerator / denominator) * 100);
}

function calculateCappedPercent(numerator: number, denominator: number): number | null {
  const percent = calculatePercent(numerator, denominator);
  if (percent === null) {
    return null;
  }

  return Math.max(0, Math.min(100, percent));
}

function timestampFromIso(value: unknown): admin.firestore.Timestamp | null {
  if (typeof value !== "string" || value.trim().length === 0) {
    return null;
  }

  const trimmed = value.trim();
  const hasTimeZone = /(?:z|[+-]\d{2}:?\d{2})$/i.test(trimmed);
  const parsed = hasTimeZone ?
    new Date(trimmed) :
    new Date(new Date(`${trimmed}Z`).getTime() - kstOffsetMs);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError("invalid-argument", "completedAt must be an ISO timestamp");
  }

  return admin.firestore.Timestamp.fromDate(parsed);
}

function secondsBetween(
  startedAt: unknown,
  completedAt: admin.firestore.Timestamp,
): number {
  if (!(startedAt instanceof admin.firestore.Timestamp)) {
    return 0;
  }

  const seconds = Math.round(
    (completedAt.toMillis() - startedAt.toMillis()) / 1000,
  );
  return Math.max(0, seconds);
}

function timestampToIso(value: unknown): string {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }

  if (typeof value === "string") {
    return value;
  }

  return "";
}

function safeNumber(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function nullableSafeNumber(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function timestampMillis(value: unknown): number {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }

  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  return 0;
}

function isFirestoreIndexNotReady(error: unknown): boolean {
  if (error === null || typeof error !== "object") {
    return false;
  }
  const candidate = error as {code?: unknown; details?: unknown; message?: unknown};
  const code = candidate.code;
  const details = `${candidate.details ?? ""} ${candidate.message ?? ""}`;
  return code === 9 &&
    details.includes("index") &&
    details.includes("not ready");
}

const kstOffsetMs = 9 * 60 * 60 * 1000;

function formatUtcDateKey(value: Date): string {
  const year = value.getUTCFullYear().toString().padStart(4, "0");
  const month = (value.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = value.getUTCDate().toString().padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function kstCalendarDate(value: admin.firestore.Timestamp): Date {
  return new Date(value.toMillis() + kstOffsetMs);
}

function dateKeyFromTimestamp(value: admin.firestore.Timestamp): string {
  return formatUtcDateKey(kstCalendarDate(value));
}

function formatKstDateTime(value: Date | admin.firestore.Timestamp): string {
  const date = value instanceof admin.firestore.Timestamp ? value.toDate() : value;
  const kst = new Date(date.getTime() + kstOffsetMs);
  const year = kst.getUTCFullYear().toString().padStart(4, "0");
  const month = (kst.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = kst.getUTCDate().toString().padStart(2, "0");
  const hour = kst.getUTCHours().toString().padStart(2, "0");
  const minute = kst.getUTCMinutes().toString().padStart(2, "0");
  const second = kst.getUTCSeconds().toString().padStart(2, "0");
  return `${year}-${month}-${day} ${hour}:${minute}:${second} KST`;
}

async function activeSimilarityEvent(): Promise<{eventId: string; data: Record<string, unknown>} | null> {
  const snap = await db.collection("similarity_events")
    .where("status", "==", "active")
    .limit(1)
    .get();
  if (snap.empty) {
    return null;
  }
  const doc = snap.docs[0];
  return {eventId: doc.id, data: doc.data() as Record<string, unknown>};
}

async function similarityEventDashboard(eventId?: string) {
  let eventDoc: admin.firestore.QueryDocumentSnapshot | admin.firestore.DocumentSnapshot | null = null;
  if (eventId && eventId.length > 0) {
    const doc = await db.doc(`similarity_events/${eventId}`).get();
    eventDoc = doc.exists ? doc : null;
  } else {
    const activeSnap = await db.collection("similarity_events")
      .where("status", "==", "active")
      .limit(1)
      .get();
    if (!activeSnap.empty) {
      eventDoc = activeSnap.docs[0];
    } else {
      const latestSnap = await db.collection("similarity_events")
        .orderBy("startedAt", "desc")
        .limit(1)
        .get();
      eventDoc = latestSnap.empty ? null : latestSnap.docs[0];
    }
  }

  if (!eventDoc || !eventDoc.exists) {
    return {
      event: null,
      totalLearners: 0,
      totalAttempts: 0,
      rankings: [],
    };
  }

  const event = eventDoc.data() as Record<string, unknown>;
  let resultsSnap;
  let receptionSnap;
  try {
    resultsSnap = await db.collectionGroup("items")
      .where("similarityEventId", "==", eventDoc.id)
      .get();
    receptionSnap = await db.collectionGroup("items")
      .where("similarityEventReceptionId", "==", eventDoc.id)
      .get();
  } catch (error) {
    if (isFirestoreIndexNotReady(error)) {
      console.warn("similarityEventDashboard index not ready", {eventId: eventDoc.id, error});
      return {
        event: {
          eventId: eventDoc.id,
          status: (event.status ?? "").toString(),
          contentSetId: (event.contentSetId ?? "").toString(),
          itemId: (event.itemId ?? "").toString(),
          expectedText: (event.expectedText ?? "").toString(),
          startedAt: timestampToIso(event.startedAt),
          endedAt: timestampToIso(event.endedAt),
        },
        totalLearners: 0,
        totalAttempts: 0,
        rankings: [],
        averageTotalLearners: 0,
        averageTotalAttempts: 0,
        averageRankings: [],
        indexPending: true,
      };
    }
    throw error;
  }
  const profileIds = new Set<string>();
  const bestByUser = new Map<string, Record<string, unknown>>();
  const averageByUser = new Map<string, {sum: number; count: number; latestEvaluatedAt: string}>();

  for (const doc of resultsSnap.docs) {
    const data = doc.data() as Record<string, unknown>;
    const userId = (data.userId ?? "").toString();
    const score = nullableSafeNumber(data.similarityScore);
    if (userId.length === 0 || score === null) {
      continue;
    }
    profileIds.add(userId);
    const prev = bestByUser.get(userId);
    const prevScore = nullableSafeNumber(prev?.similarityScore);
    const prevTime = timestampMillis(prev?.evaluatedAt);
    const nextTime = timestampMillis(data.evaluatedAt);
    if (
      prev === undefined ||
      score > (prevScore ?? -1) ||
      (score === prevScore && nextTime > prevTime)
    ) {
      bestByUser.set(userId, data);
    }
  }

  for (const doc of receptionSnap.docs) {
    const data = doc.data() as Record<string, unknown>;
    const userId = (data.userId ?? "").toString();
    const score = nullableSafeNumber(data.similarityScore);
    if (userId.length === 0 || score === null) {
      continue;
    }
    profileIds.add(userId);
    const evaluatedAt = timestampToIso(data.evaluatedAt);
    const prev = averageByUser.get(userId) ?? {sum: 0, count: 0, latestEvaluatedAt: ""};
    averageByUser.set(userId, {
      sum: prev.sum + Math.max(0, Math.min(100, score)),
      count: prev.count + 1,
      latestEvaluatedAt: evaluatedAt.localeCompare(prev.latestEvaluatedAt) > 0 ? evaluatedAt : prev.latestEvaluatedAt,
    });
  }

  const profiles = await Promise.all(
    [...profileIds].map(async (userId) => {
      const snap = await db.doc(`user_profiles/${userId}`).get();
      return [userId, snap.data() ?? {}] as const;
    }),
  );
  const profileByUserId = new Map(profiles);

  const profileName = (profile: Record<string, unknown>) => (
    profile.learnerName ??
    profile.displayName ??
    profile.name ??
    "-"
  ).toString();
  const profilePhone = (profile: Record<string, unknown>) => (
    profile.learnerPhone ??
    profile.phoneNumber ??
    profile.phone ??
    "-"
  ).toString();

  const rankings = [...bestByUser.entries()].map(([userId, data]) => {
    const profile = profileByUserId.get(userId) ?? {};
    return {
      userId,
      learnerEmail: normalizeEmail(profile.email),
      learnerName: profileName(profile),
      learnerPhone: profilePhone(profile),
      similarityScore: Math.max(0, Math.min(100, Math.round(safeNumber(data.similarityScore)))),
      passed: data.passed === true,
      transcript: (data.transcript ?? "").toString(),
      mode: (data.mode ?? "").toString(),
      sessionId: (data.sessionId ?? "").toString(),
      evaluatedAt: timestampToIso(data.evaluatedAt),
      onDeviceFallback: data.onDeviceFallback === true,
    };
  }).sort((a, b) =>
    b.similarityScore - a.similarityScore ||
    b.evaluatedAt.localeCompare(a.evaluatedAt) ||
    a.learnerName.localeCompare(b.learnerName, "ko"),
  );

  const averageRankings = [...averageByUser.entries()].map(([userId, stats]) => {
    const profile = profileByUserId.get(userId) ?? {};
    return {
      userId,
      learnerName: profileName(profile),
      learnerPhone: profilePhone(profile),
      averageSimilarity: stats.count === 0 ? 0 : Math.round(stats.sum / stats.count),
      attemptCount: stats.count,
      latestEvaluatedAt: stats.latestEvaluatedAt,
    };
  }).sort((a, b) =>
    b.averageSimilarity - a.averageSimilarity ||
    b.attemptCount - a.attemptCount ||
    b.latestEvaluatedAt.localeCompare(a.latestEvaluatedAt) ||
    a.learnerName.localeCompare(b.learnerName, "ko"),
  );

  // Report-based ranking: collect averageSimilarity from each report submitted
  // during the event period, then average per learner.
  const eventStartedAt = event.startedAt instanceof admin.firestore.Timestamp
    ? event.startedAt
    : admin.firestore.Timestamp.fromMillis(0);
  const eventEndedAt = event.endedAt instanceof admin.firestore.Timestamp
    ? event.endedAt
    : admin.firestore.Timestamp.now();

  let reportSnap: admin.firestore.QuerySnapshot | null = null;
  try {
    reportSnap = await db.collectionGroup("report_history")
      .where("submittedAt", ">=", eventStartedAt)
      .where("submittedAt", "<=", eventEndedAt)
      .get();
  } catch (error) {
    if (isFirestoreIndexNotReady(error)) {
      console.warn("similarityEventDashboard report_history index not ready", {eventId: eventDoc.id, error});
    } else {
      throw error;
    }
  }

  const reportByUser = new Map<string, {sum: number; count: number; latestSubmittedAt: string}>();
  if (reportSnap) {
    for (const doc of reportSnap.docs) {
      const data = doc.data() as Record<string, unknown>;
      const userId = (data.userId ?? "").toString();
      const sim = nullableSafeNumber(data.averageSimilarity);
      if (userId.length === 0 || sim === null) continue;
      const submittedAt = timestampToIso(data.submittedAt);
      const prev = reportByUser.get(userId) ?? {sum: 0, count: 0, latestSubmittedAt: ""};
      reportByUser.set(userId, {
        sum: prev.sum + Math.max(0, Math.min(100, sim)),
        count: prev.count + 1,
        latestSubmittedAt: submittedAt.localeCompare(prev.latestSubmittedAt) > 0
          ? submittedAt : prev.latestSubmittedAt,
      });
    }
  }

  // Fetch profiles for any new userIds not already loaded
  const newReportUserIds = [...reportByUser.keys()].filter((uid) => !profileByUserId.has(uid));
  if (newReportUserIds.length > 0) {
    const extra = await Promise.all(
      newReportUserIds.map(async (uid) => {
        const snap = await db.doc(`user_profiles/${uid}`).get();
        return [uid, snap.data() ?? {}] as const;
      }),
    );
    for (const [uid, profile] of extra) {
      profileByUserId.set(uid, profile as Record<string, unknown>);
    }
  }

  const reportRankings = [...reportByUser.entries()].map(([userId, stats]) => {
    const profile = profileByUserId.get(userId) ?? {};
    return {
      userId,
      learnerName: profileName(profile),
      learnerPhone: profilePhone(profile),
      averageSimilarity: Math.round(stats.sum / stats.count),
      reportCount: stats.count,
      latestSubmittedAt: stats.latestSubmittedAt,
    };
  }).sort((a, b) =>
    b.averageSimilarity - a.averageSimilarity ||
    b.reportCount - a.reportCount ||
    b.latestSubmittedAt.localeCompare(a.latestSubmittedAt) ||
    a.learnerName.localeCompare(b.learnerName, "ko"),
  );

  return {
    event: {
      eventId: eventDoc.id,
      status: (event.status ?? "").toString(),
      contentSetId: (event.contentSetId ?? "").toString(),
      itemId: (event.itemId ?? "").toString(),
      expectedText: (event.expectedText ?? "").toString(),
      startedAt: timestampToIso(event.startedAt),
      endedAt: timestampToIso(event.endedAt),
    },
    totalLearners: rankings.length,
    totalAttempts: resultsSnap.size,
    rankings: rankings.slice(0, 5),
    averageTotalLearners: averageRankings.length,
    averageTotalAttempts: receptionSnap.size,
    averageRankings: averageRankings.slice(0, 5),
    reportTotalLearners: reportRankings.length,
    reportTotalReports: reportSnap ? reportSnap.size : 0,
    reportRankings: reportRankings.slice(0, 10),
  };
}

function monthKeyFromDateKey(dateKey: string): string {
  return dateKey.slice(0, 7);
}

function weekKeyFromTimestamp(value: admin.firestore.Timestamp): string {
  const kstDate = kstCalendarDate(value);
  const monday = new Date(Date.UTC(
    kstDate.getUTCFullYear(),
    kstDate.getUTCMonth(),
    kstDate.getUTCDate(),
  ));
  const daysSinceMonday = (monday.getUTCDay() + 6) % 7;
  monday.setUTCDate(monday.getUTCDate() - daysSinceMonday);

  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 6);

  return `${formatUtcDateKey(monday)}_${formatUtcDateKey(sunday)}`;
}

function safeFieldKey(value: unknown): string {
  const normalized = (value ?? "unknown").toString().replace(/[^A-Za-z0-9_-]/g, "_");
  return normalized.length > 0 ? normalized : "unknown";
}

function modeGroup(value: unknown): "learning" | "test" | "unknown" {
  const mode = typeof value === "string" ? value : "";
  if (mode.endsWith("_learning")) {
    return "learning";
  }
  if (mode.endsWith("_test")) {
    return "test";
  }
  return "unknown";
}

function managementScore({
  completionRate,
  accuracy,
  averageSimilarity,
  completedItems,
}: {
  completionRate: number | null;
  accuracy: number | null;
  averageSimilarity: number | null;
  completedItems: number;
}): number {
  const completion = completionRate ?? 0;
  const accuracyScore = accuracy ?? 0;
  const similarityScore = averageSimilarity ?? 0;
  const volumeScore = Math.min(100, completedItems);
  return Math.round(
    completion * 0.3 +
    accuracyScore * 0.3 +
    similarityScore * 0.25 +
    volumeScore * 0.15,
  );
}

function riskReason({
  sessions,
  completedItems,
  accuracy,
  averageSimilarity,
  latestCompletionRate,
}: {
  sessions: number;
  completedItems: number;
  accuracy: number | null;
  averageSimilarity: number | null;
  latestCompletionRate: number | null;
}): string {
  if (sessions <= 0) {
    return "학습 기록 없음";
  }
  if ((latestCompletionRate ?? 0) < 60) {
    return "최근 학습 진도 낮음";
  }
  if ((accuracy ?? 100) < 60) {
    return "정답률 낮음";
  }
  if (averageSimilarity !== null && averageSimilarity < 60) {
    return "말하기 유사도 낮음";
  }
  if (completedItems < 10) {
    return "학습량 부족";
  }
  return "정상";
}

function isSpeakingResultMode(value: unknown): boolean {
  return typeof value === "string" && isSpeakingEvalMode(value);
}

async function collectSessionReportStats(
  userId: string,
  sessionId: string,
): Promise<SessionReportStats> {
  const itemsSnap = await db
    .collection(`test_results/${userId}/attempts/${sessionId}/items`)
    .get();

  let choiceAttemptCount = 0;
  let choiceCorrectCount = 0;
  let speakingAttemptCount = 0;
  let speakingPassedCount = 0;
  let sttFailureCount = 0;
  const similarityScores: number[] = [];
  const completedItemIds = new Set<string>();

  for (const doc of itemsSnap.docs) {
    const data = doc.data() as Record<string, unknown>;
    const mode = data.mode;
    const itemId = typeof data.itemId === "string" ? data.itemId : "";
    if (itemId.length > 0) {
      completedItemIds.add(itemId);
    }
    if (mode === "choice") {
      choiceAttemptCount += 1;
      const score = Number(data.score ?? 0);
      if (score === 1) {
        choiceCorrectCount += 1;
      }
      continue;
    }

    if (!isSpeakingResultMode(mode)) {
      continue;
    }

    speakingAttemptCount += 1;
    if (data.passed === true) {
      speakingPassedCount += 1;
    }
    const similarity = Number(data.similarityScore);
    if (Number.isFinite(similarity)) {
      similarityScores.push(Math.max(0, Math.min(100, Math.round(similarity))));
    }
    if (typeof data.errorCode === "string" && data.errorCode.length > 0) {
      sttFailureCount += 1;
    }
  }

  const similarityTotal = similarityScores.reduce((sum, value) => sum + value, 0);

  return {
    choiceAttemptCount,
    choiceCorrectCount,
    choiceAccuracy: calculatePercent(choiceCorrectCount, choiceAttemptCount),
    speakingAttemptCount,
    speakingPassedCount,
    speakingPassRate: calculatePercent(speakingPassedCount, speakingAttemptCount),
    completedItemCount: completedItemIds.size,
    averageSimilarity: similarityScores.length > 0 ?
      Math.round(similarityTotal / similarityScores.length) :
      null,
    sttFailureCount,
  };
}

function normalizeEmail(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function normalizePhone(value: unknown): string {
  return typeof value === "string" ? value.replace(/[^0-9]/g, "") : "";
}

function maskEmail(email: string): string {
  const [local, domain] = email.split("@");
  if (!local || !domain) {
    return "";
  }

  const visibleLength = local.length <= 2 ? 1 : 2;
  const visible = local.slice(0, visibleLength);
  const hidden = "*".repeat(Math.max(2, local.length - visibleLength));
  return `${visible}${hidden}@${domain}`;
}

function shouldPreApproveUser(email: string): boolean {
  return preApprovedTestEmails.has(email);
}

function isDefaultAdminEmail(email: string): boolean {
  return defaultAdminApprovalEmail.length > 0 && email === defaultAdminApprovalEmail;
}

function defaultAdminProfileFields(email: string): Record<string, unknown> {
  if (!isDefaultAdminEmail(email)) {
    return {};
  }

  // The default admin is designated server-side via ADMIN_APPROVAL_EMAIL (an
  // operator-controlled trust anchor) and Firebase Auth guarantees email
  // uniqueness, so only one account can ever hold this address. This app signs
  // in with email/password and has no email-verification flow, so requiring a
  // verified email here would make the admin role permanently unreachable.
  return {
    displayName: defaultAdminLearnerName,
    name: defaultAdminLearnerName,
    learnerName: defaultAdminLearnerName,
    phoneNumber: defaultAdminLearnerPhone,
    phone: defaultAdminLearnerPhone,
    learnerPhone: defaultAdminLearnerPhone,
    phoneNormalized: normalizePhone(defaultAdminLearnerPhone),
    role: "admin",
    admin: true,
  };
}

async function requireAdminUser(
  authUid: string | undefined,
  authToken: unknown,
  adminUserId: string,
): Promise<void> {
  requireAuthenticatedUser(authUid, adminUserId);

  const profileSnap = await db.doc(`user_profiles/${adminUserId}`).get();
  const profile = profileSnap.data() ?? {};
  const email = normalizeEmail(profile.email);
  const tokenEmail = authTokenEmail(authToken);
  const role = typeof profile.role === "string" ? profile.role : "";
  const emailMatchesToken = email.length === 0 || tokenEmail === email;
  // The configured admin email (ADMIN_APPROVAL_EMAIL) is an operator-controlled
  // trust anchor; this app has no email-verification flow, so we trust the
  // server-side designation plus Firebase Auth's email uniqueness guarantee.
  const isConfiguredDefaultAdmin =
    isDefaultAdminEmail(email) && isDefaultAdminEmail(tokenEmail);

  if (((role === "admin" || profile.admin === true) && emailMatchesToken) || isConfiguredDefaultAdmin) {
    return;
  }

  throw new HttpsError("permission-denied", "ADMIN_REQUIRED");
}

function getAdminApprovalEmail(): string {
  return normalizeEmail(process.env.ADMIN_APPROVAL_EMAIL) || defaultAdminApprovalEmail;
}

function buildFirebaseUserConsoleUrl(userId: string): string {
  const projectId = process.env.GCLOUD_PROJECT ?? admin.app().options.projectId ?? "";
  if (projectId.length === 0) {
    return "";
  }

  return `https://console.firebase.google.com/project/${projectId}` +
    `/authentication/users?search=${encodeURIComponent(userId)}`;
}

interface PendingApprovalNotice {
  userId: string;
  email: string;
  deviceId: string;
  name: string;
  phone: string;
}

async function sendTelegramAdminMessage(text: string, context: Record<string, unknown>): Promise<void> {
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;

  if (!botToken || !chatId) {
    console.warn("Telegram admin message skipped: TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID not configured", context);
    return;
  }

  try {
    const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        chat_id: chatId,
        text,
        disable_web_page_preview: true,
      }),
    });
    if (!response.ok) {
      const detail = await response.text().catch(() => "");
      console.error("Telegram admin message failed", {...context, status: response.status, detail});
    }
  } catch (error) {
    console.error("Telegram admin message error", {...context, error});
  }
}

async function notifyAdminForPendingApproval({
  userId,
  email,
  deviceId,
  name,
  phone,
}: PendingApprovalNotice): Promise<void> {
  const consoleUrl = buildFirebaseUserConsoleUrl(userId);
  const text = [
    "🔔 신규 학습자 승인 요청",
    "",
    `이름: ${name.length > 0 ? name : "-"}`,
    `전화번호: ${phone.length > 0 ? phone : "-"}`,
    `이메일: ${email.length > 0 ? email : "-"}`,
    `사용자 ID: ${userId}`,
    `기기 ID: ${deviceId}`,
    "",
    "관리자 대시보드에서 승인하거나, Firebase Console에서 user_profiles/{uid} 의 status 를 approved 로 변경하세요.",
    consoleUrl.length > 0 ? consoleUrl : "",
  ].filter((line) => line.length > 0).join("\n");

  await sendTelegramAdminMessage(text, {channel: "pending_approval", userId});
}

async function sendAdminApprovalEmail({
  userId,
  email,
  deviceId,
}: PendingApprovalNotice): Promise<void> {
  const smtpHost = process.env.SMTP_HOST;
  const smtpPort = Number(process.env.SMTP_PORT ?? 587);
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const mailFrom = process.env.MAIL_FROM ?? smtpUser;
  const adminEmail = getAdminApprovalEmail();

  if (!smtpHost || !smtpUser || !smtpPass || !mailFrom) {
    console.warn("Admin approval email skipped: SMTP environment is not configured", {
      userId,
      email,
      adminEmail,
    });
    return;
  }

  const consoleUrl = buildFirebaseUserConsoleUrl(userId);
  const subject = "[미션 언어 학습] 신규 학습자 승인 요청";
  const text = [
    "신규 학습자가 승인 대기 상태로 등록되었습니다.",
    "",
    `이메일: ${email.length > 0 ? email : "-"}`,
    `사용자 ID: ${userId}`,
    `기기 ID: ${deviceId}`,
    "",
    "승인 방법:",
    "Firebase Console > Firestore Database > user_profiles/{uid} 문서에서",
    "status 값을 approved 로 변경하세요.",
    "",
    consoleUrl.length > 0 ? `Firebase 사용자 검색: ${consoleUrl}` : "",
  ].filter((line) => line.length > 0).join("\n");

  const htmlConsoleLink = consoleUrl.length > 0 ?
    `<p><a href="${consoleUrl}">Firebase 사용자 검색 열기</a></p>` :
    "";
  const html = `
    <p>신규 학습자가 승인 대기 상태로 등록되었습니다.</p>
    <ul>
      <li>이메일: ${email.length > 0 ? email : "-"}</li>
      <li>사용자 ID: ${userId}</li>
      <li>기기 ID: ${deviceId}</li>
    </ul>
    <p>Firebase Console &gt; Firestore Database &gt; user_profiles/{uid} 문서에서
    <strong>status</strong> 값을 <strong>approved</strong> 로 변경하세요.</p>
    ${htmlConsoleLink}
  `;

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: Number.isFinite(smtpPort) ? smtpPort : 587,
    secure: smtpPort === 465,
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  await transporter.sendMail({
    from: mailFrom,
    to: adminEmail,
    subject,
    text,
    html,
  });
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
  return value === "sentence_test_speaking" ||
    value === "flash_word_test_speaking" ||
    value === "flash_sentence_test_speaking";
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

async function resolveUserStatus(userId: string, email = "", emailVerified = false): Promise<UserStatus> {
  const profileRef = db.doc(`user_profiles/${userId}`);
  const profileSnap = await profileRef.get();
  const rawStatus = profileSnap.data()?.status;
  const normalizedEmail = normalizeEmail(email);
  // The operator-designated admin (ADMIN_APPROVAL_EMAIL) is auto-approved.
  const preApproved =
    shouldPreApproveUser(normalizedEmail) || isDefaultAdminEmail(normalizedEmail);

  if ((!profileSnap.exists || rawStatus === "pending_approval") && preApproved) {
    await profileRef.set(
      {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        email: normalizedEmail,
        status: "approved",
        approved: true,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvalSource: isDefaultAdminEmail(normalizedEmail) ?
          "default_admin" :
          "preapproved_test_account",
        ...defaultAdminProfileFields(normalizedEmail),
      },
      {merge: true},
    );
    return "approved";
  }

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

export const bootstrapUserSession = onCall<BootstrapUserSessionData>(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const deviceId = ensureString(request.data?.deviceId, "deviceId");
  requireAuthenticatedUser(request.auth?.uid, userId);
  const email = normalizeEmail(request.auth?.token.email);
  // The operator-designated admin (ADMIN_APPROVAL_EMAIL) is auto-approved.
  const preApproved = shouldPreApproveUser(email) || isDefaultAdminEmail(email);

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
  const storedProfile = profileSnap.data() ?? {};
  const hasStoredAdminRole = storedProfile.role === "admin" || storedProfile.admin === true;

  if (!profileSnap.exists) {
    userStatus = preApproved ? "approved" : "pending_approval";
    await userProfileRef.set(
      {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        email,
        status: userStatus,
        approved: userStatus === "approved",
        approvedAt: userStatus === "approved" ?
          admin.firestore.FieldValue.serverTimestamp() :
          null,
        approvalSource: userStatus === "approved" ? "preapproved_test_account" : "admin_required",
        deviceId,
        ...defaultAdminProfileFields(email),
      },
      {merge: true},
    );
  } else if (userStatus === "pending_approval" && preApproved) {
    userStatus = "approved";
    await userProfileRef.set(
      {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        email,
        status: userStatus,
        approved: true,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvalSource: "preapproved_test_account",
        deviceId,
        ...defaultAdminProfileFields(email),
      },
      {merge: true},
    );
  } else {
    await userProfileRef.set(
      {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        email,
        approved: userStatus === "approved",
        deviceId,
        ...defaultAdminProfileFields(email),
      },
      {merge: true},
    );
  }

  // Notify the admin once per learner the first time they land in pending state,
  // pulling name/phone from the profile (written during signup by updateLearnerProfile).
  if (userStatus === "pending_approval" && storedProfile.pendingApprovalNotifiedAt == null) {
    const learnerName = (
      storedProfile.learnerName ?? storedProfile.name ?? storedProfile.displayName ?? ""
    ).toString();
    const learnerPhone = (
      storedProfile.learnerPhone ?? storedProfile.phone ?? storedProfile.phoneNumber ?? ""
    ).toString();
    await notifyAdminForPendingApproval({
      userId,
      email,
      deviceId,
      name: learnerName,
      phone: learnerPhone,
    }).catch((error) => {
      console.error("Pending approval notify failed", {userId, email, error});
    });
    await userProfileRef.set(
      {pendingApprovalNotifiedAt: admin.firestore.FieldValue.serverTimestamp()},
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
    isAdmin:
      userStatus === "approved" &&
      (hasStoredAdminRole || isDefaultAdminEmail(email)),
    learningBlocked: reportGate.learningBlocked,
    reportGateStage: reportGate.reportGateStage,
    hasResume: !resumeSnap.empty,
    resumeSummary: resumeSnap.empty ? null : resumeSnap.docs[0].data(),
    activeContentSetId:
      (runtimeSnap.data()?.activeContentSetId as string | undefined) ?? defaultActiveContentSetId,
    adminContact: defaultAdminContact,
  };
});

export const startStudySession = onCall<StartStudySessionData>(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const contentSetId = ensureString(request.data?.contentSetId, "contentSetId");
  const category = ensureString(request.data?.category, "category");
  const level = ensureString(request.data?.level, "level");
  const mode = ensureString(request.data?.mode, "mode");
  const clientTotalItems = optionalPositiveInteger(request.data?.totalItems);

  try {
    requireAuthenticatedUser(request.auth?.uid, userId);
    const userStatus = await resolveUserStatus(
      userId,
      request.auth?.token.email,
      authTokenEmailVerified(request.auth?.token),
    );

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

    // Item count is authoritative from the bundled manifest; the client value is
    // only a fallback for content sets the server does not know about.
    const manifestTotalItems = getManifestModeTotal(contentSetId, mode);
    const resolvedTotalItems =
      manifestTotalItems ??
      clientTotalItems ??
      await resolveModeTotalItems(contentSetId, mode);
    const contentSource = manifestTotalItems !== null ?
      "server_manifest" :
      (clientTotalItems === null ? "server_content_set" : "client_local_content");

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
        totalItems: resolvedTotalItems,
        contentSource,
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
          currentTotalItems: resolvedTotalItems,
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
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    console.error("startStudySession failed", {
      userId,
      contentSetId,
      category,
      level,
      mode,
      totalItems: clientTotalItems,
      authUid: request.auth?.uid ?? null,
      error,
    });
    throw new HttpsError("internal", "START_STUDY_SESSION_FAILED");
  }
});

export const submitChoiceTestItem = onCall<SubmitChoiceTestItemData>(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  const itemId = ensureString(request.data?.itemId, "itemId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const selectedItemId = optionalString(request.data?.selectedItemId);
  const selectedIndex = Number(request.data?.selectedIndex ?? -1);
  const correctIndex = Number(request.data?.correctIndex ?? -1);
  const elapsedSeconds = Number(request.data?.elapsedSeconds ?? 0);
  const hasLegacyIndices =
    !Number.isNaN(selectedIndex) && !Number.isNaN(correctIndex);
  if (selectedItemId.length === 0 && !hasLegacyIndices) {
    throw new HttpsError("invalid-argument", "INVALID_CHOICE_PAYLOAD");
  }

  const sessionRef = db.doc(`study_sessions/${userId}/sessions/${sessionId}`);
  const attemptRef = db.doc(`test_results/${userId}/attempts/${sessionId}`);
  let score = 0;
  let gradingSource = "client_index";
  await db.runTransaction(async (transaction) => {
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      throw new HttpsError("not-found", "SESSION_NOT_FOUND");
    }

    const contentSetId = (sessionSnap.data()?.contentSetId ?? "").toString();
    // Authoritative grading: the correct option is the one whose item id equals
    // the question's item id. The client-supplied correctIndex is never trusted
    // when the manifest knows this item.
    const manifestItem = selectedItemId.length > 0 ?
      getManifestItem(contentSetId, itemId) :
      null;
    if (manifestItem !== null) {
      score = selectedItemId === itemId ? 1 : 0;
      gradingSource = "server_manifest";
    } else if (hasLegacyIndices) {
      score = selectedIndex === correctIndex ? 1 : 0;
      gradingSource = "client_index";
    } else {
      score = 0;
      gradingSource = "unknown_item";
    }

    transaction.set(
      attemptRef,
      {
        userId,
        sessionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    transaction.set(
      attemptRef.collection("items").doc(itemId),
      {
        userId,
        sessionId,
        itemId,
        mode: "choice",
        selectedItemId,
        selectedIndex,
        correctIndex,
        score,
        gradingSource,
        elapsedSeconds,
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  return {
    sessionId,
    itemId,
    score,
    correct: score === 1,
    gradingSource,
  };
});

export const evaluateSpeakingAttempt = onCall<EvaluateSpeakingAttemptData>(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  const itemId = ensureString(request.data?.itemId, "itemId");
  const clientExpectedText = optionalString(request.data?.expectedText);
  const audioPath = optionalString(request.data?.audioPath);
  const audioBase64 = optionalString(request.data?.audioBase64);
  requireAuthenticatedUser(request.auth?.uid, userId);

  const rawMode = ensureString(request.data?.mode, "mode");
  if (!isSpeakingEvalMode(rawMode)) {
    throw new HttpsError("invalid-argument", "INVALID_SPEAKING_MODE");
  }
  if (audioBase64.length === 0) {
    if (audioPath.length === 0) {
      throw new HttpsError("invalid-argument", "audioPath or audioBase64 is required");
    }
    assertOwnedAudioPath(audioPath, userId, sessionId);
  } else if (audioPath.length > 0) {
    assertOwnedAudioPath(audioPath, userId, sessionId);
  }

  const sessionSnap = await db.doc(`study_sessions/${userId}/sessions/${sessionId}`).get();
  if (!sessionSnap.exists) {
    throw new HttpsError("not-found", "SESSION_NOT_FOUND");
  }

  // Expected text is authoritative from the manifest; the client value is only a
  // fallback for content sets the server does not know about.
  const contentSetId = (sessionSnap.data()?.contentSetId ?? "").toString();
  const manifestItem = getManifestItem(contentSetId, itemId);
  const expectedText = manifestItem?.expectedText ?? clientExpectedText;
  if (expectedText.length === 0) {
    throw new HttpsError("invalid-argument", "EXPECTED_TEXT_UNAVAILABLE");
  }
  const expectedTextSource = manifestItem !== null ? "server_manifest" : "client";

  const mode = rawMode;
  const threshold = 70;
  const durationMs = Number(request.data?.durationMs ?? 0);

  let transcript = "";
  let similarityScore = 0;
  let passed = false;
  let errorCode: string | null = null;
  let message = "발음 평가를 완료했습니다.";

  try {
    let audioBuffer: Buffer;
    if (audioBase64.length > 0) {
      audioBuffer = Buffer.from(audioBase64, "base64");
    } else {
      const bucket = admin.storage().bucket();
      [audioBuffer] = await bucket.file(audioPath).download();
    }
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
  const activeEvent = await activeSimilarityEvent();
  const isEventTarget = activeEvent !== null &&
    (activeEvent.data.contentSetId ?? "").toString() === contentSetId &&
    (activeEvent.data.itemId ?? "").toString() === itemId &&
    (activeEvent.data.expectedText ?? "").toString() === expectedText;
  const similarityEventFields = activeEvent === null ? {} : {
    similarityEventReceptionId: activeEvent.eventId,
    similarityEventReceptionItemId: itemId,
    ...(isEventTarget ? {
      similarityEventId: activeEvent.eventId,
      similarityEventItemId: itemId,
    } : {}),
  };
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
      expectedTextSource,
      transcript,
      similarityScore,
      passed,
      threshold,
      audioPath,
      durationMs: Number.isFinite(durationMs) ? durationMs : 0,
      errorCode,
      evaluatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...similarityEventFields,
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
    audioPath,
  };
});

export const submitOnDeviceSpeakingFallback = onCall<SubmitOnDeviceSpeakingFallbackData>(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  const itemId = ensureString(request.data?.itemId, "itemId");
  const clientExpectedText = optionalString(request.data?.expectedText);
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

  // Expected text is authoritative from the manifest; the client value is only a
  // fallback for content sets the server does not know about.
  const contentSetId = (sessionSnap.data()?.contentSetId ?? "").toString();
  const manifestItem = getManifestItem(contentSetId, itemId);
  const expectedText = manifestItem?.expectedText ?? clientExpectedText;
  if (expectedText.length === 0) {
    throw new HttpsError("invalid-argument", "EXPECTED_TEXT_UNAVAILABLE");
  }
  const expectedTextSource = manifestItem !== null ? "server_manifest" : "client";

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
  const activeEvent = await activeSimilarityEvent();
  const isEventTarget = activeEvent !== null &&
    (activeEvent.data.contentSetId ?? "").toString() === contentSetId &&
    (activeEvent.data.itemId ?? "").toString() === itemId &&
    (activeEvent.data.expectedText ?? "").toString() === expectedText;
  const similarityEventFields = activeEvent === null ? {} : {
    similarityEventReceptionId: activeEvent.eventId,
    similarityEventReceptionItemId: itemId,
    ...(isEventTarget ? {
      similarityEventId: activeEvent.eventId,
      similarityEventItemId: itemId,
    } : {}),
  };
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
      expectedTextSource,
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
      ...similarityEventFields,
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

export const generateReportPreview = onCall<GenerateReportPreviewData>(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const [sessionSnap, profileSnap] = await Promise.all([
    db.doc(`study_sessions/${userId}/sessions/${sessionId}`).get(),
    db.doc(`user_profiles/${userId}`).get(),
  ]);
  if (!sessionSnap.exists) {
    throw new HttpsError("not-found", "SESSION_NOT_FOUND");
  }

  const sessionData = sessionSnap.data() ?? {};
  const profileData = profileSnap.data() ?? {};
  const token = (request.auth?.token ?? {}) as Record<string, unknown>;
  const learnerName = (
    profileData.displayName ??
    profileData.name ??
    profileData.learnerName ??
    token.name ??
    ""
  ).toString().trim();
  const learnerPhone = (
    profileData.phoneNumber ??
    profileData.phone ??
    token.phone_number ??
    ""
  ).toString().trim();
  const startedAt = sessionData.startedAt instanceof admin.firestore.Timestamp ?
    sessionData.startedAt.toDate().toISOString() : "";

  const preview = {
    sessionId,
    learnerName: learnerName.length > 0 ? learnerName : "-",
    learnerPhone: learnerPhone.length > 0 ? learnerPhone : "-",
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

export const completeReportSubmission = onCall<CompleteReportSubmissionData>(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  // Self-reported completion is accepted only for non-graded (learning) modes.
  // Graded metrics (attempted/correct/similarity) are computed server-side from
  // stored attempts and never read from the client.
  const completedItemsFromClient = optionalNonNegativeInteger(
    request.data?.completedItems,
    "completedItems",
  );
  const durationSecondsFromClient = optionalNonNegativeInteger(
    request.data?.durationSeconds,
    "durationSeconds",
  );

  const reportId = `${sessionId}-${Date.now()}`;
  const sessionRef = db.doc(`study_sessions/${userId}/sessions/${sessionId}`);
  const profileRef = db.doc(`user_profiles/${userId}`);
  const summaryRef = db.doc(`user_learning_summary/${userId}`);

  const [sessionSnap, profileSnap, summarySnap, stats] = await Promise.all([
    sessionRef.get(),
    profileRef.get(),
    summaryRef.get(),
    collectSessionReportStats(userId, sessionId),
  ]);

  if (!sessionSnap.exists) {
    throw new HttpsError("not-found", "SESSION_NOT_FOUND");
  }

  const sessionData = sessionSnap.data() ?? {};
  const profileData = profileSnap.data() ?? {};
  const summaryData = summarySnap.data() ?? {};
  const token = (request.auth?.token ?? {}) as Record<string, unknown>;
  const learnerEmail = normalizeEmail(
    profileData.email ?? token.email ?? request.auth?.token.email ?? "",
  );
  const learnerName = (
    profileData.displayName ??
    profileData.name ??
    profileData.learnerName ??
    token.name ??
    ""
  ).toString().trim();
  const learnerPhone = (
    profileData.phoneNumber ??
    profileData.phone ??
    token.phone_number ??
    ""
  ).toString().trim();

  const sessionTotalItems = optionalNonNegativeInteger(sessionData.totalItems, "session.totalItems") ?? 0;
  const contentSetId = (sessionData.contentSetId ?? "").toString();
  const category = (sessionData.category ?? "").toString();
  const level = (sessionData.level ?? "").toString();
  const mode = (sessionData.mode ?? "").toString();
  // The session's totalItems is fixed at startStudySession time. If the
  // content catalog grows while a session is in progress (or resumed later),
  // a learner who legitimately completes every current item would otherwise
  // be rejected for exceeding a now-stale count. Accept the larger of the
  // two — the session's recorded total, or the live manifest total — so
  // genuine catalog growth never blocks submission, while a fabricated count
  // still gets rejected against the real manifest size.
  const manifestTotalItems = getManifestModeTotal(contentSetId, mode);
  const totalItems = Math.max(sessionTotalItems, manifestTotalItems ?? 0);
  // Assessment applicability and graded counts are server-authoritative.
  const assessmentApplicable = modeGroup(mode) === "test";
  const serverAttemptedAnswers = stats.choiceAttemptCount + stats.speakingAttemptCount;
  const serverCorrectAnswers = stats.choiceCorrectCount + stats.speakingPassedCount;

  // Test modes report completion from server-recorded attempts; learning modes
  // have no gradable attempts, so the self-reported completion count is accepted.
  // Completion is measured per distinct content item, not per recorded attempt
  // document — modes like sentence_test record two attempt docs per item (one
  // "choice", one "*_speaking" stage), so summing choice+speaking attempt
  // counts double-counts completion against totalItems (sized per item).
  const completedItemsRaw = assessmentApplicable ?
    (stats.completedItemCount > 0 ? stats.completedItemCount : (completedItemsFromClient ?? 0)) :
    (completedItemsFromClient ?? totalItems);
  if (totalItems > 0 && completedItemsRaw > totalItems) {
    throw new HttpsError("invalid-argument", "COMPLETED_ITEMS_EXCEEDS_TOTAL_ITEMS");
  }
  const completedItems = totalItems > 0 ?
    Math.min(completedItemsRaw, totalItems) :
    completedItemsRaw;
  const completionRate = calculatePercent(completedItems, totalItems);
  // Use one server-side timestamp for both completion and submission bookkeeping.
  // Older clients sent local ISO strings without a timezone, which could be
  // parsed as UTC and shift KST report dates by +9 hours.
  const reportRecordedAt = admin.firestore.Timestamp.now();
  const completedAt = reportRecordedAt;
  const durationSeconds = durationSecondsFromClient ??
    secondsBetween(sessionData.startedAt, completedAt);
  if (durationSeconds > 24 * 60 * 60) {
    throw new HttpsError("invalid-argument", "DURATION_SECONDS_OUT_OF_RANGE");
  }
  const submittedAt = reportRecordedAt;
  const startedAt = sessionData.startedAt instanceof admin.firestore.Timestamp ?
    sessionData.startedAt :
    null;
  const attemptedAnswers = assessmentApplicable ? serverAttemptedAnswers : 0;
  const correctAnswers = assessmentApplicable ? serverCorrectAnswers : 0;
  const averageSimilarity = assessmentApplicable ? stats.averageSimilarity : null;
  const accuracy = assessmentApplicable ?
    calculatePercent(correctAnswers, attemptedAnswers) :
    null;
  const previousAccuracy = optionalPercentage(summaryData.latestAccuracy, "summary.latestAccuracy");
  const previousAverageSimilarity = optionalPercentage(
    summaryData.latestAverageSimilarity,
    "summary.latestAverageSimilarity",
  );
  const accuracyDelta = previousAccuracy === null || accuracy === null ?
    null :
    accuracy - previousAccuracy;
  const similarityDelta =
    previousAverageSimilarity === null || averageSimilarity === null ?
      null :
      averageSimilarity - previousAverageSimilarity;
  const dateKey = dateKeyFromTimestamp(completedAt);
  const weekKey = weekKeyFromTimestamp(completedAt);
  const monthKey = monthKeyFromDateKey(dateKey);
  const durationMinutes = Math.round(durationSeconds / 60);
  const learningCompleted = completionRate === null ?
    completedItems > 0 :
    completionRate >= 100;
  const answerRate = assessmentApplicable ?
    calculateCappedPercent(attemptedAnswers, totalItems) :
    null;
  const missedAnswers = assessmentApplicable ?
    Math.max(0, attemptedAnswers - correctAnswers) :
    0;
  const hasTestResult = assessmentApplicable && attemptedAnswers > 0;
  const hasSpeakingResult = assessmentApplicable && averageSimilarity !== null;
  const reportManagementScore = managementScore({
    completionRate,
    accuracy,
    averageSimilarity,
    completedItems,
  });

  const previousSessions = safeNumber(summaryData.cumulativeSessions);
  const previousCompletedItems = safeNumber(summaryData.cumulativeCompletedItems);
  const previousPossibleItems = safeNumber(summaryData.cumulativePossibleItems);
  const previousDurationSeconds = safeNumber(summaryData.cumulativeDurationSeconds);
  const previousAttemptedAnswers = safeNumber(summaryData.cumulativeAttemptedAnswers);
  const previousCorrectAnswers = safeNumber(summaryData.cumulativeCorrectAnswers);
  const previousSpeakingAttempts = safeNumber(summaryData.cumulativeSpeakingAttempts);
  const previousSpeakingPassed = safeNumber(summaryData.cumulativeSpeakingPassed);
  const previousSimilaritySum = safeNumber(summaryData.cumulativeSimilarityScoreSum);
  const previousSimilarityCount = safeNumber(summaryData.cumulativeSimilaritySessionCount);
  const nextSessions = previousSessions + 1;
  const nextCompletedItems = previousCompletedItems + completedItems;
  const nextPossibleItems = previousPossibleItems + totalItems;
  const nextDurationSeconds = previousDurationSeconds + durationSeconds;
  const nextAttemptedAnswers = previousAttemptedAnswers + attemptedAnswers;
  const nextCorrectAnswers = previousCorrectAnswers + correctAnswers;
  const nextSpeakingAttempts = previousSpeakingAttempts + stats.speakingAttemptCount;
  const nextSpeakingPassed = previousSpeakingPassed + stats.speakingPassedCount;
  const nextSimilaritySum = previousSimilaritySum + (averageSimilarity ?? 0);
  const nextSimilarityCount = previousSimilarityCount + (averageSimilarity === null ? 0 : 1);
  const cumulativeAccuracy = calculatePercent(nextCorrectAnswers, nextAttemptedAnswers);
  const cumulativeSpeakingPassRate = calculatePercent(nextSpeakingPassed, nextSpeakingAttempts);
  const cumulativeAverageSimilarity = nextSimilarityCount > 0 ?
    Math.round(nextSimilaritySum / nextSimilarityCount) :
    null;
  const cumulativeCompletionAverage = calculatePercent(nextCompletedItems, nextPossibleItems);

  await db.doc(`reports/${userId}/report_history/${reportId}`).set({
    reportId,
    userId,
    sessionId,
    learnerEmail,
    learnerName: learnerName.length > 0 ? learnerName : "-",
    learnerPhone: learnerPhone.length > 0 ? learnerPhone : "-",
    contentSetId,
    category,
    level,
    mode,
    modeGroup: modeGroup(mode),
    startedAt,
    completedAt,
    submittedAt,
    dateKey,
    weekKey,
    monthKey,
    durationSeconds,
    durationMinutes,
    learningCompleted,
    totalItems,
    completedItems,
    completionRate,
    assessmentApplicable,
    answerRate,
    attemptedAnswers,
    correctAnswers,
    missedAnswers,
    accuracy,
    hasTestResult,
    hasSpeakingResult,
    choiceAttemptCount: stats.choiceAttemptCount,
    choiceCorrectCount: stats.choiceCorrectCount,
    choiceAccuracy: stats.choiceAccuracy,
    speakingAttemptCount: stats.speakingAttemptCount,
    speakingPassedCount: stats.speakingPassedCount,
    speakingPassRate: stats.speakingPassRate,
    averageSimilarity,
    sttFailureCount: stats.sttFailureCount,
    previousAccuracy,
    accuracyDelta,
    previousAverageSimilarity,
    similarityDelta,
    managementScore: reportManagementScore,
    reportPurpose: "learning_management",
  });

  await sessionRef.set(
    {
      status: "completed",
      completedAt,
      durationSeconds,
      durationMinutes,
      completedItems,
      completionRate,
      attemptedAnswers,
      correctAnswers,
      accuracy,
      averageSimilarity,
      reportId,
      updatedAt: submittedAt,
    },
    {merge: true},
  );

  const summaryUpdate: Record<string, unknown> = {
    userId,
    learnerEmail,
    learnerName: learnerName.length > 0 ? learnerName : "-",
    learnerPhone: learnerPhone.length > 0 ? learnerPhone : "-",
    cumulativeSessions: nextSessions,
    cumulativeCompletedItems: nextCompletedItems,
    cumulativePossibleItems: nextPossibleItems,
    cumulativeDurationSeconds: nextDurationSeconds,
    cumulativeAttemptedAnswers: nextAttemptedAnswers,
    cumulativeCorrectAnswers: nextCorrectAnswers,
    cumulativeSpeakingAttempts: nextSpeakingAttempts,
    cumulativeSpeakingPassed: nextSpeakingPassed,
    cumulativeSimilarityScoreSum: nextSimilaritySum,
    cumulativeSimilaritySessionCount: nextSimilarityCount,
    cumulativeAccuracy,
    cumulativeSpeakingPassRate,
    cumulativeAverageSimilarity,
    cumulativeCompletionAverage,
    latestReportId: reportId,
    latestSessionId: sessionId,
    latestCompletionRate: completionRate,
    latestStartedAt: startedAt,
    latestCompletedAt: completedAt,
    latestSubmittedAt: submittedAt,
    latestDurationSeconds: durationSeconds,
    latestDateKey: dateKey,
    latestWeekKey: weekKey,
    latestMonthKey: monthKey,
    latestMode: mode,
    latestModeGroup: modeGroup(mode),
    latestLevel: level,
    latestCategory: category,
    latestContentSetId: contentSetId,
    managementScore: managementScore({
      completionRate,
      accuracy: cumulativeAccuracy ?? accuracy,
      averageSimilarity: cumulativeAverageSimilarity ?? averageSimilarity,
      completedItems: nextCompletedItems,
    }),
    updatedAt: submittedAt,
  };

  if (assessmentApplicable) {
    summaryUpdate.latestAccuracy = accuracy;
  }
  if (averageSimilarity !== null) {
    summaryUpdate.latestAverageSimilarity = averageSimilarity;
  }

  await summaryRef.set(summaryUpdate, {merge: true});

  const modeKey = safeFieldKey(mode);
  const modeGroupKey = safeFieldKey(modeGroup(mode));
  const categoryKey = safeFieldKey(category);
  const levelKey = safeFieldKey(level);
  await summaryRef.update({
    [`modeStats.${modeKey}.sessions`]: admin.firestore.FieldValue.increment(1),
    [`modeStats.${modeKey}.completedItems`]: admin.firestore.FieldValue.increment(completedItems),
    [`modeStats.${modeKey}.durationSeconds`]: admin.firestore.FieldValue.increment(durationSeconds),
    [`modeStats.${modeKey}.attemptedAnswers`]: admin.firestore.FieldValue.increment(attemptedAnswers),
    [`modeStats.${modeKey}.correctAnswers`]: admin.firestore.FieldValue.increment(correctAnswers),
    [`modeStats.${modeKey}.speakingAttempts`]: admin.firestore.FieldValue.increment(stats.speakingAttemptCount),
    [`modeStats.${modeKey}.speakingPassed`]: admin.firestore.FieldValue.increment(stats.speakingPassedCount),
    [`modeGroupStats.${modeGroupKey}.sessions`]: admin.firestore.FieldValue.increment(1),
    [`modeGroupStats.${modeGroupKey}.completedItems`]: admin.firestore.FieldValue.increment(completedItems),
    [`categoryStats.${categoryKey}.sessions`]: admin.firestore.FieldValue.increment(1),
    [`categoryStats.${categoryKey}.completedItems`]: admin.firestore.FieldValue.increment(completedItems),
    [`levelStats.${levelKey}.sessions`]: admin.firestore.FieldValue.increment(1),
    [`levelStats.${levelKey}.completedItems`]: admin.firestore.FieldValue.increment(completedItems),
    [`dailyStats.${dateKey}.sessions`]: admin.firestore.FieldValue.increment(1),
    [`dailyStats.${dateKey}.completedItems`]: admin.firestore.FieldValue.increment(completedItems),
    [`dailyStats.${dateKey}.durationSeconds`]: admin.firestore.FieldValue.increment(durationSeconds),
    [`weeklyStats.${weekKey}.sessions`]: admin.firestore.FieldValue.increment(1),
    [`weeklyStats.${weekKey}.completedItems`]: admin.firestore.FieldValue.increment(completedItems),
    [`weeklyStats.${weekKey}.durationSeconds`]: admin.firestore.FieldValue.increment(durationSeconds),
    [`monthlyStats.${monthKey}.sessions`]: admin.firestore.FieldValue.increment(1),
    [`monthlyStats.${monthKey}.completedItems`]: admin.firestore.FieldValue.increment(completedItems),
    [`monthlyStats.${monthKey}.durationSeconds`]: admin.firestore.FieldValue.increment(durationSeconds),
  });

  await db.doc(`user_report_state/${userId}`).set(
    {
      learningBlocked: false,
      reportGateStage: "none",
      lastReportId: reportId,
      lastReportSubmittedAt: submittedAt,
    },
    {merge: true},
  );

  const reportDeviceId = (profileData.deviceId ?? "").toString();
  const reportDateText = formatKstDateTime(completedAt);
  const reportNoticeText = [
    "📄 리포트 제출",
    "",
    `이름: ${learnerName.length > 0 ? learnerName : "-"}`,
    `전화번호: ${learnerPhone.length > 0 ? learnerPhone : "-"}`,
    `이메일: ${learnerEmail.length > 0 ? learnerEmail : "-"}`,
    `사용자 ID: ${userId}`,
    `기기 ID: ${reportDeviceId.length > 0 ? reportDeviceId : "-"}`,
    `리포트 날짜(한국시간): ${reportDateText}`,
    "",
    `학습: ${category || "-"} / ${level || "-"} / ${mode || "-"}`,
    `완료율: ${completionRate}% (${completedItems}/${totalItems})`,
    assessmentApplicable ? `정답률: ${accuracy}%` : "",
  ].filter((line) => line.length > 0).join("\n");
  await sendTelegramAdminMessage(reportNoticeText, {
    channel: "report_submission",
    userId,
    reportId,
  });

  return {
    reportId,
    sessionId,
    accepted: true,
    accuracy,
    completionRate,
    averageSimilarity,
  };
});

// Learner-facing history: a learner reads only their own records, but ranks are
// computed server-side because Firestore rules forbid reading other learners.
export const getLearnerHistory = onCall(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  const summaryRef = db.doc(`user_learning_summary/${userId}`);
  const reportsQuery = db
    .collection(`reports/${userId}/report_history`)
    .orderBy("submittedAt", "desc")
    .limit(30);
  const allSummariesQuery = db.collection("user_learning_summary");

  const [summarySnap, reportsSnap, allSummariesSnap] = await Promise.all([
    summaryRef.get(),
    reportsQuery.get(),
    allSummariesQuery.get(),
  ]);

  const data = summarySnap.data() ?? {};
  const cumulativeDurationSeconds = safeNumber(data.cumulativeDurationSeconds);
  const myCompletedItems = safeNumber(data.cumulativeCompletedItems);
  const myAverageSimilarity = nullableSafeNumber(data.cumulativeAverageSimilarity);

  const summary = {
    sessions: safeNumber(data.cumulativeSessions),
    completedItems: myCompletedItems,
    possibleItems: safeNumber(data.cumulativePossibleItems),
    durationMinutes: Math.round(cumulativeDurationSeconds / 60),
    accuracy: nullableSafeNumber(data.cumulativeAccuracy),
    averageSimilarity: myAverageSimilarity,
    completionAverage: nullableSafeNumber(data.cumulativeCompletionAverage),
    speakingPassRate: nullableSafeNumber(data.cumulativeSpeakingPassRate),
    latestAccuracy: nullableSafeNumber(data.latestAccuracy),
    latestAverageSimilarity: nullableSafeNumber(data.latestAverageSimilarity),
  };

  const reports = reportsSnap.docs.map((doc) => {
    const r = doc.data() as Record<string, unknown>;
    return {
      reportId: (r.reportId ?? doc.id).toString(),
      submittedAt: timestampToIso(r.submittedAt),
      dateKey: (r.dateKey ?? "").toString(),
      category: (r.category ?? "").toString(),
      level: (r.level ?? "").toString(),
      mode: (r.mode ?? "").toString(),
      modeGroup: (r.modeGroup ?? "").toString(),
      totalItems: safeNumber(r.totalItems),
      completedItems: safeNumber(r.completedItems),
      completionRate: nullableSafeNumber(r.completionRate),
      accuracy: nullableSafeNumber(r.accuracy),
      averageSimilarity: nullableSafeNumber(r.averageSimilarity),
      durationMinutes: safeNumber(r.durationMinutes),
      speakingAttemptCount: safeNumber(r.speakingAttemptCount),
      speakingPassedCount: safeNumber(r.speakingPassedCount),
      speakingPassRate: nullableSafeNumber(r.speakingPassRate),
      sttFailureCount: safeNumber(r.sttFailureCount),
    };
  });

  // Speaking-focused subset (reports that actually had a speaking attempt).
  const speaking = reports
    .filter((r) => r.speakingAttemptCount > 0)
    .map((r) => ({
      reportId: r.reportId,
      submittedAt: r.submittedAt,
      dateKey: r.dateKey,
      category: r.category,
      level: r.level,
      attemptCount: r.speakingAttemptCount,
      passedCount: r.speakingPassedCount,
      passRate: r.speakingPassRate,
      averageSimilarity: r.averageSimilarity,
      sttFailureCount: r.sttFailureCount,
    }));

  const dailyStats = (data.dailyStats ?? {}) as Record<string, Record<string, unknown>>;
  const dailyTrend = Object.entries(dailyStats)
    .map(([dateKey, value]) => ({
      dateKey,
      sessions: safeNumber(value?.sessions),
      completedItems: safeNumber(value?.completedItems),
      durationMinutes: Math.round(safeNumber(value?.durationSeconds) / 60),
    }))
    .sort((a, b) => b.dateKey.localeCompare(a.dateKey))
    .slice(0, 14);

  const weeklyStats = (data.weeklyStats ?? {}) as Record<string, Record<string, unknown>>;
  const weeklyTrend = Object.entries(weeklyStats)
    .map(([weekKey, value]) => ({
      weekKey,
      sessions: safeNumber(value?.sessions),
      completedItems: safeNumber(value?.completedItems),
      durationMinutes: Math.round(safeNumber(value?.durationSeconds) / 60),
    }))
    .sort((a, b) => b.weekKey.localeCompare(a.weekKey))
    .slice(0, 8);

  const allLearners = allSummariesSnap.docs.map((doc) => ({
    userId: doc.id,
    completedItems: safeNumber(doc.data().cumulativeCompletedItems),
    similarity: nullableSafeNumber(doc.data().cumulativeAverageSimilarity),
  }));
  const totalLearners = allLearners.length;

  const sortedByVolume = [...allLearners].sort((a, b) => b.completedItems - a.completedItems);
  const volumeIndex = sortedByVolume.findIndex((l) => l.userId === userId);
  const learningVolumeRank = volumeIndex >= 0 ? volumeIndex + 1 : null;

  const withSimilarity = allLearners.filter((l) => l.similarity !== null);
  const sortedBySimilarity = [...withSimilarity].sort(
    (a, b) => (b.similarity ?? 0) - (a.similarity ?? 0),
  );
  const similarityIndex = sortedBySimilarity.findIndex((l) => l.userId === userId);
  const similarityRank = similarityIndex >= 0 ? similarityIndex + 1 : null;

  return {
    generatedAt: new Date().toISOString(),
    summary,
    reports,
    speaking,
    dailyTrend,
    weeklyTrend,
    ranking: {
      totalLearners,
      learningVolumeRank,
      myCompletedItems,
      similarityRank,
      similarityRankTotal: withSimilarity.length,
      myAverageSimilarity,
    },
  };
});

export const getAdminDashboard = onCall<AdminDashboardData>(callableOptions, async (request) => {
  const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
  await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

  const approvedProfilesQuery = db.collection("user_profiles").where("status", "==", "approved");
  const pendingProfilesQuery = db.collection("user_profiles").where("status", "==", "pending_approval");
  const reportsQuery = db.collectionGroup("report_history");
  const nowMs = Date.now();
  const sevenDaysAgoTimestamp = admin.firestore.Timestamp.fromMillis(nowMs - (7 * 24 * 60 * 60 * 1000));
  const thirtyDaysAgoTimestamp = admin.firestore.Timestamp.fromMillis(nowMs - (30 * 24 * 60 * 60 * 1000));
  const [
    pendingProfilesSnap,
    pendingCountSnap,
    approvedProfilesSnap,
    summariesSnap,
    recentReportsSnap,
    totalReportCountSnap,
    sevenDayReportCountSnap,
    thirtyDayReportCountSnap,
    sevenDayReportsSnap,
  ] = await Promise.all([
    pendingProfilesQuery.limit(50).get(),
    pendingProfilesQuery.count().get(),
    approvedProfilesQuery.get(),
    db.collection("user_learning_summary").get(),
    reportsQuery.orderBy("submittedAt", "desc").limit(30).get(),
    reportsQuery.count().get(),
    reportsQuery.where("submittedAt", ">=", sevenDaysAgoTimestamp).count().get(),
    reportsQuery.where("submittedAt", ">=", thirtyDaysAgoTimestamp).count().get(),
    reportsQuery.where("submittedAt", ">=", sevenDaysAgoTimestamp).get(),
  ]);

  const pendingApprovals = pendingProfilesSnap.docs.map((doc) => {
    const data = doc.data() as Record<string, unknown>;
    return {
      userId: doc.id,
      email: normalizeEmail(data.email),
      name: (data.displayName ?? data.name ?? data.learnerName ?? "-").toString(),
      phone: (data.phoneNumber ?? data.phone ?? "-").toString(),
      createdAt: timestampToIso(data.createdAt),
      deviceId: (data.deviceId ?? "-").toString(),
    };
  });

  const summariesByUserId = new Map(
    summariesSnap.docs.map((doc) => [doc.id, doc.data() as Record<string, unknown>]),
  );
  const profileDocsByUserId = new Map(
    approvedProfilesSnap.docs.map((doc) => [doc.id, doc.data() as Record<string, unknown>]),
  );
  const learnerIds = new Set<string>([
    ...profileDocsByUserId.keys(),
    ...summariesByUserId.keys(),
  ]);

  const learnerSummaries = [...learnerIds].map((userId) => {
    const data = summariesByUserId.get(userId) ?? {};
    const profile = profileDocsByUserId.get(userId) ?? {};
    const sessions = safeNumber(data.cumulativeSessions);
    const completedItems = safeNumber(data.cumulativeCompletedItems);
    const possibleItems = safeNumber(data.cumulativePossibleItems);
    const durationSeconds = safeNumber(data.cumulativeDurationSeconds);
    const attemptedAnswers = safeNumber(data.cumulativeAttemptedAnswers);
    const correctAnswers = safeNumber(data.cumulativeCorrectAnswers);
    const cumulativeAccuracy = data.cumulativeAccuracy === null || data.cumulativeAccuracy === undefined ?
      calculatePercent(correctAnswers, attemptedAnswers) :
      safeNumber(data.cumulativeAccuracy);
    const latestAccuracy = data.latestAccuracy === null || data.latestAccuracy === undefined ?
      null :
      safeNumber(data.latestAccuracy);
    const averageSimilarity =
      data.cumulativeAverageSimilarity === null || data.cumulativeAverageSimilarity === undefined ?
        null :
        safeNumber(data.cumulativeAverageSimilarity);
    const latestAverageSimilarity =
      data.latestAverageSimilarity === null || data.latestAverageSimilarity === undefined ?
        null :
        safeNumber(data.latestAverageSimilarity);
    const latestCompletionRate = nullableSafeNumber(data.latestCompletionRate);
    const score = nullableSafeNumber(data.managementScore) ?? managementScore({
      completionRate: latestCompletionRate,
      accuracy: cumulativeAccuracy,
      averageSimilarity,
      completedItems,
    });
    return {
      userId,
      email: normalizeEmail(data.learnerEmail ?? profile.email),
      name: (data.learnerName ?? profile.displayName ?? profile.name ?? profile.learnerName ?? "-").toString(),
      phone: (data.learnerPhone ?? profile.phoneNumber ?? profile.phone ?? "-").toString(),
      sessions,
      completedItems,
      possibleItems,
      durationSeconds,
      durationMinutes: Math.round(durationSeconds / 60),
      attemptedAnswers,
      correctAnswers,
      accuracy: cumulativeAccuracy,
      latestAccuracy,
      averageSimilarity,
      latestAverageSimilarity,
      cumulativeCompletionAverage: nullableSafeNumber(data.cumulativeCompletionAverage),
      cumulativeSpeakingPassRate: nullableSafeNumber(data.cumulativeSpeakingPassRate),
      latestCompletionRate,
      latestMode: (data.latestMode ?? "").toString(),
      latestModeGroup: (data.latestModeGroup ?? "").toString(),
      latestLevel: (data.latestLevel ?? "").toString(),
      latestCategory: (data.latestCategory ?? "").toString(),
      latestContentSetId: (data.latestContentSetId ?? "").toString(),
      latestReportId: (data.latestReportId ?? "").toString(),
      latestSessionId: (data.latestSessionId ?? "").toString(),
      latestStartedAt: timestampToIso(data.latestStartedAt),
      latestCompletedAt: timestampToIso(data.latestCompletedAt),
      latestDateKey: (data.latestDateKey ?? "").toString(),
      latestWeekKey: (data.latestWeekKey ?? "").toString(),
      latestMonthKey: (data.latestMonthKey ?? "").toString(),
      managementScore: score,
      riskReason: riskReason({
        sessions,
        completedItems,
        accuracy: cumulativeAccuracy,
        averageSimilarity,
        latestCompletionRate,
      }),
      updatedAt: timestampToIso(data.updatedAt),
    };
  }).sort((a, b) => b.managementScore - a.managementScore);

  const recentReports = recentReportsSnap.docs.map((doc) => {
    const data = doc.data() as Record<string, unknown>;
    return {
      reportId: (data.reportId ?? doc.id).toString(),
      userId: (data.userId ?? "").toString(),
      sessionId: (data.sessionId ?? "").toString(),
      learnerEmail: normalizeEmail(data.learnerEmail),
      learnerName: (data.learnerName ?? "-").toString(),
      mode: (data.mode ?? "").toString(),
      modeGroup: (data.modeGroup ?? "").toString(),
      category: (data.category ?? "").toString(),
      level: (data.level ?? "").toString(),
      contentSetId: (data.contentSetId ?? "").toString(),
      completedItems: safeNumber(data.completedItems),
      totalItems: safeNumber(data.totalItems),
      completionRate: data.completionRate === null || data.completionRate === undefined ?
        null :
        safeNumber(data.completionRate),
      attemptedAnswers: safeNumber(data.attemptedAnswers),
      correctAnswers: safeNumber(data.correctAnswers),
      missedAnswers: safeNumber(data.missedAnswers),
      accuracy: data.accuracy === null || data.accuracy === undefined ?
        null :
        safeNumber(data.accuracy),
      averageSimilarity: data.averageSimilarity === null ||
        data.averageSimilarity === undefined ?
        null :
        safeNumber(data.averageSimilarity),
      durationSeconds: safeNumber(data.durationSeconds),
      durationMinutes: safeNumber(data.durationMinutes),
      learningCompleted: data.learningCompleted === true,
      hasTestResult: data.hasTestResult === true,
      hasSpeakingResult: data.hasSpeakingResult === true,
      accuracyDelta: nullableSafeNumber(data.accuracyDelta),
      similarityDelta: nullableSafeNumber(data.similarityDelta),
      dateKey: (data.dateKey ?? "").toString(),
      submittedAt: timestampToIso(data.submittedAt),
    };
  }).sort((a, b) => b.submittedAt.localeCompare(a.submittedAt));

  const totalLearners = learnerSummaries.length;
  const totalSessions = learnerSummaries.reduce((sum, item) => sum + item.sessions, 0);
  const totalCompletedItems = learnerSummaries.reduce(
    (sum, item) => sum + item.completedItems,
    0,
  );
  const totalPossibleItems = learnerSummaries.reduce(
    (sum, item) => sum + item.possibleItems,
    0,
  );
  const totalDurationSeconds = learnerSummaries.reduce(
    (sum, item) => sum + item.durationSeconds,
    0,
  );
  const totalAttempted = learnerSummaries.reduce(
    (sum, item) => sum + item.attemptedAnswers,
    0,
  );
  const totalCorrect = learnerSummaries.reduce(
    (sum, item) => sum + item.correctAnswers,
    0,
  );
  const similarityValues = learnerSummaries
    .map((item) => item.averageSimilarity)
    .filter((value): value is number => typeof value === "number");
  const averageSimilarity = similarityValues.length === 0 ?
    null :
    Math.round(similarityValues.reduce((sum, value) => sum + value, 0) / similarityValues.length);
  const activeLearners = learnerSummaries.filter((item) => item.sessions > 0).length;
  const activeLearnersLast7Days = new Set(
    sevenDayReportsSnap.docs
      .map((doc) => ((doc.data() as Record<string, unknown>).userId ?? "").toString())
      .filter((value) => value.length > 0),
  ).size;
  const byManagementScore = [...learnerSummaries].sort((a, b) => b.managementScore - a.managementScore);
  const byRisk = [...learnerSummaries]
    .filter((item) => item.sessions > 0)
    .sort((a, b) => a.managementScore - b.managementScore);

  return {
    generatedAt: admin.firestore.Timestamp.now().toDate().toISOString(),
    summary: {
      totalLearners,
      activeLearners,
      activeLearnersLast7Days,
      totalSessions,
      totalCompletedItems,
      totalPossibleItems,
      totalDurationSeconds,
      totalDurationMinutes: Math.round(totalDurationSeconds / 60),
      averageCompletionRate: calculatePercent(totalCompletedItems, totalPossibleItems),
      averageAccuracy: calculatePercent(totalCorrect, totalAttempted),
      averageSimilarity,
      pendingApprovalCount: pendingCountSnap.data().count,
      recentReportCount: totalReportCountSnap.data().count,
      recentSevenDayReportCount: sevenDayReportCountSnap.data().count,
      recentThirtyDayReportCount: thirtyDayReportCountSnap.data().count,
    },
    pendingApprovals,
    learnerSummaries: learnerSummaries.slice(0, 200),
    topLearners: byManagementScore.slice(0, 5),
    needsAttentionLearners: byRisk.slice(0, 5),
    recentReports,
  };
});

export const startSimilarityEvent = onCall<StartSimilarityEventData>(callableOptions, async (request) => {
  const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
  await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

  const contentSetId = ensureString(request.data?.contentSetId, "contentSetId");
  const itemId = ensureString(request.data?.itemId, "itemId");
  const manifestItem = getManifestItem(contentSetId, itemId);
  if (manifestItem === null || manifestItem.type !== "sentence") {
    throw new HttpsError("invalid-argument", "SIMILARITY_EVENT_SENTENCE_NOT_FOUND");
  }

  const now = admin.firestore.Timestamp.now();
  const activeSnap = await db.collection("similarity_events")
    .where("status", "==", "active")
    .get();
  const batch = db.batch();
  for (const doc of activeSnap.docs) {
    batch.set(doc.ref, {
      status: "ended",
      endedAt: now,
      endedBy: adminUserId,
    }, {merge: true});
  }
  const eventRef = db.collection("similarity_events").doc();
  batch.set(eventRef, {
    status: "active",
    contentSetId,
    itemId,
    expectedText: manifestItem.expectedText,
    startedAt: now,
    startedBy: adminUserId,
    createdAt: now,
  });
  await batch.commit();

  return similarityEventDashboard(eventRef.id);
});

export const endSimilarityEvent = onCall<EndSimilarityEventData>(callableOptions, async (request) => {
  const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
  await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

  const eventId = ensureString(request.data?.eventId, "eventId");
  await db.doc(`similarity_events/${eventId}`).set({
    status: "ended",
    endedAt: admin.firestore.Timestamp.now(),
    endedBy: adminUserId,
  }, {merge: true});

  return similarityEventDashboard(eventId);
});

export const getSimilarityEventDashboard = onCall<GetSimilarityEventData>(callableOptions, async (request) => {
  const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
  await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);
  const eventId = optionalString(request.data?.eventId);
  return similarityEventDashboard(eventId.length > 0 ? eventId : undefined);
});

export const approveLearnerAccount = onCall<ApproveUserData>(callableOptions, async (request) => {
  const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
  const targetUserId = ensureString(request.data?.targetUserId, "targetUserId");
  await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

  if (adminUserId === targetUserId) {
    throw new HttpsError("invalid-argument", "CANNOT_APPROVE_SELF");
  }

  const targetProfileRef = db.doc(`user_profiles/${targetUserId}`);
  await db.runTransaction(async (transaction) => {
    const targetProfileSnap = await transaction.get(targetProfileRef);
    if (!targetProfileSnap.exists) {
      throw new HttpsError("not-found", "TARGET_PROFILE_NOT_FOUND");
    }

    const targetProfile = targetProfileSnap.data() ?? {};
    if (targetProfile.status !== "pending_approval") {
      throw new HttpsError("failed-precondition", "TARGET_PROFILE_NOT_PENDING_APPROVAL");
    }

    transaction.set(
      targetProfileRef,
      {
        status: "approved",
        approved: true,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: adminUserId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  return {
    approved: true,
    targetUserId,
  };
});

export const updateLearnerProfile = onCall<UpdateLearnerProfileData>(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const learnerName = ensureString(request.data?.learnerName, "learnerName");
  const learnerPhone = ensureString(request.data?.learnerPhone, "learnerPhone");
  const normalizedPhone = normalizePhone(learnerPhone);
  requireAuthenticatedUser(request.auth?.uid, userId);

  const email = normalizeEmail(request.auth?.token.email);
  const preApproved = shouldPreApproveUser(email);
  const profileRef = db.doc(`user_profiles/${userId}`);

  await db.runTransaction(async (transaction) => {
    const profileSnap = await transaction.get(profileRef);
    const profile = profileSnap.data() ?? {};
    const currentStatus = profile.status as UserStatus | undefined;
    const nextStatus = currentStatus ?? (preApproved ? "approved" : "pending_approval");
    const update: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      email,
      displayName: learnerName,
      name: learnerName,
      learnerName,
      phoneNumber: learnerPhone,
      phone: learnerPhone,
      learnerPhone,
      phoneNormalized: normalizedPhone,
      status: nextStatus,
      approved: nextStatus === "approved",
    };

    if (!profileSnap.exists) {
      update.createdAt = admin.firestore.FieldValue.serverTimestamp();
      update.approvalSource = preApproved ? "preapproved_test_account" : "admin_required";
      update.approvedAt = nextStatus === "approved" ?
        admin.firestore.FieldValue.serverTimestamp() :
        null;
    } else if (preApproved && currentStatus === "pending_approval") {
      update.status = "approved";
      update.approved = true;
      update.approvedAt = admin.firestore.FieldValue.serverTimestamp();
      update.approvalSource = "preapproved_test_account";
    }

    transaction.set(profileRef, update, {merge: true});
  });

  return {
    saved: true,
    userId,
    learnerName,
    learnerPhone,
  };
});

export const findLearnerEmail = onCall<FindLearnerEmailData>(callableOptions, async (request) => {
  const learnerName = ensureString(request.data?.learnerName, "learnerName");
  const learnerPhone = ensureString(request.data?.learnerPhone, "learnerPhone");
  const normalizedPhone = normalizePhone(learnerPhone);
  if (normalizedPhone.length < 8) {
    throw new HttpsError("invalid-argument", "INVALID_PHONE");
  }

  const matchesByPhone = await db
    .collection("user_profiles")
    .where("phoneNormalized", "==", normalizedPhone)
    .limit(10)
    .get();

  const profileDocs = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const doc of matchesByPhone.docs) {
    profileDocs.set(doc.id, doc);
  }

  // Older profiles may not have phoneNormalized yet. Fall back to name-based
  // lookups and then compare normalized phone fields in memory.
  if (profileDocs.size === 0) {
    const nameFields = ["learnerName", "name", "displayName"];
    const fallbackSnaps = await Promise.all(
      nameFields.map((field) =>
        db.collection("user_profiles").where(field, "==", learnerName).limit(20).get(),
      ),
    );
    for (const snap of fallbackSnaps) {
      for (const doc of snap.docs) {
        profileDocs.set(doc.id, doc);
      }
    }
  }

  const emails = [...profileDocs.values()]
    .map((doc) => doc.data() as Record<string, unknown>)
    .filter((profile) => {
      const names = [profile.learnerName, profile.name, profile.displayName]
        .map((value) => (value ?? "").toString().trim());
      const phones = [
        profile.phoneNormalized,
        profile.learnerPhone,
        profile.phone,
        profile.phoneNumber,
      ].map(normalizePhone);
      return names.includes(learnerName) && phones.includes(normalizedPhone);
    })
    .map((profile) => normalizeEmail(profile.email))
    .filter((email) => email.length > 0);

  const uniqueEmails = [...new Set(emails)];
  if (uniqueEmails.length === 1) {
    return {
      found: true,
      maskedEmail: maskEmail(uniqueEmails[0]),
    };
  }

  return {
    found: false,
    multiple: uniqueEmails.length > 1,
  };
});

export const saveResumeState = onCall<ResumeStateData>(callableOptions, async (request) => {
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

export const discardResumeState = onCall<DiscardResumeStateData>(callableOptions, async (request) => {
  const userId = ensureString(request.data?.userId, "userId");
  const sessionId = ensureString(request.data?.sessionId, "sessionId");
  requireAuthenticatedUser(request.auth?.uid, userId);

  await db.doc(`resume_states/${userId}/draft/${sessionId}`).delete();
  return {deleted: true, sessionId};
});

export const abandonStudySession = onCall<AbandonStudySessionData>(callableOptions, async (request) => {
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

export const checkWeeklyReportGate = onCall<{userId: string}>(callableOptions, async (request) => {
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

const dateKeyPattern = /^\d{4}-\d{2}-\d{2}$/;

function resolveDateKey(rawDateKey: unknown): string {
  if (typeof rawDateKey === "string" && rawDateKey.trim().length > 0) {
    const trimmed = rawDateKey.trim();
    if (!dateKeyPattern.test(trimmed)) {
      throw new HttpsError("invalid-argument", "INVALID_DATE_KEY");
    }
    return trimmed;
  }

  return dateKeyFromTimestamp(admin.firestore.Timestamp.now());
}

function ensureHttpUrl(value: unknown, fieldName: string): string {
  const raw = ensureString(value, fieldName);
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    throw new HttpsError("invalid-argument", "INVALID_URL");
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new HttpsError("invalid-argument", "INVALID_URL");
  }

  return raw;
}

export const getTodayLink = onCall<GetTodayLinkData>(callableOptions, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "AUTH_REQUIRED");
  }

  const dateKey = resolveDateKey(request.data?.dateKey);
  const snap = await db.doc(`daily_links/${dateKey}`).get();
  if (!snap.exists) {
    return {exists: false, dateKey, url: null, title: null};
  }

  const data = snap.data() ?? {};
  return {
    exists: true,
    dateKey,
    url: typeof data.url === "string" ? data.url : null,
    title: typeof data.title === "string" ? data.title : null,
  };
});

export const setTodayLink = onCall<SetTodayLinkData>(callableOptions, async (request) => {
  const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
  await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

  const dateKey = resolveDateKey(request.data?.dateKey);
  const url = ensureHttpUrl(request.data?.url, "url");
  const title = ensureString(request.data?.title, "title");

  await db.doc(`daily_links/${dateKey}`).set(
    {
      url,
      title,
      dateKey,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: adminUserId,
    },
    {merge: true},
  );

  return {saved: true, dateKey, url, title};
});

export const recordTodayLinkClick = onCall<RecordTodayLinkClickData>(
  callableOptions,
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "AUTH_REQUIRED");
    }

    const dateKey = resolveDateKey(request.data?.dateKey);
    await db.collection(`daily_links/${dateKey}/clickEvents`).add({
      userId,
      dateKey,
      clickedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {recorded: true, dateKey};
  },
);

export const getTodayLinkClicks = onCall<GetTodayLinkClicksData>(
  callableOptions,
  async (request) => {
    const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
    await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

    const dateKey = resolveDateKey(request.data?.dateKey);
    const eventsSnap = await db
      .collection(`daily_links/${dateKey}/clickEvents`)
      .orderBy("clickedAt", "asc")
      .get();

    const clickedAtByUserId = new Map<string, string[]>();
    for (const doc of eventsSnap.docs) {
      const data = doc.data();
      const userId = typeof data.userId === "string" ? data.userId : null;
      const clickedAt = data.clickedAt as admin.firestore.Timestamp | undefined;
      if (!userId || !clickedAt) {
        continue;
      }
      const list = clickedAtByUserId.get(userId) ?? [];
      list.push(clickedAt.toDate().toISOString());
      clickedAtByUserId.set(userId, list);
    }

    const learners = await Promise.all(
      Array.from(clickedAtByUserId.entries()).map(async ([userId, clickedAt]) => {
        const profileSnap = await db.doc(`user_profiles/${userId}`).get();
        const profile = profileSnap.data() ?? {};
        return {
          userId,
          name: (profile.displayName ?? profile.name ?? profile.learnerName ?? "-").toString(),
          email: normalizeEmail(profile.email),
          clickCount: clickedAt.length,
          clickedAt,
        };
      }),
    );
    learners.sort((a, b) => a.name.localeCompare(b.name, "ko"));

    return {
      dateKey,
      totalClicks: eventsSnap.size,
      totalLearners: learners.length,
      learners,
    };
  },
);

export const addLearnerRosterEntries = onCall<AddLearnerRosterEntriesData>(
  callableOptions,
  async (request) => {
    const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
    await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

    const rawEntries = Array.isArray(request.data?.entries) ? request.data.entries : [];
    if (rawEntries.length === 0) {
      throw new HttpsError("invalid-argument", "ENTRIES_REQUIRED");
    }

    const rosterCollection = db.collection("learner_roster");
    let added = 0;
    let updated = 0;

    for (const rawEntry of rawEntries) {
      const name = ensureString((rawEntry as {name?: unknown}).name, "name");
      const phoneNormalized = normalizePhone((rawEntry as {phone?: unknown}).phone);
      if (phoneNormalized.length < 8) {
        continue;
      }
      const phone = ensureString((rawEntry as {phone?: unknown}).phone, "phone");

      const existing = await rosterCollection
        .where("phoneNormalized", "==", phoneNormalized)
        .limit(1)
        .get();

      if (existing.empty) {
        await rosterCollection.add({
          name,
          phone,
          phoneNormalized,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: adminUserId,
        });
        added++;
      } else {
        await existing.docs[0].ref.set(
          {name, phone, phoneNormalized},
          {merge: true},
        );
        updated++;
      }
    }

    return {added, updated};
  },
);

export const getLearnerRoster = onCall<GetLearnerRosterData>(
  callableOptions,
  async (request) => {
    const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
    await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

    const [rosterSnap, profilesSnap] = await Promise.all([
      db.collection("learner_roster").get(),
      db.collection("user_profiles").get(),
    ]);

    const profilesByPhone = new Map<string, FirebaseFirestore.DocumentData>();
    for (const doc of profilesSnap.docs) {
      const data = doc.data();
      const phoneNormalized = normalizePhone(
        data.phoneNormalized ?? data.phone ?? data.phoneNumber,
      );
      if (phoneNormalized.length >= 8 && !profilesByPhone.has(phoneNormalized)) {
        profilesByPhone.set(phoneNormalized, data);
      }
    }

    const entries = rosterSnap.docs.map((doc) => {
      const data = doc.data();
      const phoneNormalized = (data.phoneNormalized ?? "").toString();
      const matchedProfile = profilesByPhone.get(phoneNormalized);
      const status = !matchedProfile
        ? "not_registered"
        : matchedProfile.status === "approved"
          ? "approved"
          : matchedProfile.status === "blocked"
            ? "blocked"
            : "pending_approval";
      return {
        rosterId: doc.id,
        name: (data.name ?? "-").toString(),
        phone: (data.phone ?? "-").toString(),
        status,
        matchedEmail: matchedProfile ? normalizeEmail(matchedProfile.email) : null,
      };
    });

    entries.sort((a, b) => a.name.localeCompare(b.name, "ko"));

    return {entries};
  },
);

export const deleteLearnerRosterEntry = onCall<DeleteLearnerRosterEntryData>(
  callableOptions,
  async (request) => {
    const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
    await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);
    const rosterId = ensureString(request.data?.rosterId, "rosterId");

    await db.doc(`learner_roster/${rosterId}`).delete();
    return {deleted: true};
  },
);

// ─── Daily Activity Report ──────────────────────────────────────────────────

interface DailyActivityLearner {
  uid: string;
  name: string;
  phone: string;
  durationSeconds: number;
  durationSource: "completed" | "proxy" | "none";
  sessionCount: number;
  totalItems: number;
  speakingItems: number;
  avgSimilarity: number | null;
}

interface DailyActivityReport {
  dateKey: string;
  generatedAt: admin.firestore.Timestamp;
  activeLearners: DailyActivityLearner[];
  inactiveLearnerNames: string[];
  totalApproved: number;
  activeCount: number;
}

async function computeDailyActivityReport(dateKey: string): Promise<DailyActivityReport> {
  // KST day boundaries in UTC
  const [dateYear, dateMon, dateDay] = dateKey.split("-").map(Number);
  const dayStartUtc = new Date(Date.UTC(dateYear, dateMon - 1, dateDay) - kstOffsetMs);
  const dayEndUtc = new Date(dayStartUtc.getTime() + 24 * 60 * 60 * 1000 - 1);
  const startTs = admin.firestore.Timestamp.fromDate(dayStartUtc);
  const endTs = admin.firestore.Timestamp.fromDate(dayEndUtc);

  // 1. Load all approved user profiles
  const profileSnaps = await db.collection("user_profiles").get();
  const approvedProfiles: Array<{uid: string; name: string; phone: string}> = [];
  for (const doc of profileSnaps.docs) {
    const d = doc.data();
    if (d.status === "approved") {
      approvedProfiles.push({
        uid: doc.id,
        name: (d.learnerName ?? d.displayName ?? d.name ?? "-").toString(),
        phone: (d.learnerPhone ?? d.phoneNumber ?? d.phone ?? "-").toString(),
      });
    }
  }

  // 2. Load user_learning_summary for completed-session aggregates
  const summarySnaps = await db.collection("user_learning_summary").get();
  const summaryByUid = new Map<string, {durationSeconds: number; sessions: number}>();
  for (const doc of summarySnaps.docs) {
    const d = doc.data();
    const daily = d.dailyStats?.[dateKey];
    if (daily) {
      summaryByUid.set(doc.id, {
        durationSeconds: Number(daily.durationSeconds ?? 0),
        sessions: Number(daily.sessions ?? 0),
      });
    }
  }

  // 3. Per-user: scan test_results + study_sessions
  const activeLearners: DailyActivityLearner[] = [];
  const inactiveLearnerNames: string[] = [];

  for (const profile of approvedProfiles) {
    const {uid, name, phone} = profile;

    // Load all attempt docs for this user
    let attemptSnaps;
    try {
      attemptSnaps = await db.collection(`test_results/${uid}/attempts`).get();
    } catch {
      attemptSnaps = {docs: []};
    }

    let daySessionIds = new Set<string>();
    const evalsBySession = new Map<string, Date[]>();
    let speakingItems = 0;
    let totalItems = 0;
    const simScores: number[] = [];

    for (const attemptDoc of attemptSnaps.docs) {
      const sid = attemptDoc.id;
      let itemSnaps;
      try {
        itemSnaps = await db.collection(`test_results/${uid}/attempts/${sid}/items`).get();
      } catch {
        continue;
      }
      for (const itemDoc of itemSnaps.docs) {
        const d = itemDoc.data();
        const evalAt = d.evaluatedAt as admin.firestore.Timestamp | undefined;
        if (!evalAt || evalAt < startTs || evalAt > endTs) continue;
        daySessionIds.add(sid);
        totalItems++;
        const evalDate = evalAt.toDate();
        const prev = evalsBySession.get(sid) ?? [];
        prev.push(evalDate);
        evalsBySession.set(sid, prev);
        const sim = d.similarityScore;
        if (sim !== null && sim !== undefined) {
          speakingItems++;
          simScores.push(Number(sim));
        }
      }
    }

    // Session start times for the day
    let sessionSnaps;
    try {
      sessionSnaps = await db.collection(`study_sessions/${uid}/sessions`)
        .where("startedAt", ">=", startTs)
        .where("startedAt", "<=", endTs)
        .get();
    } catch {
      sessionSnaps = {docs: []};
    }
    const daySessionStarts = new Map<string, Date>();
    for (const sDoc of sessionSnaps.docs) {
      const d = sDoc.data();
      const startedAt = d.startedAt as admin.firestore.Timestamp | undefined;
      if (startedAt) {
        daySessionIds.add(sDoc.id);
        daySessionStarts.set(sDoc.id, startedAt.toDate());
      }
    }

    const sessionCount = daySessionIds.size;
    if (sessionCount === 0 && totalItems === 0) {
      inactiveLearnerNames.push(name);
      continue;
    }

    // Duration calculation
    const summary = summaryByUid.get(uid);
    let durationSeconds: number;
    let durationSource: "completed" | "proxy" | "none";

    if (summary && summary.durationSeconds > 0) {
      durationSeconds = summary.durationSeconds;
      durationSource = "completed";
    } else if (evalsBySession.size > 0) {
      let total = 0;
      for (const [sid, evalTimes] of evalsBySession) {
        const lastEval = new Date(Math.max(...evalTimes.map((t) => t.getTime())));
        const sessionStart = daySessionStarts.get(sid);
        if (sessionStart) {
          const span = Math.min((lastEval.getTime() - sessionStart.getTime()) / 1000, 90 * 60);
          total += Math.max(span, 30);
        } else {
          total += 30;
        }
      }
      durationSeconds = Math.round(total);
      durationSource = "proxy";
    } else {
      durationSeconds = 0;
      durationSource = "none";
    }

    const avgSimilarity = simScores.length > 0
      ? Math.round(simScores.reduce((a, b) => a + b, 0) / simScores.length)
      : null;

    activeLearners.push({
      uid,
      name,
      phone,
      durationSeconds,
      durationSource,
      sessionCount,
      totalItems,
      speakingItems,
      avgSimilarity,
    });
  }

  inactiveLearnerNames.sort((a, b) => a.localeCompare(b, "ko"));
  activeLearners.sort((a, b) => b.durationSeconds - a.durationSeconds);

  return {
    dateKey,
    generatedAt: admin.firestore.Timestamp.now(),
    activeLearners,
    inactiveLearnerNames,
    totalApproved: approvedProfiles.length,
    activeCount: activeLearners.length,
  };
}

function fmtDur(seconds: number): string {
  if (seconds <= 0) return "-";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}시간 ${m}분 ${s}초`;
  if (m > 0) return `${m}분 ${s}초`;
  return `${s}초`;
}

function buildDailyReportTelegramText(report: DailyActivityReport): string {
  const {dateKey, activeLearners, inactiveLearnerNames, totalApproved, activeCount} = report;
  const lines: string[] = [];
  lines.push(`📊 ${dateKey} 학습 활동 보고 (KST 기준)`);
  lines.push(`생성 시각: ${formatKstDateTime(report.generatedAt)}`);
  lines.push(`활동: ${activeCount}명 / 미활동: ${inactiveLearnerNames.length}명 (전체 ${totalApproved}명)`);

  const byDuration = [...activeLearners].sort((a, b) => b.durationSeconds - a.durationSeconds);
  if (byDuration.length > 0) {
    lines.push("");
    lines.push("[학습시간 상위 3명]");
    byDuration.slice(0, 3).forEach((l, i) => {
      const approx = l.durationSource === "proxy" ? "~" : "";
      lines.push(`${i + 1}위 ${l.name}: ${approx}${fmtDur(l.durationSeconds)} (${l.sessionCount}회)`);
    });
  }

  const bySessions = [...activeLearners].sort((a, b) => b.sessionCount - a.sessionCount);
  if (bySessions.length > 0) {
    lines.push("");
    lines.push("[세션 수 상위 3명]");
    bySessions.slice(0, 3).forEach((l, i) => {
      lines.push(`${i + 1}위 ${l.name}: ${l.sessionCount}회 (말하기 ${l.speakingItems}건)`);
    });
  }

  const withSim = activeLearners.filter((l) => l.avgSimilarity !== null);
  withSim.sort((a, b) => (b.avgSimilarity ?? 0) - (a.avgSimilarity ?? 0));
  if (withSim.length > 0) {
    lines.push("");
    lines.push("[발음 유사도 상위 3명]");
    withSim.slice(0, 3).forEach((l, i) => {
      lines.push(`${i + 1}위 ${l.name}: ${l.avgSimilarity}% (${l.speakingItems}건)`);
    });
  }

  if (inactiveLearnerNames.length > 0) {
    lines.push("");
    lines.push(`[미활동 ${inactiveLearnerNames.length}명]`);
    lines.push(inactiveLearnerNames.join(", "));
  }

  return lines.join("\n");
}

export const generateDailyActivityReport = onSchedule(
  {
    schedule: "20 6 * * *",
    timeZone: "Asia/Seoul",
    region: "asia-northeast3",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async () => {
    // Report covers yesterday in KST (this runs at 6:20 AM KST)
    const nowKst = new Date(Date.now() + kstOffsetMs);
    const yesterday = new Date(nowKst.getTime() - 24 * 60 * 60 * 1000);
    const dateKey = formatUtcDateKey(yesterday);

    console.log(`Generating daily activity report for ${dateKey}`);
    const report = await computeDailyActivityReport(dateKey);

    await db.doc(`daily_activity_reports/${dateKey}`).set(report);

    const text = buildDailyReportTelegramText(report);
    await sendTelegramAdminMessage(text, {channel: "daily_activity_report", dateKey});
    console.log(`Daily activity report for ${dateKey} done: ${report.activeCount}/${report.totalApproved} active`);
  },
);

interface GetDailyActivityReportData {
  adminUserId: string;
  dateKey?: string;
}

export const getDailyActivityReport = onCall<GetDailyActivityReportData>(
  callableOptions,
  async (request) => {
    const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
    await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

    const dateKey = resolveDateKey(request.data?.dateKey);
    const snap = await db.doc(`daily_activity_reports/${dateKey}`).get();
    if (!snap.exists) {
      return {exists: false, dateKey, report: null};
    }
    const data = snap.data() as DailyActivityReport;
    return {
      exists: true,
      dateKey,
      report: {
        dateKey: data.dateKey,
        generatedAt: (data.generatedAt as admin.firestore.Timestamp).toDate().toISOString(),
        generatedAtKst: formatKstDateTime(data.generatedAt as admin.firestore.Timestamp),
        activeLearners: data.activeLearners,
        inactiveLearnerNames: data.inactiveLearnerNames,
        totalApproved: data.totalApproved,
        activeCount: data.activeCount,
      },
    };
  },
);

interface GenerateDailyActivityReportForDateData {
  adminUserId: string;
  dateKey?: string;
}

export const generateDailyActivityReportForDate = onCall<GenerateDailyActivityReportForDateData>(
  {
    ...callableOptions,
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async (request) => {
    const adminUserId = ensureString(request.data?.adminUserId, "adminUserId");
    await requireAdminUser(request.auth?.uid, request.auth?.token, adminUserId);

    const dateKey = resolveDateKey(request.data?.dateKey);
    const report = await computeDailyActivityReport(dateKey);
    await db.doc(`daily_activity_reports/${dateKey}`).set(report);

    return {
      dateKey,
      generatedAt: report.generatedAt.toDate().toISOString(),
      generatedAtKst: formatKstDateTime(report.generatedAt),
      activeLearners: report.activeLearners,
      inactiveLearnerNames: report.inactiveLearnerNames,
      totalApproved: report.totalApproved,
      activeCount: report.activeCount,
    };
  },
);

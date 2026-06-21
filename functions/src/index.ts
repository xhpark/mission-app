import * as admin from "firebase-admin";
import nodemailer from "nodemailer";
import {onCall, HttpsError} from "firebase-functions/v2/https";
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

  const parsed = new Date(value);
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

  for (const doc of itemsSnap.docs) {
    const data = doc.data() as Record<string, unknown>;
    const mode = data.mode;
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

  const totalItems = optionalNonNegativeInteger(sessionData.totalItems, "session.totalItems") ?? 0;
  const contentSetId = (sessionData.contentSetId ?? "").toString();
  const category = (sessionData.category ?? "").toString();
  const level = (sessionData.level ?? "").toString();
  const mode = (sessionData.mode ?? "").toString();
  // Assessment applicability and graded counts are server-authoritative.
  const assessmentApplicable = modeGroup(mode) === "test";
  const serverAttemptedAnswers = stats.choiceAttemptCount + stats.speakingAttemptCount;
  const serverCorrectAnswers = stats.choiceCorrectCount + stats.speakingPassedCount;

  // Test modes report completion from server-recorded attempts; learning modes
  // have no gradable attempts, so the self-reported completion count is accepted.
  const completedItemsRaw = assessmentApplicable ?
    (serverAttemptedAnswers > 0 ? serverAttemptedAnswers : (completedItemsFromClient ?? 0)) :
    (completedItemsFromClient ?? totalItems);
  if (totalItems > 0 && completedItemsRaw > totalItems) {
    throw new HttpsError("invalid-argument", "COMPLETED_ITEMS_EXCEEDS_TOTAL_ITEMS");
  }
  const completedItems = totalItems > 0 ?
    Math.min(completedItemsRaw, totalItems) :
    completedItemsRaw;
  const completionRate = calculatePercent(completedItems, totalItems);
  const completedAt = timestampFromIso(request.data?.completedAt) ??
    admin.firestore.Timestamp.now();
  const durationSeconds = durationSecondsFromClient ??
    secondsBetween(sessionData.startedAt, completedAt);
  if (durationSeconds > 24 * 60 * 60) {
    throw new HttpsError("invalid-argument", "DURATION_SECONDS_OUT_OF_RANGE");
  }
  const submittedAt = admin.firestore.FieldValue.serverTimestamp();
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
  const reportDateText = completedAt.toDate().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});
  const reportNoticeText = [
    "📄 리포트 제출",
    "",
    `이름: ${learnerName.length > 0 ? learnerName : "-"}`,
    `전화번호: ${learnerPhone.length > 0 ? learnerPhone : "-"}`,
    `이메일: ${learnerEmail.length > 0 ? learnerEmail : "-"}`,
    `사용자 ID: ${userId}`,
    `기기 ID: ${reportDeviceId.length > 0 ? reportDeviceId : "-"}`,
    `리포트 날짜: ${reportDateText}`,
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

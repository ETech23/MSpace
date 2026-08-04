const crypto = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");

const STAGE1_APP_ID_PATTERN = /^DSP-2026-\d{6}$/i;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_PATTERN = /^(\+234|234|0)([789][01]\d{8})$/;
const URL_PATTERN = /^(https?:\/\/)[^\s/$.?#].[^\s]*$/i;

const STAGE1_SPREADSHEET_HEADERS = [
  "Submission ID",
  "Respondent ID",
  "Submitted at",
  "First Name",
  "Last Name",
  "Phone Number (WhatsApp preferred)",
  "Email Address",
  "Date of birth",
  "Gender",
  "State of Residence",
  "Current Occupation",
  "Are you currently learning any digital skill?",
  "Which digital skill are you learning or interested in?",
  "How long have you been learning?",
  "Facebook Profile link",
  "Instagram Profile link",
  "Tiktok Profile link",
  "X (Twitter) Profile link",
  "How many followers do you have in total across your social media accounts?",
  "How many followers do you have in total across your social media accounts? (Under 100)",
  "How many followers do you have in total across your social media accounts? (100–500)",
  "How many followers do you have in total across your social media accounts? (501–1,000)",
  "How many followers do you have in total across your social media accounts? (1,001–5,000)",
  "How many followers do you have in total across your social media accounts? (5,001–10,000)",
  "How many followers do you have in total across your social media accounts? (Above 10,000)",
  "Do you currently own a laptop?",
  "Do you have access to a computer elsewhere?",
  "Are you willing to participate in follow-up activities if selected?",
  "How did you share the application?",
  "Paste one link showing you've shared the application .",
  "Screenshot showing you've shared the application",
  "I confirm that the information I have provided is true and accurate. I understand that submitting this application does not guarantee selection, and that applications found to contain false information may be disqualified.",
  "I confirm that the information I have provided is true and accurate. I understand that submitting this application does not guarantee selection, and that applications found to contain false information may be disqualified. (I agree to the terms above.)",
  "Status",
  "Email Sent",
  "Email Sent Date",
  "Next Stage",
  "Notes",
  "Applicant ID",
  "Queue Status",
  "Last Email Stage",
  "Last Email Date",
  "Failure Reason",
  "Retry Count",
  "Next Action Link"
];

function buildStage1ApplicantId() {
  const randomNumber = crypto.randomInt(0, 1_000_000).toString().padStart(6, "0");
  return `DSP-2026-${randomNumber}`;
}

function normalizeEmail(value) {
  return String(value ?? "").trim().toLowerCase();
}

function sanitizeStage1Payload(payload) {
  return Object.fromEntries(
    Object.entries(payload ?? {}).map(([key, value]) => [
      key,
      typeof value === "string" ? sanitizeText(value) : value
    ])
  );
}

function sanitizeText(value, maxLength = 4000) {
  return String(value ?? "")
    .replace(/<[^>]*>/g, "")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function validateStage1ApplicationPayload(payload) {
  const requiredFields = [
    "firstName",
    "lastName",
    "email",
    "phone",
    "gender",
    "age",
    "state",
    "lga",
    "highestQualification",
    "employmentStatus",
    "currentOccupation",
    "primarySkill",
    "experienceLevel",
    "startedLearning",
    "whyDigitalSkills",
    "ownsLaptop",
    "internetAvailability",
    "dailyDataBudget",
    "internetProvider",
    "totalFollowers",
    "referralSource",
    "accurateInformation",
    "understandNotGuarantee",
    "consentToContact"
  ];

  for (const field of requiredFields) {
    const value = payload?.[field];
    if (typeof value === "boolean") {
      if (value !== true) {
        return `${field} is required.`;
      }
      continue;
    }

    if (!String(value ?? "").trim()) {
      return `${field} is required.`;
    }
  }

  if (!EMAIL_PATTERN.test(normalizeEmail(payload.email))) {
    return "Enter a valid email address.";
  }

  if (!PHONE_PATTERN.test(String(payload.phone))) {
    return "Enter a valid Nigerian phone number.";
  }

  const age = Number(payload.age);
  if (!Number.isInteger(age) || age < 16 || age > 80) {
    return "Age must be between 16 and 80.";
  }

  const followers = Number(payload.totalFollowers);
  if (!Number.isInteger(followers) || followers < 0) {
    return "Total followers must be a valid number.";
  }

  if (wordCount(payload.whyDigitalSkills) > 400) {
    return "Why do you want to learn digital skills must be 400 words or less.";
  }

  for (const field of ["facebookProfile", "instagramProfile", "linkedInProfile", "xProfile", "tiktokProfile"]) {
    const value = String(payload[field] ?? "").trim();
    if (value && !URL_PATTERN.test(value)) {
      return `${field} must be a valid URL.`;
    }
  }

  if (String(payload.startedLearning).toLowerCase() === "yes") {
    if (!String(payload.learningPlatform ?? "").trim()) {
      return "Learning platform is required when you have started learning.";
    }
  }

  if (String(payload.ownsLaptop).toLowerCase() === "yes") {
    for (const field of ["laptopCondition", "ram", "storage", "operatingSystem"]) {
      if (!String(payload[field] ?? "").trim()) {
        return `${field} is required when you own a laptop.`;
      }
    }
  }

  if (String(payload.referralSource).toLowerCase() === "other") {
    if (!String(payload.referralCode ?? "").trim()) {
      return "Referral code or note is required when referral source is Other.";
    }
  }

  return null;
}

function buildStage1FirestoreDocument(payload, metadata, applicantId) {
  const normalizedEmail = normalizeEmail(payload.email);
  const firstName = sanitizeText(payload.firstName, 120);
  const lastName = sanitizeText(payload.lastName, 120);
  const primarySkill = sanitizeText(payload.primarySkill, 120);
  const stageLabel = "Stage1";
  const currentStage = "Stage 1";

  return {
    applicantId,
    stage: stageLabel,
    currentStage,
    status: "Pending Review",
    verificationStatus: "Pending Review",
    paymentStatus: "N/A",
    queueStatus: "Waiting",
    lastEmailStage: "None",
    lastEmailDate: null,
    failureReason: null,
    retryCount: 0,
    nextActionLink: buildNextActionLink(applicantId),
    email: normalizedEmail,
    emailNormalized: normalizedEmail,
    firstName,
    lastName,
    phone: sanitizeText(payload.phone, 32),
    gender: sanitizeText(payload.gender, 40),
    age: Number(payload.age),
    state: sanitizeText(payload.state, 80),
    lga: sanitizeText(payload.lga, 120),
    highestQualification: sanitizeText(payload.highestQualification, 120),
    employmentStatus: sanitizeText(payload.employmentStatus, 80),
    currentOccupation: sanitizeText(payload.currentOccupation, 120),
    primarySkill,
    preferredDigitalSkill: primarySkill,
    secondarySkill: sanitizeText(payload.secondarySkill, 120),
    experienceLevel: sanitizeText(payload.experienceLevel, 40),
    startedLearning: sanitizeText(payload.startedLearning, 20),
    learningPlatform: sanitizeText(payload.learningPlatform, 80),
    learningPlatformOther: sanitizeText(payload.learningPlatformOther, 120),
    whyDigitalSkills: sanitizeText(payload.whyDigitalSkills, 5000),
    ownsLaptop: sanitizeText(payload.ownsLaptop, 20),
    laptopCondition: sanitizeText(payload.laptopCondition, 80),
    ram: sanitizeText(payload.ram, 80),
    storage: sanitizeText(payload.storage, 80),
    operatingSystem: sanitizeText(payload.operatingSystem, 80),
    internetAvailability: sanitizeText(payload.internetAvailability, 80),
    dailyDataBudget: sanitizeText(payload.dailyDataBudget, 80),
    internetProvider: sanitizeText(payload.internetProvider, 120),
    facebookProfile: sanitizeText(payload.facebookProfile, 300),
    instagramProfile: sanitizeText(payload.instagramProfile, 300),
    linkedInProfile: sanitizeText(payload.linkedInProfile, 300),
    xProfile: sanitizeText(payload.xProfile, 300),
    tiktokProfile: sanitizeText(payload.tiktokProfile, 300),
    totalFollowers: Number(payload.totalFollowers),
    referralSource: sanitizeText(payload.referralSource, 80),
    referralCode: sanitizeText(payload.referralCode, 160),
    accurateInformation: Boolean(payload.accurateInformation),
    understandNotGuarantee: Boolean(payload.understandNotGuarantee),
    consentToContact: Boolean(payload.consentToContact),
    submissionTime: FieldValue.serverTimestamp(),
    ipAddress: metadata.ipAddress,
    browser: metadata.browser,
    submittedFrom: metadata.submittedFrom ?? "web",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  };
}

function buildStage1SpreadsheetRow(application) {
  const submittedAt = application.submittedAt ?? new Date().toISOString();
  const totalFollowers = Number(application.totalFollowers ?? 0);
  const notes = [
    application.secondarySkill ? `Secondary skill: ${application.secondarySkill}` : "",
    application.experienceLevel ? `Experience: ${application.experienceLevel}` : "",
    application.learningPlatform ? `Platform: ${application.learningPlatform}` : "",
    application.learningPlatformOther ? `Platform note: ${application.learningPlatformOther}` : "",
    application.ownsLaptop === "Yes" && application.laptopCondition
      ? `Laptop: ${application.laptopCondition}`
      : "",
    application.ram ? `RAM: ${application.ram}` : "",
    application.storage ? `Storage: ${application.storage}` : "",
    application.operatingSystem ? `OS: ${application.operatingSystem}` : "",
    application.dailyDataBudget ? `Data budget: ${application.dailyDataBudget}` : "",
    application.internetProvider ? `Internet provider: ${application.internetProvider}` : ""
  ]
    .filter(Boolean)
    .join("; ");

  return [
    application.applicantId ?? "",
    "",
    submittedAt,
    application.firstName ?? "",
    application.lastName ?? "",
    application.phone ?? "",
    application.email ?? "",
    "",
    application.gender ?? "",
    application.state ?? "",
    application.currentOccupation ?? "",
    application.startedLearning ?? "",
    application.primarySkill ?? "",
    application.experienceLevel ?? "",
    application.facebookProfile ?? "",
    application.instagramProfile ?? "",
    application.tiktokProfile ?? "",
    application.xProfile ?? "",
    totalFollowers,
    totalFollowers > 0 && totalFollowers < 100,
    totalFollowers >= 100 && totalFollowers <= 500,
    totalFollowers >= 501 && totalFollowers <= 1000,
    totalFollowers >= 1001 && totalFollowers <= 5000,
    totalFollowers >= 5001 && totalFollowers <= 10000,
    totalFollowers > 10000,
    application.ownsLaptop ?? "",
    "",
    application.consentToContact ? "Yes" : "",
    application.referralSource ?? "",
    application.referralCode ?? "",
    "",
    application.accurateInformation ? true : false,
    application.understandNotGuarantee ? true : false,
    application.status ?? "Pending Review",
    "",
    "",
    "",
    notes,
    application.applicantId ?? "",
    "",
    "",
    application.lastEmailDate ?? "",
    "",
    0,
    application.nextActionLink ?? ""
  ];
}

function buildNextActionLink(applicantId) {
  const frontendUrl = String(
    process.env.FRONTEND_URL?.split(",")[0] ?? "https://mspaceapp.com"
  ).replace(/\/$/, "");
  return `${frontendUrl}/apply/success?applicantId=${encodeURIComponent(applicantId)}`;
}

function wordCount(value) {
  return String(value ?? "")
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
}

module.exports = {
  STAGE1_APP_ID_PATTERN,
  STAGE1_SPREADSHEET_HEADERS,
  buildStage1ApplicantId,
  buildStage1FirestoreDocument,
  buildStage1SpreadsheetRow,
  normalizeEmail,
  sanitizeStage1Payload,
  validateStage1ApplicationPayload
};

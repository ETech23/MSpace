const crypto = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");

const STAGE1_APP_ID_PATTERN = /^DSP1-2026-\d{6}$/i;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_PATTERN = /^(\+234|234|0)([789][01]\d{8})$/;
const URL_PATTERN = /^(https?:\/\/)[^\s/$.?#].[^\s]*$/i;

function buildStage1ApplicantId() {
  const randomNumber = crypto.randomInt(0, 1_000_000).toString().padStart(6, "0");
  return `DSP1-2026-${randomNumber}`;
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
  const socialLink = [
    application.facebookProfile,
    application.instagramProfile,
    application.linkedInProfile,
    application.xProfile,
    application.tiktokProfile
  ]
    .filter(Boolean)
    .join(" | ");

  const notes = [
    `Learning: ${application.startedLearning}`,
    application.learningPlatform ? `Platform: ${application.learningPlatform}` : "",
    application.ownsLaptop === "Yes" ? `Laptop: ${application.laptopCondition}` : ""
  ]
    .filter(Boolean)
    .join("; ");

  return [
    new Date().toISOString(),
    application.firstName,
    application.lastName,
    application.email,
    application.phone,
    application.gender,
    application.age,
    application.state,
    application.lga,
    application.primarySkill,
    application.currentOccupation,
    application.highestQualification,
    socialLink,
    application.totalFollowers,
    application.referralSource,
    application.status,
    notes,
    application.applicantId,
    application.queueStatus,
    application.lastEmailStage,
    application.lastEmailDate ?? "",
    application.failureReason ?? "",
    application.retryCount,
    application.nextActionLink
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
  buildStage1ApplicantId,
  buildStage1FirestoreDocument,
  buildStage1SpreadsheetRow,
  normalizeEmail,
  sanitizeStage1Payload,
  validateStage1ApplicationPayload
};

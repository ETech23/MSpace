const applicantIdPattern = /^DSP-2026-\d{6}$/i;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const phonePattern = /^(\+234|234|0)([789][01]\d{8})$/;
const sqlRiskPattern =
  /(\b(select|insert|update|delete|drop|alter|truncate|union|exec)\b|--|;|\/\*|\*\/)/i;

const requiredApplicantFields = [
  "applicantId",
  "firstName",
  "lastName",
  "email",
  "phone",
  "state",
  "lga",
  "gender",
  "age",
  "highestEducation",
  "employmentStatus",
  "preferredDigitalSkill",
  "motivation",
  "currentOccupation",
  "ownsLaptop",
  "internetAvailability",
  "socialFollowers",
  "emergencyContactName",
  "emergencyContactPhone"
];

function validateApplicantPayload(payload) {
  for (const field of requiredApplicantFields) {
    if (!String(payload[field] ?? "").trim()) {
      return `${field} is required.`;
    }
  }

  if (payload.confirmation !== true) {
    return "Applicant confirmation is required.";
  }

  if (!applicantIdPattern.test(payload.applicantId)) {
    return "Applicant ID must use the DSP-2026-000458 format.";
  }

  if (!emailPattern.test(payload.email)) {
    return "Enter a valid email address.";
  }

  if (!phonePattern.test(payload.phone)) {
    return "Enter a valid Nigerian phone number.";
  }

  if (!phonePattern.test(payload.emergencyContactPhone)) {
    return "Enter a valid emergency contact phone number.";
  }

  const age = Number(payload.age);
  if (!Number.isInteger(age) || age < 16 || age > 80) {
    return "Age must be between 16 and 80.";
  }

  const followers = Number(payload.socialFollowers);
  if (!Number.isInteger(followers) || followers < 0) {
    return "Social media followers must be a valid number.";
  }

  if (String(payload.motivation).length < 40) {
    return "Motivation must be at least 40 characters.";
  }

  for (const [field, value] of Object.entries(payload)) {
    if (typeof value === "string" && sqlRiskPattern.test(value)) {
      return `${field} contains unsupported characters.`;
    }
  }

  for (const field of ["facebookProfile", "xProfile", "linkedInProfile"]) {
    const value = payload[field];
    if (value && !/^https?:\/\/[\w.-]+/i.test(value)) {
      return `${field} must be a valid URL.`;
    }
  }

  return null;
}

function isValidApplicantId(value) {
  return applicantIdPattern.test(String(value ?? ""));
}

module.exports = {
  isValidApplicantId,
  validateApplicantPayload
};

export type ApplicantForm = {
  applicantId: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  state: string;
  lga: string;
  gender: string;
  age: string;
  highestEducation: string;
  employmentStatus: string;
  preferredDigitalSkill: string;
  motivation: string;
  currentOccupation: string;
  ownsLaptop: string;
  internetAvailability: string;
  facebookProfile: string;
  xProfile: string;
  linkedInProfile: string;
  socialFollowers: string;
  emergencyContactName: string;
  emergencyContactPhone: string;
  confirmation: boolean;
};

export type ApplicantPayload = Omit<ApplicantForm, "confirmation"> & {
  confirmation: true;
};

export type CreateApplicantResponse = {
  applicantId: string;
  amount: number;
  currency: "NGN";
  email: string;
  paymentReference: string;
};

export type PaymentReceipt = {
  applicantId: string;
  amountPaid: number;
  currency: "NGN";
  currentStatus: string;
  paymentDate: string;
  paymentReference: string;
  receiptNumber: string;
};

export const initialApplicantForm: ApplicantForm = {
  applicantId: "",
  firstName: "",
  lastName: "",
  email: "",
  phone: "",
  state: "",
  lga: "",
  gender: "",
  age: "",
  highestEducation: "",
  employmentStatus: "",
  preferredDigitalSkill: "",
  motivation: "",
  currentOccupation: "",
  ownsLaptop: "",
  internetAvailability: "",
  facebookProfile: "",
  xProfile: "",
  linkedInProfile: "",
  socialFollowers: "",
  emergencyContactName: "",
  emergencyContactPhone: "",
  confirmation: false
};

export const states = [
  "Abia",
  "Adamawa",
  "Akwa Ibom",
  "Anambra",
  "Bauchi",
  "Bayelsa",
  "Benue",
  "Borno",
  "Cross River",
  "Delta",
  "Ebonyi",
  "Edo",
  "Ekiti",
  "Enugu",
  "FCT",
  "Gombe",
  "Imo",
  "Jigawa",
  "Kaduna",
  "Kano",
  "Katsina",
  "Kebbi",
  "Kogi",
  "Kwara",
  "Lagos",
  "Nasarawa",
  "Niger",
  "Ogun",
  "Ondo",
  "Osun",
  "Oyo",
  "Plateau",
  "Rivers",
  "Sokoto",
  "Taraba",
  "Yobe",
  "Zamfara"
];

export const digitalSkills = [
  "Product Design",
  "Frontend Development",
  "Backend Development",
  "Data Analysis",
  "Digital Marketing",
  "Cybersecurity",
  "Cloud Computing",
  "UI/UX Design",
  "Content Creation",
  "Virtual Assistance"
];

const applicantIdPattern = /^DSP-2026-\d{6}$/i;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const phonePattern = /^(\+234|234|0)([789][01]\d{8})$/;

const requiredFields: Array<keyof ApplicantForm> = [
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

export function sanitizeInput(value: string): string {
  return value
    .replace(/<[^>]*>/g, "")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function sanitizeApplicantForm(form: ApplicantForm): ApplicantForm {
  return Object.fromEntries(
    Object.entries(form).map(([key, value]) => [
      key,
      typeof value === "string" ? sanitizeInput(value) : value
    ])
  ) as ApplicantForm;
}

export function validateApplicantForm(form: ApplicantForm): Record<string, string> {
  const sanitized = sanitizeApplicantForm(form);
  const errors: Record<string, string> = {};

  for (const field of requiredFields) {
    if (!String(sanitized[field] ?? "").trim()) {
      errors[field] = "Required";
    }
  }

  if (sanitized.applicantId && !applicantIdPattern.test(sanitized.applicantId)) {
    errors.applicantId = "Use the format DSP-2026-000458";
  }

  if (sanitized.email && !emailPattern.test(sanitized.email)) {
    errors.email = "Enter a valid email address";
  }

  if (sanitized.phone && !phonePattern.test(sanitized.phone)) {
    errors.phone = "Enter a valid Nigerian phone number";
  }

  if (
    sanitized.emergencyContactPhone &&
    !phonePattern.test(sanitized.emergencyContactPhone)
  ) {
    errors.emergencyContactPhone = "Enter a valid Nigerian phone number";
  }

  const age = Number(sanitized.age);
  if (!Number.isInteger(age) || age < 16 || age > 80) {
    errors.age = "Age must be between 16 and 80";
  }

  const followers = Number(sanitized.socialFollowers);
  if (!Number.isInteger(followers) || followers < 0) {
    errors.socialFollowers = "Enter a valid follower count";
  }

  if (sanitized.motivation.length < 40) {
    errors.motivation = "Write at least 40 characters";
  }

  if (!sanitized.confirmation) {
    errors.confirmation = "Please confirm your information";
  }

  return errors;
}

export function toApplicantPayload(form: ApplicantForm): ApplicantPayload {
  const sanitized = sanitizeApplicantForm(form);
  return {
    ...sanitized,
    applicantId: sanitized.applicantId.toUpperCase(),
    email: sanitized.email.toLowerCase(),
    confirmation: true
  };
}


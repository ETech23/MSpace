import { digitalSkills } from "./application";

export type Stage1Form = {
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  gender: string;
  age: string;
  state: string;
  lga: string;
  highestQualification: string;
  employmentStatus: string;
  currentOccupation: string;
  primarySkill: string;
  secondarySkill: string;
  experienceLevel: string;
  startedLearning: string;
  learningPlatform: string;
  learningPlatformOther: string;
  whyDigitalSkills: string;
  ownsLaptop: string;
  laptopCondition: string;
  ram: string;
  storage: string;
  operatingSystem: string;
  internetAvailability: string;
  dailyDataBudget: string;
  internetProvider: string;
  facebookProfile: string;
  instagramProfile: string;
  linkedInProfile: string;
  xProfile: string;
  tiktokProfile: string;
  totalFollowers: string;
  referralSource: string;
  referralCode: string;
  accurateInformation: boolean;
  understandNotGuarantee: boolean;
  consentToContact: boolean;
};

export type Stage1Payload = Omit<
  Stage1Form,
  "accurateInformation" | "understandNotGuarantee" | "consentToContact"
> & {
  accurateInformation: true;
  understandNotGuarantee: true;
  consentToContact: true;
};

export type Stage1ApplicationResponse = {
  applicantId: string;
  stage: "Stage1";
  queueStatus: string;
  failureReason: string | null;
  retryCount: number;
  nextActionLink: string;
  status: string;
  submittedAt: string;
  email?: string;
  firstName?: string;
  lastName?: string;
};

export const initialStage1Form: Stage1Form = {
  firstName: "",
  lastName: "",
  email: "",
  phone: "",
  gender: "",
  age: "",
  state: "",
  lga: "",
  highestQualification: "",
  employmentStatus: "",
  currentOccupation: "",
  primarySkill: "",
  secondarySkill: "",
  experienceLevel: "",
  startedLearning: "",
  learningPlatform: "",
  learningPlatformOther: "",
  whyDigitalSkills: "",
  ownsLaptop: "",
  laptopCondition: "",
  ram: "",
  storage: "",
  operatingSystem: "",
  internetAvailability: "",
  dailyDataBudget: "",
  internetProvider: "",
  facebookProfile: "",
  instagramProfile: "",
  linkedInProfile: "",
  xProfile: "",
  tiktokProfile: "",
  totalFollowers: "",
  referralSource: "",
  referralCode: "",
  accurateInformation: false,
  understandNotGuarantee: false,
  consentToContact: false
};

export const stage1Options = {
  genders: ["Female", "Male", "Prefer not to say", "Other"],
  qualifications: [
    "No Formal Education",
    "Primary School",
    "Secondary School",
    "OND/NCE",
    "HND",
    "Bachelor's Degree",
    "Postgraduate",
    "Other"
  ],
  employmentStatuses: [
    "Student",
    "Employed",
    "Self-employed",
    "Unemployed",
    "Apprentice",
    "NYSC",
    "Other"
  ],
  experienceLevels: ["Beginner", "Intermediate", "Advanced"],
  yesNo: ["Yes", "No"],
  learningPlatforms: [
    "YouTube",
    "Udemy",
    "Coursera",
    "Cisco",
    "Bootcamp",
    "Self Learning",
    "Other"
  ],
  laptopConditions: ["Excellent", "Good", "Fair", "Needs Repair"],
  operatingSystems: ["Windows", "macOS", "Linux", "ChromeOS", "Other"],
  internetAvailability: [
    "Daily",
    "Several times a week",
    "Weekly",
    "Rarely",
    "Not available"
  ],
  referralSources: ["Facebook", "Instagram", "LinkedIn", "WhatsApp", "Friend", "Google", "Other"],
  digitalSkills
};

export const stage1Steps = [
  {
    title: "Personal",
    description: "Identity and contact details",
    fields: [
      "firstName",
      "lastName",
      "email",
      "phone",
      "gender",
      "age",
      "state",
      "lga"
    ] as const
  },
  {
    title: "Education",
    description: "Academic background and work status",
    fields: [
      "highestQualification",
      "employmentStatus",
      "currentOccupation"
    ] as const
  },
  {
    title: "Digital Interest",
    description: "Learning goals and experience",
    fields: [
      "primarySkill",
      "secondarySkill",
      "experienceLevel",
      "startedLearning",
      "learningPlatform",
      "learningPlatformOther",
      "whyDigitalSkills"
    ] as const
  },
  {
    title: "Device & Internet",
    description: "Hardware and connectivity details",
    fields: [
      "ownsLaptop",
      "laptopCondition",
      "ram",
      "storage",
      "operatingSystem",
      "internetAvailability",
      "dailyDataBudget",
      "internetProvider"
    ] as const
  },
  {
    title: "Social & Review",
    description: "Profiles, referral, and declaration",
    fields: [
      "facebookProfile",
      "instagramProfile",
      "linkedInProfile",
      "xProfile",
      "tiktokProfile",
      "totalFollowers",
      "referralSource",
      "referralCode",
      "accurateInformation",
      "understandNotGuarantee",
      "consentToContact"
    ] as const
  }
] as const;

const stage1EmailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const stage1PhonePattern = /^(\+234|234|0)([789][01]\d{8})$/;
const stage1UrlPattern = /^(https?:\/\/)[^\s/$.?#].[^\s]*$/i;

export function sanitizeStage1Input(value: string): string {
  return value
    .replace(/<[^>]*>/g, "")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function sanitizeStage1Form(form: Stage1Form): Stage1Form {
  return Object.fromEntries(
    Object.entries(form).map(([key, value]) => [
      key,
      typeof value === "string" ? sanitizeStage1Input(value) : value
    ])
  ) as Stage1Form;
}

export function validateStage1Form(form: Stage1Form): Record<string, string> {
  const sanitized = sanitizeStage1Form(form);
  const errors: Record<string, string> = {};

  const requiredTextFields: Array<keyof Stage1Form> = [
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
    "referralSource"
  ];

  for (const field of requiredTextFields) {
    if (!String(sanitized[field] ?? "").trim()) {
      errors[field] = "Required";
    }
  }

  if (!stage1EmailPattern.test(sanitized.email)) {
    errors.email = "Enter a valid email address";
  }

  if (!stage1PhonePattern.test(sanitized.phone)) {
    errors.phone = "Enter a valid Nigerian phone number";
  }

  const age = Number(sanitized.age);
  if (!Number.isInteger(age) || age < 16 || age > 80) {
    errors.age = "Age must be between 16 and 80";
  }

  const totalFollowers = Number(sanitized.totalFollowers);
  if (!Number.isInteger(totalFollowers) || totalFollowers < 0) {
    errors.totalFollowers = "Enter a valid follower count";
  }

  if (wordCount(sanitized.whyDigitalSkills) > 400) {
    errors.whyDigitalSkills = "Limit this answer to 400 words";
  }

  for (const field of ["facebookProfile", "instagramProfile", "linkedInProfile", "xProfile", "tiktokProfile"] as const) {
    const value = String(sanitized[field] ?? "").trim();
    if (value && !stage1UrlPattern.test(value)) {
      errors[field] = "Enter a valid URL";
    }
  }

  if (sanitized.startedLearning === "Yes" && !String(sanitized.learningPlatform).trim()) {
    errors.learningPlatform = "Choose where you are learning";
  }

  if (sanitized.startedLearning === "Yes" && sanitized.learningPlatform === "Other" && !String(sanitized.learningPlatformOther).trim()) {
    errors.learningPlatformOther = "Please specify your learning platform";
  }

  if (sanitized.ownsLaptop === "Yes") {
    for (const field of ["laptopCondition", "ram", "storage", "operatingSystem"] as const) {
      if (!String(sanitized[field] ?? "").trim()) {
        errors[field] = "Required";
      }
    }
  }

  if (sanitized.referralSource === "Other" && !String(sanitized.referralCode).trim()) {
    errors.referralCode = "Please tell us where you heard about the program";
  }

  if (!sanitized.accurateInformation) {
    errors.accurateInformation = "Please confirm the information is accurate";
  }

  if (!sanitized.understandNotGuarantee) {
    errors.understandNotGuarantee = "Please confirm your understanding";
  }

  if (!sanitized.consentToContact) {
    errors.consentToContact = "Please consent to being contacted";
  }

  return errors;
}

export function toStage1Payload(form: Stage1Form): Stage1Payload {
  const sanitized = sanitizeStage1Form(form);

  return {
    ...sanitized,
    email: sanitized.email.toLowerCase(),
    accurateInformation: true,
    understandNotGuarantee: true,
    consentToContact: true
  };
}

export function wordCount(value: string): number {
  return String(value ?? "")
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
}

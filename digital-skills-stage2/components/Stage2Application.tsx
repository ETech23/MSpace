"use client";

import { AnimatePresence, motion } from "framer-motion";
import {
  ArrowRight,
  CheckCircle2,
  CreditCard,
  Lock,
  ShieldCheck
} from "lucide-react";
import { useRouter, useSearchParams } from "next/navigation";
import { ChangeEvent, FormEvent, useEffect, useMemo, useState } from "react";
import { createApplicant, getCsrfToken, verifyPayment } from "../lib/api";
import {
  ApplicantForm,
  digitalSkills,
  initialApplicantForm,
  sanitizeApplicantForm,
  states,
  toApplicantPayload,
  validateApplicantForm
} from "../lib/application";
import { openPaystackCheckout } from "../lib/paystack";
import { ThemeToggle } from "./ThemeToggle";

const educationOptions = [
  "Secondary School",
  "OND/NCE",
  "HND",
  "Bachelor's Degree",
  "Postgraduate",
  "Other"
];

const employmentOptions = [
  "Student",
  "Employed",
  "Self-employed",
  "Unemployed",
  "NYSC",
  "Other"
];

type ProcessStepState = "done" | "current" | "upcoming";

const processSteps: Array<{ index: string; label: string; state: ProcessStepState }> = [
  { index: "01", label: "Application", state: "done" },
  { index: "02", label: "Verification", state: "current" },
  { index: "03", label: "Selection", state: "upcoming" }
];

const formSteps: Array<{
  title: string;
  description: string;
  fields: Array<keyof ApplicantForm>;
}> = [
  {
    title: "Step 1 — Basic details",
    description: "Confirm your identity and contact information.",
    fields: [
      "applicantId",
      "firstName",
      "lastName",
      "email",
      "phone",
      "gender",
      "state",
      "lga",
      "age"
    ]
  },
  {
    title: "Step 2 — Background",
    description: "Education, work status, and your preferred track.",
    fields: [
      "highestEducation",
      "employmentStatus",
      "preferredDigitalSkill",
      "currentOccupation",
      "ownsLaptop",
      "internetAvailability",
      "socialFollowers",
      "motivation"
    ]
  },
  {
    title: "Step 3 — Links & confirmation",
    description: "Profiles, emergency contact, and final confirmation.",
    fields: [
      "facebookProfile",
      "xProfile",
      "linkedInProfile",
      "emergencyContactName",
      "emergencyContactPhone",
      "confirmation"
    ]
  }
];

export function Stage2Application() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [form, setForm] = useState<ApplicantForm>(initialApplicantForm);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [currentStep, setCurrentStep] = useState(0);
  const [csrfToken, setCsrfToken] = useState("");
  const [loadingToken, setLoadingToken] = useState(true);
  const [status, setStatus] = useState<"idle" | "saving" | "checkout" | "verifying">(
    "idle"
  );
  const [notice, setNotice] = useState("");

  const applicantIdFromUrl = searchParams.get("applicantId") ?? "";

  useEffect(() => {
    setForm((current) => ({
      ...current,
      applicantId: applicantIdFromUrl || current.applicantId
    }));
  }, [applicantIdFromUrl]);

  useEffect(() => {
    getCsrfToken()
      .then(setCsrfToken)
      .catch((error: Error) => setNotice(error.message))
      .finally(() => setLoadingToken(false));
  }, []);

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, [currentStep]);

  const isBusy = status !== "idle";
  const sanitizedForm = useMemo(() => sanitizeApplicantForm(form), [form]);
  const isFinalStep = currentStep === formSteps.length - 1;

  function updateField(
    field: keyof ApplicantForm,
    value: string | boolean
  ) {
    setForm((current) => ({ ...current, [field]: value }));
    setErrors((current) => {
      const next = { ...current };
      delete next[field];
      return next;
    });
  }

  function getStepErrors(validationErrors: Record<string, string>, stepIndex: number) {
    const fields = formSteps[stepIndex]?.fields ?? [];
    return Object.fromEntries(
      Object.entries(validationErrors).filter(([field]) =>
        fields.includes(field as keyof ApplicantForm)
      )
    );
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setNotice("");

    const validationErrors = validateApplicantForm(sanitizedForm);
    const stepErrors = isFinalStep
      ? validationErrors
      : getStepErrors(validationErrors, currentStep);

    if (Object.keys(stepErrors).length > 0) {
      setErrors(stepErrors);
      return;
    }

    if (!isFinalStep) {
      setErrors({});
      setCurrentStep((step) => Math.min(step + 1, formSteps.length - 1));
      return;
    }

    try {
      setStatus("saving");
      const applicant = await createApplicant(
        toApplicantPayload(sanitizedForm),
        csrfToken
      );

      setStatus("checkout");
      await openPaystackCheckout(
        applicant,
        async ({ reference }) => {
          try {
            setStatus("verifying");
            const receipt = await verifyPayment(
              applicant.applicantId,
              reference,
              csrfToken
            );
            sessionStorage.setItem("stage2-receipt", JSON.stringify(receipt));
            router.push(
              `/success?applicantId=${encodeURIComponent(receipt.applicantId)}`
            );
          } catch (error) {
            setNotice(
              error instanceof Error
                ? error.message
                : "Payment verification failed"
            );
            setStatus("idle");
          }
        },
        () => {
          setNotice("Checkout closed before payment was verified.");
          setStatus("idle");
        }
      );
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Unable to continue");
      setStatus("idle");
    }
  }

  if (loadingToken) {
    return <LoadingExperience />;
  }

  return (
    <>
      <AnimatePresence>
        {isBusy ? (
          <motion.div
            animate={{ opacity: 1 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 px-4 py-6 backdrop-blur-sm"
            exit={{ opacity: 0 }}
            initial={{ opacity: 0 }}
            role="alertdialog"
            aria-live="assertive"
            aria-busy="true"
          >
            <motion.div
              animate={{ y: 0, scale: 1, opacity: 1 }}
              className="w-full max-w-md rounded-2xl border border-white/15 bg-[#08130f]/95 p-7 text-center text-white shadow-2xl shadow-black/40"
              initial={{ y: 18, scale: 0.98, opacity: 0 }}
              transition={{ duration: 0.22 }}
            >
              <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-brand-gold/15 text-brand-gold">
                <motion.div
                  animate={{ rotate: 360 }}
                  className="h-7 w-7 rounded-full border-4 border-brand-gold/25 border-t-brand-gold"
                  transition={{ repeat: Infinity, ease: "linear", duration: 0.9 }}
                />
              </div>
              <p className="mt-4 text-[11px] font-bold uppercase tracking-[0.3em] text-brand-gold/90">
                Please wait
              </p>
              <h3 className="mt-2 text-xl font-black">
                {workingStatusTitle(status)}
              </h3>
              <p className="mt-2 text-sm leading-6 text-white/75">
                {workingStatusDescription(status)}
              </p>
              <div className="mt-5 rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-left text-xs text-white/85">
                Do not refresh or close this page while we finish preparing your
                payment.
              </div>
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      <main className="mx-auto min-h-screen max-w-6xl px-4 pb-10 sm:px-6 lg:px-8">
        {/* Compact sticky header — replaces the full-screen hero */}
        <header className="sticky top-0 z-30 -mx-4 flex items-center justify-between border-b border-emerald-900/10 bg-white/95 px-4 py-3 backdrop-blur sm:-mx-6 sm:px-6 dark:border-white/10 dark:bg-[#08130f]/95">
          <div className="flex items-center gap-2.5">
            <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-brand-green text-white">
              <ShieldCheck size={16} />
            </span>
            <div className="leading-tight">
              <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-brand-green dark:text-brand-gold">
                Digital Skills Laptop Support Program
              </p>
              <p className="text-xs font-semibold text-brand-ink dark:text-white">
                Stage 2 &middot; Verification
              </p>
            </div>
          </div>
          <ThemeToggle />
        </header>

        {/* Process rail — a real sequence, not decoration */}
        <nav
          aria-label="Application progress"
          className="mt-4 flex items-center gap-1 overflow-x-auto rounded-lg border border-emerald-900/10 bg-white/70 px-3 py-2.5 dark:border-white/10 dark:bg-white/5"
        >
          {processSteps.map((step, idx) => (
            <div className="flex items-center" key={step.index}>
              <ProcessStep {...step} />
              {idx < processSteps.length - 1 ? (
                <span
                  aria-hidden="true"
                  className={
                    "mx-2 h-px w-6 shrink-0 sm:w-10 " +
                    (step.state === "done" ? "bg-brand-green" : "bg-emerald-900/15 dark:bg-white/15")
                  }
                />
              ) : null}
            </div>
          ))}
        </nav>

        {/* One-line status banner */}
        <p className="mt-4 text-sm leading-6 text-emerald-950/75 dark:text-white/70">
          <span className="font-bold text-brand-ink dark:text-white">Congratulations.</span>{" "}
          Your Stage 1 application was successful. Complete verification and pay the processing
          fee below to advance to Stage 3.
        </p>

        {/* Reference strip — mono, data-first, replaces the 3 hero stat cards */}
        <div className="mt-4 grid grid-cols-3 divide-x divide-emerald-900/10 overflow-hidden rounded-lg border border-emerald-900/10 bg-white/70 dark:divide-white/10 dark:border-white/10 dark:bg-white/5">
          <RefCell label="Applicant ID" value={form.applicantId || "Pending"} mono />
          <RefCell label="Processing fee" value="NGN 1,000" mono />
          <RefCell
            label="Payment"
            value="Paystack"
            icon={<CreditCard className="text-brand-green dark:text-brand-gold" size={14} />}
          />
        </div>

        <div className="mt-6 grid gap-6 lg:grid-cols-[0.85fr_1.15fr] lg:items-start">
          {/* Desktop-only requirements / security panel */}
          <aside className="hidden rounded-xl border border-emerald-900/10 bg-white/70 p-5 lg:block dark:border-white/10 dark:bg-white/5 lg:sticky lg:top-20">
            <p className="text-[11px] font-bold uppercase tracking-[0.2em] text-brand-green dark:text-brand-gold">
              Before you continue
            </p>
            <ul className="mt-4 space-y-3 text-sm text-emerald-950/75 dark:text-white/70">
              <RequirementItem text="Complete every required field accurately." />
              <RequirementItem text="Inaccurate or misleading information may result in disqualification." />
              <RequirementItem text="Have your emergency contact details ready." />
              <RequirementItem text="The NGN 1,000 fee is processed securely by Paystack." />
            </ul>
            <div className="mt-5 flex items-center gap-2 rounded-lg border border-emerald-900/10 bg-emerald-950/[0.03] px-3 py-2.5 text-xs font-medium text-emerald-950/70 dark:border-white/10 dark:bg-white/5 dark:text-white/60">
              <Lock size={14} className="shrink-0 text-brand-green dark:text-brand-gold" />
              Your data is encrypted in transit and never shared with third parties.
            </div>
          </aside>

          <section className="rounded-xl border border-emerald-900/10 bg-white/85 p-4 dark:border-white/10 dark:bg-white/5 sm:p-6">
            <div className="flex flex-col gap-3 border-b border-emerald-900/10 pb-5 dark:border-white/10 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.18em] text-brand-green dark:text-brand-gold">
                  {formSteps[currentStep].title}
                </p>
                <p className="mt-1 text-sm text-emerald-950/70 dark:text-white/60">
                  {formSteps[currentStep].description}
                </p>
              </div>
              <div className="shrink-0 rounded-md bg-brand-green/10 px-2.5 py-1 text-xs font-bold text-brand-green dark:bg-brand-gold/15 dark:text-brand-gold">
                Step {currentStep + 1} of {formSteps.length}
              </div>
            </div>
            <div className="mt-4 h-1.5 overflow-hidden rounded-full bg-emerald-900/10 dark:bg-white/10">
              <div
                className="h-full rounded-full bg-brand-green transition-all duration-300 dark:bg-brand-gold"
                style={{ width: `${((currentStep + 1) / formSteps.length) * 100}%` }}
              />
            </div>

            <AnimatePresence>
              {notice ? (
                <motion.div
                  animate={{ opacity: 1, y: 0 }}
                  className="mt-5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm font-medium text-red-700 dark:border-red-400/20 dark:bg-red-400/10 dark:text-red-200"
                  exit={{ opacity: 0, y: -8 }}
                  initial={{ opacity: 0, y: -8 }}
                >
                  {notice}
                </motion.div>
              ) : null}
            </AnimatePresence>

            <form className="mt-6 grid gap-5" onSubmit={handleSubmit}>
              {currentStep === 0 ? (
                <div className="grid gap-5 sm:grid-cols-2">
                  <TextField
                    error={errors.applicantId}
                    label="Applicant ID"
                    mono
                    name="applicantId"
                    onChange={updateField}
                    value={form.applicantId}
                  />
                  <TextField
                    error={errors.firstName}
                    label="First Name"
                    name="firstName"
                    onChange={updateField}
                    value={form.firstName}
                  />
                  <TextField
                    error={errors.lastName}
                    label="Last Name"
                    name="lastName"
                    onChange={updateField}
                    value={form.lastName}
                  />
                  <TextField
                    error={errors.email}
                    label="Email Address"
                    name="email"
                    onChange={updateField}
                    type="email"
                    value={form.email}
                  />
                  <TextField
                    error={errors.phone}
                    label="Phone Number"
                    mono
                    name="phone"
                    onChange={updateField}
                    placeholder="08012345678"
                    value={form.phone}
                  />
                  <SelectField
                    error={errors.gender}
                    label="Gender"
                    name="gender"
                    onChange={updateField}
                    options={["Female", "Male", "Prefer not to say"]}
                    value={form.gender}
                  />
                  <SelectField
                    error={errors.state}
                    label="State"
                    name="state"
                    onChange={updateField}
                    options={states}
                    value={form.state}
                  />
                  <TextField
                    error={errors.lga}
                    label="LGA"
                    name="lga"
                    onChange={updateField}
                    value={form.lga}
                  />
                  <TextField
                    error={errors.age}
                    label="Age"
                    mono
                    name="age"
                    onChange={updateField}
                    type="number"
                    value={form.age}
                  />
                </div>
              ) : null}

              {currentStep === 1 ? (
                <div className="grid gap-5 sm:grid-cols-2">
                  <SelectField
                    error={errors.highestEducation}
                    label="Highest Education"
                    name="highestEducation"
                    onChange={updateField}
                    options={educationOptions}
                    value={form.highestEducation}
                  />
                  <SelectField
                    error={errors.employmentStatus}
                    label="Employment Status"
                    name="employmentStatus"
                    onChange={updateField}
                    options={employmentOptions}
                    value={form.employmentStatus}
                  />
                  <SelectField
                    error={errors.preferredDigitalSkill}
                    label="Preferred Digital Skill"
                    name="preferredDigitalSkill"
                    onChange={updateField}
                    options={digitalSkills}
                    value={form.preferredDigitalSkill}
                  />
                  <TextField
                    error={errors.currentOccupation}
                    label="Current Occupation"
                    name="currentOccupation"
                    onChange={updateField}
                    value={form.currentOccupation}
                  />
                  <SelectField
                    error={errors.ownsLaptop}
                    label="Do you own a laptop?"
                    name="ownsLaptop"
                    onChange={updateField}
                    options={["Yes", "No"]}
                    value={form.ownsLaptop}
                  />
                  <SelectField
                    error={errors.internetAvailability}
                    label="Internet Availability"
                    name="internetAvailability"
                    onChange={updateField}
                    options={["Reliable", "Occasional", "Limited", "None"]}
                    value={form.internetAvailability}
                  />
                  <TextField
                    error={errors.socialFollowers}
                    label="Number of Social Media Followers"
                    mono
                    name="socialFollowers"
                    onChange={updateField}
                    type="number"
                    value={form.socialFollowers}
                  />
                  <div className="sm:col-span-2">
                    <TextAreaField
                      error={errors.motivation}
                      label="Why do you want to learn this skill?"
                      name="motivation"
                      onChange={updateField}
                      value={form.motivation}
                    />
                  </div>
                </div>
              ) : null}

              {currentStep === 2 ? (
                <div className="grid gap-5 sm:grid-cols-2">
                  <TextField
                    error={errors.facebookProfile}
                    label="Facebook Profile"
                    name="facebookProfile"
                    onChange={updateField}
                    required={false}
                    value={form.facebookProfile}
                  />
                  <TextField
                    error={errors.xProfile}
                    label="X (Twitter) Profile"
                    name="xProfile"
                    onChange={updateField}
                    required={false}
                    value={form.xProfile}
                  />
                  <TextField
                    error={errors.linkedInProfile}
                    label="LinkedIn Profile"
                    name="linkedInProfile"
                    onChange={updateField}
                    required={false}
                    value={form.linkedInProfile}
                  />
                  <TextField
                    error={errors.emergencyContactName}
                    label="Emergency Contact Name"
                    name="emergencyContactName"
                    onChange={updateField}
                    value={form.emergencyContactName}
                  />
                  <TextField
                    error={errors.emergencyContactPhone}
                    label="Emergency Contact Phone"
                    mono
                    name="emergencyContactPhone"
                    onChange={updateField}
                    value={form.emergencyContactPhone}
                  />
                  <label className="flex items-start gap-3 rounded-lg border border-emerald-900/10 bg-white/70 p-4 text-sm font-medium text-brand-ink dark:border-white/10 dark:bg-white/10 dark:text-white sm:col-span-2">
                    <input
                      checked={form.confirmation}
                      className="mt-1 rounded border-emerald-900/20 text-brand-green focus:ring-brand-green"
                      onChange={(event) => updateField("confirmation", event.target.checked)}
                      type="checkbox"
                    />
                    <span>
                      I confirm that every piece of information provided is accurate.
                      {errors.confirmation ? (
                        <span className="error-text block">{errors.confirmation}</span>
                      ) : null}
                    </span>
                  </label>
                </div>
              ) : null}

              <div className="flex flex-col gap-3 border-t border-emerald-900/10 pt-5 dark:border-white/10 sm:flex-row sm:items-center sm:justify-between">
                <div className="text-xs font-medium text-emerald-950/55 dark:text-white/50">
                  Step {currentStep + 1} of {formSteps.length}
                </div>
                <div className="flex flex-col gap-3 sm:flex-row">
                  {currentStep > 0 ? (
                    <button
                      className="inline-flex min-h-11 items-center justify-center rounded-md border border-emerald-900/15 bg-white px-6 text-sm font-bold text-brand-ink transition hover:border-brand-green hover:text-brand-green dark:border-white/10 dark:bg-white/5 dark:text-white"
                      onClick={() => setCurrentStep((step) => Math.max(0, step - 1))}
                      type="button"
                    >
                      Back
                    </button>
                  ) : null}
                  <button
                    className="inline-flex min-h-11 items-center justify-center gap-2 rounded-md bg-brand-green px-6 text-sm font-bold text-white transition hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-60"
                    disabled={isBusy || (isFinalStep && !csrfToken)}
                    type="submit"
                  >
                    {isFinalStep
                      ? status === "idle"
                        ? "Continue to Payment"
                        : statusLabel(status)
                      : "Next Step"}
                    {isFinalStep ? (
                      status === "idle" ? (
                        <ArrowRight size={18} />
                      ) : (
                        <CheckCircle2 size={18} />
                      )
                    ) : (
                      <ArrowRight size={18} />
                    )}
                  </button>
                </div>
              </div>
            </form>
          </section>
        </div>

        <footer className="mt-6 flex flex-col items-center gap-1 border-t border-emerald-900/10 pt-4 text-center text-[11px] text-emerald-950/50 dark:border-white/10 dark:text-white/40">
          <p className="flex items-center gap-1.5">
            <Lock size={12} /> Payments secured by Paystack &middot; TLS encrypted
          </p>
          <p>Digital Skills Laptop Support Program &middot; support@mspaceapp.com</p>
        </footer>
      </main>
    </>
  );
}

function ProcessStep({ index, label, state }: { index: string; label: string; state: ProcessStepState }) {
  const isDone = state === "done";
  const isCurrent = state === "current";

  return (
    <div className="flex shrink-0 items-center gap-2">
      <span
        className={
          "flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-[10px] font-bold " +
          (isDone
            ? "bg-brand-green text-white"
            : isCurrent
            ? "border-2 border-brand-green text-brand-green dark:border-brand-gold dark:text-brand-gold"
            : "border border-emerald-900/20 text-emerald-950/40 dark:border-white/20 dark:text-white/40")
        }
      >
        {isDone ? <CheckCircle2 size={13} /> : index}
      </span>
      <span
        className={
          "whitespace-nowrap text-[11px] font-semibold " +
          (isCurrent
            ? "text-brand-ink dark:text-white"
            : isDone
            ? "text-emerald-950/60 dark:text-white/50"
            : "text-emerald-950/35 dark:text-white/30")
        }
      >
        {label}
      </span>
    </div>
  );
}

function RefCell({
  label,
  value,
  mono = false,
  icon
}: {
  label: string;
  value: string;
  mono?: boolean;
  icon?: React.ReactNode;
}) {
  return (
    <div className="px-3 py-2.5 sm:px-4">
      <p className="text-[9px] font-bold uppercase tracking-[0.16em] text-emerald-950/45 dark:text-white/40">
        {label}
      </p>
      <p
        className={
          "mt-0.5 flex items-center gap-1.5 truncate text-xs font-bold text-brand-ink dark:text-white sm:text-sm " +
          (mono ? "font-mono" : "")
        }
      >
        {icon}
        {value}
      </p>
    </div>
  );
}

function RequirementItem({ text }: { text: string }) {
  return (
    <li className="flex items-start gap-2.5">
      <CheckCircle2 size={15} className="mt-0.5 shrink-0 text-brand-green dark:text-brand-gold" />
      <span>{text}</span>
    </li>
  );
}

function workingStatusTitle(status: "idle" | "saving" | "checkout" | "verifying") {
  switch (status) {
    case "saving":
      return "Saving your application";
    case "checkout":
      return "Opening secure payment";
    case "verifying":
      return "Verifying your payment";
    default:
      return "Working on your request";
  }
}

function workingStatusDescription(status: "idle" | "saving" | "checkout" | "verifying") {
  switch (status) {
    case "saving":
      return "We are preparing your application details and generating your payment reference.";
    case "checkout":
      return "Please wait while we launch Paystack securely.";
    case "verifying":
      return "Your payment was successful. We are confirming it now and updating your record.";
    default:
      return "We are processing your request.";
  }
}

function statusLabel(status: "idle" | "saving" | "checkout" | "verifying") {
  switch (status) {
    case "saving":
      return "Saving application";
    case "checkout":
      return "Opening checkout";
    case "verifying":
      return "Verifying payment";
    default:
      return "Continue to Payment";
  }
}

function TextField({
  error,
  label,
  mono = false,
  name,
  onChange,
  placeholder,
  required = true,
  type = "text",
  value
}: {
  error?: string;
  label: string;
  mono?: boolean;
  name: keyof ApplicantForm;
  onChange: (field: keyof ApplicantForm, value: string) => void;
  placeholder?: string;
  required?: boolean;
  type?: string;
  value: string;
}) {
  return (
    <label>
      <span className="field-label">
        {label}
        {required ? null : (
          <span className="font-normal text-emerald-950/50 dark:text-white/50">
            {" "}
            optional
          </span>
        )}
      </span>
      <input
        className={"input-base" + (mono ? " font-mono" : "")}
        name={name}
        onChange={(event: ChangeEvent<HTMLInputElement>) =>
          onChange(name, event.target.value)
        }
        placeholder={placeholder}
        type={type}
        value={value}
      />
      {error ? <p className="error-text">{error}</p> : null}
    </label>
  );
}

function SelectField({
  error,
  label,
  name,
  onChange,
  options,
  value
}: {
  error?: string;
  label: string;
  name: keyof ApplicantForm;
  onChange: (field: keyof ApplicantForm, value: string) => void;
  options: string[];
  value: string;
}) {
  return (
    <label>
      <span className="field-label">{label}</span>
      <select
        className="input-base"
        name={name}
        onChange={(event: ChangeEvent<HTMLSelectElement>) =>
          onChange(name, event.target.value)
        }
        value={value}
      >
        <option value="">Select</option>
        {options.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
      {error ? <p className="error-text">{error}</p> : null}
    </label>
  );
}

function TextAreaField({
  error,
  label,
  name,
  onChange,
  value
}: {
  error?: string;
  label: string;
  name: keyof ApplicantForm;
  onChange: (field: keyof ApplicantForm, value: string) => void;
  value: string;
}) {
  return (
    <label>
      <span className="field-label">{label}</span>
      <textarea
        className="input-base min-h-32 resize-y"
        name={name}
        onChange={(event: ChangeEvent<HTMLTextAreaElement>) =>
          onChange(name, event.target.value)
        }
        value={value}
      />
      {error ? <p className="error-text">{error}</p> : null}
    </label>
  );
}

function LoadingExperience() {
  return (
    <main className="mx-auto min-h-screen max-w-6xl px-4 py-6 sm:px-6">
      <div className="skeleton h-14 w-full rounded-lg" />
      <div className="skeleton mt-4 h-10 w-full rounded-lg" />
      <div className="mt-6 grid gap-6 lg:grid-cols-[0.85fr_1.15fr]">
        <div className="hidden skeleton h-64 rounded-xl lg:block" />
        <div className="skeleton h-96 rounded-xl" />
      </div>
    </main>
  );
}
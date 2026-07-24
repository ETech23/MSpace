"use client";

import { AnimatePresence, motion } from "framer-motion";
import {
  ArrowRight,
  CheckCircle2,
  CreditCard,
  GraduationCap,
  ShieldCheck,
  Sparkles,
  type LucideIcon
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

const heroStats: Array<{ label: string; value: string; Icon: LucideIcon }> = [
  { label: "Fee", value: "NGN 1,000", Icon: CreditCard },
  { label: "Stage", value: "Verification", Icon: ShieldCheck },
  { label: "Status", value: "Shortlisted", Icon: GraduationCap }
];

export function Stage2Application() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [form, setForm] = useState<ApplicantForm>(initialApplicantForm);
  const [errors, setErrors] = useState<Record<string, string>>({});
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

  const isBusy = status !== "idle";
  const sanitizedForm = useMemo(() => sanitizeApplicantForm(form), [form]);

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

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setNotice("");

    const validationErrors = validateApplicantForm(sanitizedForm);
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors);
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
            className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 px-4 py-6 backdrop-blur-md"
            exit={{ opacity: 0 }}
            initial={{ opacity: 0 }}
            role="alertdialog"
            aria-live="assertive"
            aria-busy="true"
          >
            <motion.div
              animate={{ y: 0, scale: 1, opacity: 1 }}
              className="w-full max-w-md rounded-3xl border border-white/15 bg-[#08130f]/95 p-7 text-center text-white shadow-2xl shadow-black/40"
              initial={{ y: 18, scale: 0.98, opacity: 0 }}
              transition={{ duration: 0.22 }}
            >
              <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-brand-gold/15 text-brand-gold">
                <motion.div
                  animate={{ rotate: 360 }}
                  className="h-8 w-8 rounded-full border-4 border-brand-gold/25 border-t-brand-gold"
                  transition={{ repeat: Infinity, ease: "linear", duration: 0.9 }}
                />
              </div>
              <p className="mt-5 text-xs font-bold uppercase tracking-[0.3em] text-brand-gold/90">
                Please wait
              </p>
              <h3 className="mt-3 text-2xl font-black">
                {workingStatusTitle(status)}
              </h3>
              <p className="mt-3 text-sm leading-6 text-white/75">
                {workingStatusDescription(status)}
              </p>
              <div className="mt-6 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-left text-sm text-white/85">
                Do not refresh or close this page while we finish preparing your
                payment.
              </div>
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      <main className="mx-auto grid min-h-screen max-w-7xl gap-7 px-4 py-5 sm:px-6 md:grid-cols-[0.92fr_1.08fr] md:px-8 md:py-8">
        <section className="flex flex-col gap-5">
          <div className="flex items-center justify-between">
            <div className="inline-flex items-center gap-2 rounded-full border border-brand-green/20 bg-white/80 px-4 py-2 text-xs font-bold uppercase tracking-wide text-brand-green dark:border-white/10 dark:bg-white/10 dark:text-brand-gold">
              <Sparkles size={15} />
              Stage 2 Verification
            </div>
            <ThemeToggle />
          </div>

        <motion.div
          animate={{ opacity: 1, y: 0 }}
          className="glass-panel overflow-hidden rounded-2xl"
          initial={{ opacity: 0, y: 18 }}
          transition={{ duration: 0.45 }}
        >
          <div className="relative min-h-[34rem] overflow-hidden bg-[linear-gradient(135deg,rgba(15,122,74,0.95),rgba(20,33,27,0.94)),url('/hero-pattern.svg')] bg-cover p-7 text-white sm:p-9">
            <div className="absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-black/30 to-transparent" />
            <div className="relative z-10 flex h-full flex-col justify-between gap-10">
              <div>
                <p className="text-sm font-semibold uppercase tracking-wide text-brand-gold">
                  Digital Skills Laptop Support Program
                </p>
                <h1 className="mt-5 max-w-lg text-4xl font-black leading-tight sm:text-5xl">
                  Congratulations!
                </h1>
                <p className="mt-5 max-w-xl text-base leading-7 text-white/90">
                  After reviewing your Stage 1 application, you have successfully
                  progressed to the next phase. Complete the verification form
                  and pay the NGN 1,000 Application Processing Fee.
                </p>
              </div>

              <div className="grid gap-3 sm:grid-cols-3">
                {heroStats.map(({ label, value, Icon }) => (
                  <div
                    className="rounded-xl border border-white/20 bg-white/10 p-4 backdrop-blur-md"
                    key={label}
                  >
                    <Icon className="text-brand-gold" size={21} />
                    <p className="mt-3 text-xs uppercase tracking-wide text-white/70">
                      {label}
                    </p>
                    <p className="mt-1 text-sm font-bold text-white">{value}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </motion.div>
        </section>

        <motion.section
          animate={{ opacity: 1, y: 0 }}
          className="glass-panel rounded-2xl p-5 sm:p-7"
          initial={{ opacity: 0, y: 18 }}
          transition={{ delay: 0.1, duration: 0.45 }}
        >
        <div className="flex flex-col gap-3 border-b border-emerald-900/10 pb-5 dark:border-white/10 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-2xl font-black text-brand-ink dark:text-white">
              Verification form
            </h2>
            <p className="mt-1 text-sm text-emerald-950/70 dark:text-white/60">
              Your Applicant ID is filled automatically when it is present in
              the email link.
            </p>
          </div>
          <div className="rounded-lg bg-brand-gold/20 px-4 py-2 text-sm font-bold text-brand-ink dark:text-brand-gold">
            Secure checkout
          </div>
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
          <div className="grid gap-5 sm:grid-cols-2">
            <TextField
              error={errors.applicantId}
              label="Applicant ID"
              name="applicantId"
              onChange={updateField}
              value={form.applicantId}
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
              error={errors.phone}
              label="Phone Number"
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
              name="age"
              onChange={updateField}
              type="number"
              value={form.age}
            />
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
              name="socialFollowers"
              onChange={updateField}
              type="number"
              value={form.socialFollowers}
            />
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
              name="emergencyContactPhone"
              onChange={updateField}
              value={form.emergencyContactPhone}
            />
          </div>

          <TextAreaField
            error={errors.motivation}
            label="Why do you want to learn this skill?"
            name="motivation"
            onChange={updateField}
            value={form.motivation}
          />

          <label className="flex items-start gap-3 rounded-xl border border-emerald-900/10 bg-white/70 p-4 text-sm font-medium text-brand-ink dark:border-white/10 dark:bg-white/10 dark:text-white">
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

          <button
            className="inline-flex min-h-12 items-center justify-center gap-2 rounded-lg bg-brand-green px-6 py-3 text-sm font-black text-white shadow-lg shadow-emerald-900/20 transition hover:-translate-y-0.5 hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-65"
            disabled={isBusy || !csrfToken}
            type="submit"
          >
            {status === "idle" ? "Continue to Payment" : statusLabel(status)}
            {status === "idle" ? <ArrowRight size={18} /> : <CheckCircle2 size={18} />}
          </button>
        </form>
        </motion.section>
      </main>
    </>
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
  name,
  onChange,
  placeholder,
  required = true,
  type = "text",
  value
}: {
  error?: string;
  label: string;
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
        className="input-base"
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
    <main className="mx-auto grid min-h-screen max-w-6xl gap-8 px-5 py-8 md:grid-cols-[0.9fr_1.1fr]">
      <section className="glass-panel rounded-2xl p-7">
        <div className="skeleton h-7 w-40" />
        <div className="skeleton mt-10 h-14 w-4/5" />
        <div className="skeleton mt-5 h-24 w-full" />
      </section>
      <section className="glass-panel rounded-2xl p-7">
        <div className="skeleton h-8 w-2/3" />
        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          {Array.from({ length: 12 }).map((_, index) => (
            <div className="skeleton h-14" key={index} />
          ))}
        </div>
      </section>
    </main>
  );
}

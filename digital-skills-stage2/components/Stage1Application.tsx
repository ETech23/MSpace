"use client";

import { AnimatePresence, motion } from "framer-motion";
import {
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  ClipboardCheck,
  GraduationCap,
  ShieldCheck,
  Sparkles,
  type LucideIcon
} from "lucide-react";
import { useRouter } from "next/navigation";
import { ChangeEvent, FormEvent, useEffect, useMemo, useState } from "react";
import { createStage1Application, getCsrfToken } from "../lib/api";
import {
  initialStage1Form,
  sanitizeStage1Form,
  stage1Options,
  stage1Steps,
  type Stage1Form,
  toStage1Payload,
  validateStage1Form,
  wordCount
} from "../lib/stage1";
import { states } from "../lib/application";
import { ThemeToggle } from "./ThemeToggle";

type SubmissionStatus = "idle" | "loading" | "submitting";

const draftKey = "stage1-application-draft-v1";
const receiptKey = "stage1-application-receipt-v1";

const highlightCards: Array<{ label: string; value: string; Icon: LucideIcon }> = [
  { label: "Stage", value: "Stage 1 Application", Icon: ShieldCheck },
  { label: "Review", value: "Shortlisting begins after submission", Icon: ClipboardCheck },
  { label: "Outcome", value: "Qualified applicants move to Stage 2", Icon: GraduationCap }
];

export function Stage1Application() {
  const router = useRouter();
  const [form, setForm] = useState<Stage1Form>(initialStage1Form);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [currentStep, setCurrentStep] = useState(0);
  const [csrfToken, setCsrfToken] = useState("");
  const [notice, setNotice] = useState("");
  const [status, setStatus] = useState<SubmissionStatus>("loading");
  const [hydrated, setHydrated] = useState(false);

  const sanitizedForm = useMemo(() => sanitizeStage1Form(form), [form]);
  const isFinalStep = currentStep === stage1Steps.length - 1;

  useEffect(() => {
    const storedDraft = window.localStorage.getItem(draftKey);

    if (storedDraft) {
      try {
        const parsed = JSON.parse(storedDraft) as {
          form?: Partial<Stage1Form>;
          currentStep?: number;
        };

        if (parsed.form) {
          setForm((current) => ({ ...current, ...parsed.form }));
        }

        if (typeof parsed.currentStep === "number") {
          setCurrentStep(Math.min(Math.max(parsed.currentStep, 0), stage1Steps.length - 1));
        }

        setNotice("Draft restored from this browser.");
      } catch {
        window.localStorage.removeItem(draftKey);
      }
    }

    getCsrfToken()
      .then(setCsrfToken)
      .catch((error: Error) => setNotice(error.message))
      .finally(() => {
        setStatus("idle");
        setHydrated(true);
      });
  }, []);

  useEffect(() => {
    if (!hydrated) {
      return;
    }

    const timeout = window.setTimeout(() => {
      window.localStorage.setItem(
        draftKey,
        JSON.stringify({ form: sanitizedForm, currentStep })
      );
    }, 250);

    return () => window.clearTimeout(timeout);
  }, [currentStep, hydrated, sanitizedForm]);

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, [currentStep]);

  useEffect(() => {
    if (notice) {
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }, [notice]);

  function setField(field: keyof Stage1Form, value: string | boolean) {
    setForm((current) => ({ ...current, [field]: value }));
    setErrors((current) => {
      const next = { ...current };
      delete next[field];
      return next;
    });
  }

  function getStepErrors(validationErrors: Record<string, string>, stepIndex: number) {
    const fields = (stage1Steps[stepIndex]?.fields ?? []) as readonly (keyof Stage1Form)[];
    return Object.fromEntries(
      Object.entries(validationErrors).filter(([field]) =>
        fields.includes(field as keyof Stage1Form)
      )
    );
  }

  function goBack() {
    setErrors({});
    setCurrentStep((step) => Math.max(step - 1, 0));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setNotice("");

    const validationErrors = validateStage1Form(sanitizedForm);
    const stepErrors = isFinalStep
      ? validationErrors
      : getStepErrors(validationErrors, currentStep);

    if (Object.keys(stepErrors).length > 0) {
      setErrors(stepErrors);
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }

    if (!isFinalStep) {
      setErrors({});
      setCurrentStep((step) => Math.min(step + 1, stage1Steps.length - 1));
      return;
    }

    try {
      setStatus("submitting");
      const response = await createStage1Application(toStage1Payload(sanitizedForm), csrfToken);
      const receipt = {
        ...response,
        email: sanitizedForm.email,
        firstName: sanitizedForm.firstName,
        lastName: sanitizedForm.lastName,
        submittedAt: response.submittedAt
      };
      window.sessionStorage.setItem("stage1-application", JSON.stringify(receipt));
      window.sessionStorage.setItem(receiptKey, JSON.stringify(receipt));
      window.localStorage.removeItem(draftKey);
      router.push(`/apply/success?applicantId=${encodeURIComponent(response.applicantId)}`);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Unable to submit application");
      setStatus("idle");
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }

  function updateTextarea(
    field: keyof Stage1Form,
    event: ChangeEvent<HTMLTextAreaElement | HTMLInputElement | HTMLSelectElement>
  ) {
    setField(field, event.target.value);
  }

  if (status === "loading") {
    return <LoadingView />;
  }

  return (
    <main className="mx-auto min-h-screen max-w-7xl px-4 py-5 sm:px-6 lg:px-8 lg:py-8">
      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <p className="inline-flex items-center gap-2 rounded-full bg-brand-green/10 px-3 py-1 text-xs font-bold uppercase tracking-[0.28em] text-brand-green dark:bg-white/10 dark:text-brand-gold">
            <Sparkles size={14} />
            Digital Skills Program
          </p>
          <h1 className="mt-3 text-3xl font-black tracking-tight text-brand-ink dark:text-white sm:text-4xl">
            Digital Skills Laptop Support Program
          </h1>
          <p className="mt-3 max-w-2xl text-sm leading-6 text-emerald-950/70 dark:text-white/70">
            Stage 1 application form. Complete this carefully so we can review your
            background, digital interests, and readiness for the program.
          </p>
        </div>
        <ThemeToggle />
      </div>

      <section className={`grid gap-6 ${currentStep === 0 ? "lg:grid-cols-[1fr_1.45fr]" : "lg:grid-cols-1"}`}>
        {currentStep === 0 ? (
          <motion.aside
            animate={{ opacity: 1, y: 0 }}
            className="glass-panel rounded-3xl p-5 sm:p-6"
            initial={{ opacity: 0, y: 14 }}
          >
            <div className="rounded-2xl border border-emerald-900/10 bg-white/75 p-5 dark:border-white/10 dark:bg-white/10">
              <p className="text-xs font-bold uppercase tracking-[0.3em] text-brand-green dark:text-brand-gold">
                Information notice
              </p>
              <ul className="mt-4 space-y-3 text-sm leading-6 text-emerald-950/80 dark:text-white/75">
                <NoticeItem text="Carefully complete all sections." />
                <NoticeItem text="Only shortlisted applicants will proceed to Stage 2." />
                <NoticeItem text="Please provide accurate and verifiable information." />
              </ul>
            </div>

            <div className="mt-5 grid gap-3 sm:grid-cols-3 lg:grid-cols-1">
              {highlightCards.map(({ label, value, Icon }) => (
                <motion.div
                  animate={{ opacity: 1, x: 0 }}
                  className="rounded-2xl border border-emerald-900/10 bg-white/75 p-4 dark:border-white/10 dark:bg-white/10"
                  key={label}
                  initial={{ opacity: 0, x: -10 }}
                  transition={{ duration: 0.25 }}
                >
                  <div className="flex items-center gap-3">
                    <span className="flex size-10 items-center justify-center rounded-xl bg-brand-green/10 text-brand-green dark:bg-white/10 dark:text-brand-gold">
                      <Icon size={18} />
                    </span>
                    <div>
                      <p className="text-xs font-bold uppercase tracking-wide text-emerald-950/50 dark:text-white/50">
                        {label}
                      </p>
                      <p className="mt-1 text-sm font-black text-brand-ink dark:text-white">
                        {value}
                      </p>
                    </div>
                  </div>
                </motion.div>
              ))}
            </div>

            <div className="mt-5 rounded-2xl border border-brand-gold/30 bg-brand-gold/10 p-5 text-sm text-brand-ink dark:text-brand-gold">
              <p className="font-black uppercase tracking-wide">Autosave enabled</p>
              <p className="mt-2 leading-6">
                Your progress is saved locally in this browser while you complete the
                application.
              </p>
            </div>
          </motion.aside>
        ) : null}

        <motion.section
          animate={{ opacity: 1, y: 0 }}
          className="glass-panel rounded-3xl p-4 sm:p-6 lg:p-7"
          initial={{ opacity: 0, y: 14 }}
        >
          <form onSubmit={handleSubmit}>
            <div className="mb-6 flex flex-col gap-4 border-b border-emerald-900/10 pb-6 dark:border-white/10">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-xs font-bold uppercase tracking-[0.3em] text-brand-green dark:text-brand-gold">
                    Application flow
                  </p>
                  <h2 className="mt-2 text-2xl font-black text-brand-ink dark:text-white">
                    {stage1Steps[currentStep]?.title}
                  </h2>
                  <p className="mt-1 text-sm text-emerald-950/70 dark:text-white/65">
                    {stage1Steps[currentStep]?.description}
                  </p>
                </div>
                <div className="rounded-2xl border border-emerald-900/10 bg-white/80 px-4 py-3 text-right dark:border-white/10 dark:bg-white/10">
                  <p className="text-xs font-bold uppercase tracking-wide text-emerald-950/50 dark:text-white/50">
                    Step
                  </p>
                  <p className="text-lg font-black text-brand-ink dark:text-white">
                    {currentStep + 1}/{stage1Steps.length}
                  </p>
                </div>
              </div>

              <div className="grid gap-2 sm:grid-cols-5">
                {stage1Steps.map((step, index) => {
                  const active = index === currentStep;
                  const complete = index < currentStep;
                  return (
                    <button
                      className={[
                        "rounded-2xl border px-3 py-3 text-left transition",
                        active
                          ? "border-brand-green bg-brand-green/10 text-brand-ink shadow-sm dark:border-brand-gold dark:bg-white/10 dark:text-white"
                          : complete
                            ? "border-emerald-900/15 bg-white/80 text-brand-ink dark:border-white/10 dark:bg-white/10 dark:text-white"
                            : "border-dashed border-emerald-900/10 bg-white/60 text-emerald-950/55 dark:border-white/10 dark:bg-white/5 dark:text-white/40"
                      ].join(" ")}
                      disabled={index > currentStep}
                      key={step.title}
                      onClick={() => setCurrentStep(index)}
                      type="button"
                    >
                      <p className="text-[11px] font-bold uppercase tracking-[0.24em]">
                        {step.title}
                      </p>
                      <p className="mt-1 text-xs leading-5 opacity-80">{step.description}</p>
                    </button>
                  );
                })}
              </div>

              <div className="h-2 overflow-hidden rounded-full bg-emerald-900/10 dark:bg-white/10">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-brand-green to-brand-gold transition-all"
                  style={{ width: `${((currentStep + 1) / stage1Steps.length) * 100}%` }}
                />
              </div>
            </div>

            {notice ? (
              <p className="mb-5 rounded-2xl border border-brand-gold/30 bg-brand-gold/10 px-4 py-3 text-sm font-medium text-brand-ink dark:text-brand-gold">
                {notice}
              </p>
            ) : null}

            <AnimatePresence mode="wait">
              <motion.div
                animate={{ opacity: 1, y: 0 }}
                className="grid gap-5"
                exit={{ opacity: 0, y: -10 }}
                initial={{ opacity: 0, y: 10 }}
                key={currentStep}
                transition={{ duration: 0.25 }}
              >
                {currentStep === 0 ? (
                  <PersonalStep form={form} onChange={updateTextarea} errors={errors} />
                ) : null}
                {currentStep === 1 ? (
                  <EducationStep form={form} onChange={updateTextarea} errors={errors} />
                ) : null}
                {currentStep === 2 ? (
                  <DigitalInterestStep
                    form={form}
                    onChange={updateTextarea}
                    errors={errors}
                  />
                ) : null}
                {currentStep === 3 ? (
                  <DeviceStep form={form} onChange={updateTextarea} errors={errors} />
                ) : null}
                {currentStep === 4 ? (
                  <ReviewStep
                    form={sanitizedForm}
                    onChange={updateTextarea}
                    errors={errors}
                    setField={setField}
                  />
                ) : null}
              </motion.div>
            </AnimatePresence>

            <div className="mt-8 flex flex-col-reverse gap-3 sm:flex-row sm:items-center sm:justify-between">
              <button
                className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-emerald-900/10 bg-white/80 px-5 py-3 text-sm font-bold text-brand-ink transition hover:-translate-y-0.5 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50 dark:border-white/10 dark:bg-white/10 dark:text-white"
                disabled={currentStep === 0 || status !== "idle"}
                onClick={goBack}
                type="button"
              >
                <ArrowLeft size={16} />
                Back
              </button>

              <button
                className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-brand-green px-6 py-3 text-sm font-black text-white shadow-lg shadow-emerald-900/20 transition hover:-translate-y-0.5 hover:shadow-xl disabled:cursor-not-allowed disabled:opacity-60"
                disabled={status !== "idle"}
                type="submit"
              >
                {isFinalStep ? "Submit application" : "Continue"}
                <ArrowRight size={16} />
              </button>
            </div>
          </form>
        </motion.section>
      </section>

      <AnimatePresence>
        {status === "submitting" ? (
          <motion.div
            animate={{ opacity: 1 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/75 px-4 py-6 backdrop-blur-md"
            exit={{ opacity: 0 }}
            initial={{ opacity: 0 }}
            role="alertdialog"
            aria-busy="true"
            aria-live="assertive"
          >
            <motion.div
              animate={{ opacity: 1, y: 0, scale: 1 }}
              className="w-full max-w-md rounded-3xl border border-white/15 bg-[#08130f]/95 p-7 text-center text-white shadow-2xl shadow-black/40"
              initial={{ opacity: 0, y: 18, scale: 0.98 }}
              transition={{ duration: 0.24 }}
            >
              <div className="mx-auto flex size-16 items-center justify-center rounded-full bg-brand-gold/15 text-brand-gold">
                <motion.div
                  animate={{ rotate: 360 }}
                  className="size-8 rounded-full border-4 border-brand-gold/25 border-t-brand-gold"
                  transition={{ repeat: Infinity, ease: "linear", duration: 0.9 }}
                />
              </div>
              <p className="mt-5 text-xs font-bold uppercase tracking-[0.3em] text-brand-gold/90">
                Please wait
              </p>
              <h3 className="mt-3 text-2xl font-black">Submitting your application</h3>
              <p className="mt-3 text-sm leading-6 text-white/75">
                We are saving your application securely and syncing it to the review
                queue. Please do not refresh or close this page.
              </p>
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </main>
  );
}

function PersonalStep({
  form,
  onChange,
  errors
}: {
  form: Stage1Form;
  onChange: (
    field: keyof Stage1Form,
    event: ChangeEvent<HTMLTextAreaElement | HTMLInputElement | HTMLSelectElement>
  ) => void;
  errors: Record<string, string>;
}) {
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <TextField name="firstName" label="First Name" value={form.firstName} onChange={onChange} error={errors.firstName} placeholder="Ada" />
      <TextField name="lastName" label="Last Name" value={form.lastName} onChange={onChange} error={errors.lastName} placeholder="Okafor" />
      <TextField name="email" label="Email Address" type="email" value={form.email} onChange={onChange} error={errors.email} placeholder="you@example.com" />
      <TextField name="phone" label="Phone Number" type="tel" value={form.phone} onChange={onChange} error={errors.phone} placeholder="08012345678" />
      <SelectField name="gender" label="Gender" value={form.gender} onChange={onChange} error={errors.gender} options={["Select gender", ...stage1Options.genders]} />
      <TextField name="age" label="Age" type="number" value={form.age} onChange={onChange} error={errors.age} placeholder="18" />
      <SelectField name="state" label="State" value={form.state} onChange={onChange} error={errors.state} options={["Select state", ...states]} />
      <TextField name="lga" label="LGA" value={form.lga} onChange={onChange} error={errors.lga} placeholder="Ikeja" />
    </div>
  );
}

function EducationStep({
  form,
  onChange,
  errors
}: {
  form: Stage1Form;
  onChange: (
    field: keyof Stage1Form,
    event: ChangeEvent<HTMLTextAreaElement | HTMLInputElement | HTMLSelectElement>
  ) => void;
  errors: Record<string, string>;
}) {
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <SelectField name="highestQualification" label="Highest Qualification" value={form.highestQualification} onChange={onChange} error={errors.highestQualification} options={["Select qualification", ...stage1Options.qualifications]} />
      <SelectField name="employmentStatus" label="Employment Status" value={form.employmentStatus} onChange={onChange} error={errors.employmentStatus} options={["Select employment status", ...stage1Options.employmentStatuses]} />
      <TextField name="currentOccupation" label="Current Occupation" value={form.currentOccupation} onChange={onChange} error={errors.currentOccupation} placeholder="Student, designer, etc." />
    </div>
  );
}

function DigitalInterestStep({
  form,
  onChange,
  errors
}: {
  form: Stage1Form;
  onChange: (
    field: keyof Stage1Form,
    event: ChangeEvent<HTMLTextAreaElement | HTMLInputElement | HTMLSelectElement>
  ) => void;
  errors: Record<string, string>;
}) {
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <SelectField name="primarySkill" label="Primary Skill" value={form.primarySkill} onChange={onChange} error={errors.primarySkill} options={["Select skill", ...stage1Options.digitalSkills]} />
      <TextField name="secondarySkill" label="Secondary Skill (Optional)" value={form.secondarySkill} onChange={onChange} error={errors.secondarySkill} placeholder="Optional secondary interest" />
      <SelectField name="experienceLevel" label="Experience Level" value={form.experienceLevel} onChange={onChange} error={errors.experienceLevel} options={["Select level", ...stage1Options.experienceLevels]} />
      <SelectField name="startedLearning" label="Have you started learning?" value={form.startedLearning} onChange={onChange} error={errors.startedLearning} options={["Select answer", ...stage1Options.yesNo]} />
      {form.startedLearning === "Yes" ? (
        <>
          <SelectField name="learningPlatform" label="Where are you learning?" value={form.learningPlatform} onChange={onChange} error={errors.learningPlatform} options={["Select platform", ...stage1Options.learningPlatforms]} />
          {form.learningPlatform === "Other" ? (
            <TextField name="learningPlatformOther" label="Other Learning Platform" value={form.learningPlatformOther} onChange={onChange} error={errors.learningPlatformOther} placeholder="Tell us where you are learning" />
          ) : null}
        </>
      ) : null}
      <TextAreaField name="whyDigitalSkills" label="Why do you want to learn digital skills?" value={form.whyDigitalSkills} onChange={onChange} error={errors.whyDigitalSkills} rows={5} placeholder="Explain your motivation and goals." helper={`Maximum 400 words • ${wordCount(form.whyDigitalSkills)} words used`} />
      <div className="sm:col-span-2 rounded-2xl border border-brand-gold/25 bg-brand-gold/10 p-4 text-sm leading-6 text-brand-ink dark:text-brand-gold">
        <p className="font-black">Tip</p>
        <p className="mt-2">
          Keep your answers specific. We review clarity, readiness, and how well
          the program fits your goals.
        </p>
      </div>
    </div>
  );
}

function DeviceStep({
  form,
  onChange,
  errors
}: {
  form: Stage1Form;
  onChange: (
    field: keyof Stage1Form,
    event: ChangeEvent<HTMLTextAreaElement | HTMLInputElement | HTMLSelectElement>
  ) => void;
  errors: Record<string, string>;
}) {
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <SelectField name="ownsLaptop" label="Do you currently own a laptop?" value={form.ownsLaptop} onChange={onChange} error={errors.ownsLaptop} options={["Select answer", ...stage1Options.yesNo]} />
      <SelectField name="internetAvailability" label="Internet Availability" value={form.internetAvailability} onChange={onChange} error={errors.internetAvailability} options={["Select availability", ...stage1Options.internetAvailability]} />
      <TextField name="dailyDataBudget" label="Daily Data Budget" value={form.dailyDataBudget} onChange={onChange} error={errors.dailyDataBudget} placeholder="e.g. NGN 500/day" />
      <TextField name="internetProvider" label="Internet Provider" value={form.internetProvider} onChange={onChange} error={errors.internetProvider} placeholder="MTN, Airtel, Glo..." />
      {form.ownsLaptop === "Yes" ? (
        <>
          <SelectField name="laptopCondition" label="Laptop Condition" value={form.laptopCondition} onChange={onChange} error={errors.laptopCondition} options={["Select condition", ...stage1Options.laptopConditions]} />
          <TextField name="ram" label="RAM" value={form.ram} onChange={onChange} error={errors.ram} placeholder="4GB, 8GB, 16GB..." />
          <TextField name="storage" label="Storage" value={form.storage} onChange={onChange} error={errors.storage} placeholder="128GB SSD..." />
          <SelectField name="operatingSystem" label="Operating System" value={form.operatingSystem} onChange={onChange} error={errors.operatingSystem} options={["Select OS", ...stage1Options.operatingSystems]} />
        </>
      ) : null}
    </div>
  );
}

function ReviewStep({
  form,
  onChange,
  errors,
  setField
}: {
  form: Stage1Form;
  onChange: (
    field: keyof Stage1Form,
    event: ChangeEvent<HTMLTextAreaElement | HTMLInputElement | HTMLSelectElement>
  ) => void;
  errors: Record<string, string>;
  setField: (field: keyof Stage1Form, value: string | boolean) => void;
}) {
  return (
    <div className="grid gap-5">
      <div className="grid gap-4 sm:grid-cols-2">
        <TextField name="facebookProfile" label="Facebook Profile" value={form.facebookProfile} onChange={onChange} error={errors.facebookProfile} placeholder="https://facebook.com/..." />
        <TextField name="instagramProfile" label="Instagram Profile" value={form.instagramProfile} onChange={onChange} error={errors.instagramProfile} placeholder="https://instagram.com/..." />
        <TextField name="linkedInProfile" label="LinkedIn Profile" value={form.linkedInProfile} onChange={onChange} error={errors.linkedInProfile} placeholder="https://linkedin.com/in/..." />
        <TextField name="xProfile" label="X (Twitter) Profile" value={form.xProfile} onChange={onChange} error={errors.xProfile} placeholder="https://x.com/..." />
        <TextField name="tiktokProfile" label="TikTok Profile" value={form.tiktokProfile} onChange={onChange} error={errors.tiktokProfile} placeholder="https://tiktok.com/..." />
        <TextField name="totalFollowers" label="Total Followers" type="number" value={form.totalFollowers} onChange={onChange} error={errors.totalFollowers} placeholder="0" />
        <SelectField name="referralSource" label="How did you hear about this program?" value={form.referralSource} onChange={onChange} error={errors.referralSource} options={["Select source", ...stage1Options.referralSources]} />
        {form.referralSource === "Other" ? (
          <TextField name="referralCode" label="Referral Code / Note" value={form.referralCode} onChange={onChange} error={errors.referralCode} placeholder="Tell us how you found us" />
        ) : null}
      </div>

      <div className="rounded-3xl border border-emerald-900/10 bg-white/80 p-5 dark:border-white/10 dark:bg-white/10">
        <p className="text-xs font-bold uppercase tracking-[0.3em] text-brand-green dark:text-brand-gold">
          Application summary
        </p>
        <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          <SummaryValue label="Name" value={`${form.firstName} ${form.lastName}`.trim()} />
          <SummaryValue label="Email" value={form.email} />
          <SummaryValue label="Phone" value={form.phone} />
          <SummaryValue label="State / LGA" value={`${form.state} / ${form.lga}`.trim()} />
          <SummaryValue label="Primary Skill" value={form.primarySkill} />
          <SummaryValue label="Laptop" value={form.ownsLaptop} />
        </div>
      </div>

      <div className="grid gap-3">
        <DeclarationCheckbox
          checked={form.accurateInformation}
          error={errors.accurateInformation}
          label="I certify that the information provided is accurate."
          onChange={(checked) => setField("accurateInformation", checked)}
        />
        <DeclarationCheckbox
          checked={form.understandNotGuarantee}
          error={errors.understandNotGuarantee}
          label="I understand that submitting this application does not guarantee selection."
          onChange={(checked) => setField("understandNotGuarantee", checked)}
        />
        <DeclarationCheckbox
          checked={form.consentToContact}
          error={errors.consentToContact}
          label="I consent to being contacted regarding this application."
          onChange={(checked) => setField("consentToContact", checked)}
        />
      </div>
    </div>
  );
}

function TextField({
  name,
  label,
  value,
  onChange,
  error,
  placeholder,
  type = "text"
}: {
  name: keyof Stage1Form;
  label: string;
  value: string;
  onChange: (
    field: keyof Stage1Form,
    event: ChangeEvent<HTMLTextAreaElement | HTMLInputElement | HTMLSelectElement>
  ) => void;
  error?: string;
  placeholder?: string;
  type?: string;
}) {
  return (
    <label className="block">
      <span className="field-label">{label}</span>
      <input
        className="input-base"
        onChange={(event) => onChange(name, event)}
        placeholder={placeholder}
        type={type}
        value={value}
      />
      {error ? <p className="error-text">{error}</p> : null}
    </label>
  );
}

function TextAreaField({
  name,
  label,
  value,
  onChange,
  error,
  placeholder,
  rows = 4,
  helper
}: {
  name: keyof Stage1Form;
  label: string;
  value: string;
  onChange: (
    field: keyof Stage1Form,
    event: ChangeEvent<HTMLTextAreaElement | HTMLInputElement | HTMLSelectElement>
  ) => void;
  error?: string;
  placeholder?: string;
  rows?: number;
  helper?: string;
}) {
  return (
    <label className="block sm:col-span-2">
      <span className="field-label">{label}</span>
      <textarea
        className="input-base min-h-32"
        onChange={(event) => onChange(name, event)}
        placeholder={placeholder}
        rows={rows}
        value={value}
      />
      <div className="mt-1 flex items-center justify-between gap-3">
        {error ? <p className="error-text">{error}</p> : <span />}
        {helper ? (
          <p className="text-xs font-medium text-emerald-950/50 dark:text-white/50">
            {helper}
          </p>
        ) : null}
      </div>
    </label>
  );
}

function SelectField({
  name,
  label,
  value,
  onChange,
  error,
  options
}: {
  name: keyof Stage1Form;
  label: string;
  value: string;
  onChange: (
    field: keyof Stage1Form,
    event: ChangeEvent<HTMLTextAreaElement | HTMLInputElement | HTMLSelectElement>
  ) => void;
  error?: string;
  options: string[];
}) {
  return (
    <label className="block">
      <span className="field-label">{label}</span>
      <select className="input-base" onChange={(event) => onChange(name, event)} value={value}>
        {options.map((option) => (
          <option key={option} value={option.startsWith("Select ") ? "" : option}>
            {option}
          </option>
        ))}
      </select>
      {error ? <p className="error-text">{error}</p> : null}
    </label>
  );
}

function DeclarationCheckbox({
  checked,
  error,
  label,
  onChange
}: {
  checked: boolean;
  error?: string;
  label: string;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label className="flex cursor-pointer items-start gap-3 rounded-2xl border border-emerald-900/10 bg-white/70 p-4 text-sm leading-6 text-brand-ink transition hover:border-brand-green/30 dark:border-white/10 dark:bg-white/10 dark:text-white">
      <input
        checked={checked}
        className="mt-1 rounded border-emerald-900/20 text-brand-green focus:ring-brand-green/30"
        onChange={(event) => onChange(event.target.checked)}
        type="checkbox"
      />
      <span>
        <span className="block font-semibold">{label}</span>
        {error ? <span className="error-text">{error}</span> : null}
      </span>
    </label>
  );
}

function SummaryValue({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-emerald-900/10 bg-white/70 p-4 dark:border-white/10 dark:bg-white/5">
      <p className="text-xs font-bold uppercase tracking-wide text-emerald-950/50 dark:text-white/50">
        {label}
      </p>
      <p className="mt-1 break-words text-sm font-black text-brand-ink dark:text-white">
        {value || "Not provided"}
      </p>
    </div>
  );
}

function NoticeItem({ text }: { text: string }) {
  return (
    <li className="flex gap-2">
      <CheckCircle2 className="mt-0.5 shrink-0 text-brand-green dark:text-brand-gold" size={16} />
      <span>{text}</span>
    </li>
  );
}

function LoadingView() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <div className="glass-panel w-full max-w-lg rounded-3xl p-6 text-center">
        <div className="mx-auto flex size-16 items-center justify-center rounded-full bg-brand-green/10 text-brand-green dark:bg-white/10 dark:text-brand-gold">
          <motion.div
            animate={{ rotate: 360 }}
            className="size-8 rounded-full border-4 border-brand-green/20 border-t-brand-green dark:border-brand-gold/25 dark:border-t-brand-gold"
            transition={{ repeat: Infinity, ease: "linear", duration: 0.9 }}
          />
        </div>
        <h1 className="mt-5 text-2xl font-black text-brand-ink dark:text-white">
          Preparing secure session
        </h1>
        <p className="mt-3 text-sm leading-6 text-emerald-950/70 dark:text-white/70">
          We’re loading the application experience and securing your submission
          token.
        </p>
      </div>
    </main>
  );
}

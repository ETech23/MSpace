"use client";

import { motion } from "framer-motion";
import { CheckCircle2, Home, Sparkles } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { getStage1Application } from "../lib/api";
import { ThemeToggle } from "./ThemeToggle";

type Stage1Receipt = {
  applicantId: string;
  status?: string;
  queueStatus?: string;
  nextActionLink?: string;
  submittedAt?: string;
  email?: string;
  firstName?: string;
  lastName?: string;
};

export function Stage1Success() {
  const searchParams = useSearchParams();
  const applicantId = searchParams.get("applicantId") ?? "";

  return <Stage1SuccessView applicantId={applicantId} />;
}

function Stage1SuccessView({ applicantId }: { applicantId: string }) {
  const [application, setApplication] = useState<Stage1Receipt | null>(null);

  useEffect(() => {
    const stored = window.sessionStorage.getItem("stage1-application");

    if (stored) {
      try {
        setApplication(JSON.parse(stored) as Stage1Receipt);
        return;
      } catch {
        window.sessionStorage.removeItem("stage1-application");
      }
    }

    if (!applicantId) {
      return;
    }

    getStage1Application(applicantId)
      .then((response) => {
        const record = response as Record<string, unknown>;
        setApplication({
          applicantId: String(record.applicantId ?? applicantId),
          status: String(record.status ?? "Pending Review"),
          queueStatus: String(record.queueStatus ?? "Waiting"),
          nextActionLink: String(record.nextActionLink ?? "/apply"),
          submittedAt: formatSubmittedAt(record.submissionTime ?? record.submittedAt),
          email: String(record.email ?? ""),
          firstName: String(record.firstName ?? ""),
          lastName: String(record.lastName ?? "")
        });
      })
      .catch(() => {
        setApplication({
          applicantId,
          status: "Pending Review",
          queueStatus: "Waiting",
          nextActionLink: "/apply"
        });
      });
  }, [applicantId]);

  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-8">
      <section className="w-full max-w-3xl">
        <div className="mb-5 flex justify-end">
          <ThemeToggle />
        </div>
        <motion.div
          animate={{ opacity: 1, scale: 1 }}
          className="glass-panel rounded-3xl p-6 text-center sm:p-10"
          initial={{ opacity: 0, scale: 0.96 }}
          transition={{ duration: 0.42 }}
        >
          <motion.div
            animate={{ scale: [0.92, 1.06, 1] }}
            className="mx-auto flex size-20 items-center justify-center rounded-full bg-brand-green text-white shadow-lg shadow-emerald-900/20"
            transition={{ delay: 0.15, duration: 0.55 }}
          >
            <CheckCircle2 size={42} />
          </motion.div>

          <p className="mt-6 inline-flex items-center gap-2 rounded-full bg-brand-green/10 px-3 py-1 text-xs font-bold uppercase tracking-[0.28em] text-brand-green dark:bg-white/10 dark:text-brand-gold">
            <Sparkles size={14} />
            Application received
          </p>

          <h1 className="mt-5 text-3xl font-black text-brand-ink dark:text-white sm:text-4xl">
            Application Submitted Successfully
          </h1>
          <p className="mx-auto mt-3 max-w-2xl text-sm leading-6 text-emerald-950/70 dark:text-white/70">
            Thank you for applying. Your application has been received and queued
            for review. If you are shortlisted, you will receive an email with
            instructions for Stage 2.
          </p>

          <div className="mt-8 grid gap-3 text-left sm:grid-cols-2">
            <ReceiptItem label="Applicant ID" value={application?.applicantId} />
            <ReceiptItem label="Status" value={application?.status ?? "Pending Review"} />
            <ReceiptItem label="Queue Status" value={application?.queueStatus ?? "Waiting"} />
            <ReceiptItem label="Submitted At" value={application?.submittedAt ?? "Saved securely"} />
            <ReceiptItem label="Email" value={application?.email} />
            <ReceiptItem
              label="Name"
              value={`${application?.firstName ?? ""} ${application?.lastName ?? ""}`.trim()}
            />
          </div>

          <div className="mt-8 rounded-3xl border border-brand-gold/30 bg-brand-gold/10 px-5 py-4 text-left text-sm leading-6 text-brand-ink dark:text-brand-gold">
            <p className="font-black uppercase tracking-wide">Next step</p>
            <p className="mt-2">
              Please monitor your email regularly. We may contact you if we need
              clarification or if your application progresses.
            </p>
          </div>

          <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
            <Link
              className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-brand-green px-5 py-3 text-sm font-bold text-white shadow-lg shadow-emerald-900/20"
              href="/apply"
            >
              <Home size={17} />
              Return Home
            </Link>
          </div>
        </motion.div>
      </section>
    </main>
  );
}

function ReceiptItem({ label, value }: { label: string; value?: string }) {
  return (
    <div className="rounded-2xl border border-emerald-900/10 bg-white/75 p-4 dark:border-white/10 dark:bg-white/10">
      <p className="text-xs font-bold uppercase tracking-wide text-emerald-950/50 dark:text-white/50">
        {label}
      </p>
      <p className="mt-1 break-words text-sm font-black text-brand-ink dark:text-white">
        {value || "Pending"}
      </p>
    </div>
  );
}

function formatSubmittedAt(value: unknown): string {
  if (!value) {
    return "";
  }

  if (typeof value === "string") {
    return value;
  }

  if (typeof value === "object" && value !== null) {
    const maybeValue = value as { toDate?: () => Date; seconds?: number };
    if (typeof maybeValue.toDate === "function") {
      return maybeValue.toDate().toISOString();
    }
    if (typeof maybeValue.seconds === "number") {
      return new Date(maybeValue.seconds * 1000).toISOString();
    }
  }

  return String(value);
}

"use client";

import { motion } from "framer-motion";
import { CheckCircle2, Download, Home } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import type { PaymentReceipt } from "../lib/application";
import { ThemeToggle } from "./ThemeToggle";

export function SuccessReceipt() {
  const [receipt, setReceipt] = useState<PaymentReceipt | null>(null);

  useEffect(() => {
    const stored = sessionStorage.getItem("stage2-receipt");
    if (stored) {
      setReceipt(JSON.parse(stored) as PaymentReceipt);
    }
  }, []);

  function printReceipt() {
    window.print();
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-8">
      <section className="w-full max-w-3xl">
        <div className="mb-5 flex justify-end">
          <ThemeToggle />
        </div>
        <motion.div
          animate={{ opacity: 1, scale: 1 }}
          className="glass-panel rounded-2xl p-6 text-center sm:p-10"
          initial={{ opacity: 0, scale: 0.96 }}
          transition={{ duration: 0.45 }}
        >
          <motion.div
            animate={{ scale: [0.92, 1.08, 1] }}
            className="mx-auto flex size-20 items-center justify-center rounded-full bg-brand-green text-white shadow-lg shadow-emerald-900/20"
            transition={{ delay: 0.15, duration: 0.52 }}
          >
            <CheckCircle2 size={42} />
          </motion.div>

          <h1 className="mt-6 text-3xl font-black text-brand-ink dark:text-white sm:text-4xl">
            Payment Successful
          </h1>
          <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-emerald-950/70 dark:text-white/70">
            Thank you for completing Stage 2. Your application is now under
            review. You will receive further instructions via email if you
            progress to the next stage.
          </p>

          <div className="mt-8 grid gap-3 text-left sm:grid-cols-2">
            <ReceiptItem label="Applicant ID" value={receipt?.applicantId} />
            <ReceiptItem label="Payment Reference" value={receipt?.paymentReference} />
            <ReceiptItem label="Receipt Number" value={receipt?.receiptNumber} />
            <ReceiptItem label="Payment Date" value={receipt?.paymentDate} />
            <ReceiptItem
              label="Amount Paid"
              value={
                receipt
                  ? `${receipt.currency} ${(receipt.amountPaid / 100).toLocaleString()}`
                  : undefined
              }
            />
            <ReceiptItem label="Current Status" value={receipt?.currentStatus} />
          </div>

          {!receipt ? (
            <p className="mt-6 rounded-lg border border-brand-gold/30 bg-brand-gold/10 px-4 py-3 text-sm font-medium text-brand-ink dark:text-brand-gold">
              Receipt details are only shown after a verified checkout in this
              browser session.
            </p>
          ) : null}

          <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
            <button
              className="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg bg-brand-green px-5 py-3 text-sm font-bold text-white"
              onClick={printReceipt}
              type="button"
            >
              <Download size={17} />
              Download Receipt
            </button>
            <Link
              className="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg border border-emerald-900/10 bg-white/80 px-5 py-3 text-sm font-bold text-brand-ink dark:border-white/10 dark:bg-white/10 dark:text-white"
              href="/stage2"
            >
              <Home size={17} />
              Stage 2 Form
            </Link>
          </div>
        </motion.div>
      </section>
    </main>
  );
}

function ReceiptItem({ label, value }: { label: string; value?: string }) {
  return (
    <div className="rounded-lg border border-emerald-900/10 bg-white/70 p-4 dark:border-white/10 dark:bg-white/10">
      <p className="text-xs font-bold uppercase tracking-wide text-emerald-950/50 dark:text-white/50">
        {label}
      </p>
      <p className="mt-1 break-words text-sm font-black text-brand-ink dark:text-white">
        {value ?? "Pending"}
      </p>
    </div>
  );
}

import type { Metadata } from "next";
import { Suspense } from "react";
import { Stage1Success } from "../../../components/Stage1Success";

export const metadata: Metadata = {
  title: "Application Submitted Successfully",
  description: "Your Stage 1 application has been submitted successfully.",
  metadataBase: new URL("https://mspaceapp.com"),
  openGraph: {
    title: "Application Submitted Successfully",
    description: "Your Stage 1 application has been submitted successfully.",
    url: "https://mspaceapp.com/apply/success",
    siteName: "Mspace",
    type: "website"
  }
};

export default function ApplySuccessPage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center px-4 py-8">
          <div className="glass-panel rounded-3xl p-6 text-center sm:p-10">
            <p className="text-sm font-bold uppercase tracking-[0.28em] text-brand-green dark:text-brand-gold">
              Loading
            </p>
            <h1 className="mt-3 text-2xl font-black text-brand-ink dark:text-white">
              Preparing your success page
            </h1>
          </div>
        </main>
      }
    >
      <Stage1Success />
    </Suspense>
  );
}

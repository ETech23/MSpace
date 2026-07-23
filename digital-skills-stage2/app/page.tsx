"use client";

import { useEffect } from "react";

export default function HomePage() {
  useEffect(() => {
    window.location.replace("/stage2");
  }, []);

  return (
    <main className="flex min-h-screen items-center justify-center px-6 text-center">
      <a
        className="rounded-lg bg-brand-green px-6 py-3 text-sm font-semibold text-white shadow-lg shadow-emerald-900/20"
        href="/stage2"
      >
        Open Stage 2 application
      </a>
    </main>
  );
}

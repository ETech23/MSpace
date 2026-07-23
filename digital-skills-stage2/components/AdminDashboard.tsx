"use client";

import { motion } from "framer-motion";
import {
  BarChart3,
  Download,
  FileSpreadsheet,
  RefreshCcw,
  Search,
  ShieldCheck
} from "lucide-react";
import { FormEvent, useEffect, useMemo, useState } from "react";
import { exportApplicants, getAdminDashboard } from "../lib/api";
import { digitalSkills, states } from "../lib/application";
import { ThemeToggle } from "./ThemeToggle";

type ApplicantRow = {
  applicantId: string;
  fullName: string;
  email: string;
  phone: string;
  state: string;
  preferredDigitalSkill: string;
  paymentStatus: string;
  stage: string;
  verificationStatus: string;
  submittedAt: string;
};

type DashboardResponse = {
  stats: {
    pending: number;
    paid: number;
    rejected: number;
    approved: number;
    revenue: number;
  };
  charts: {
    bySkill: Record<string, number>;
    byState: Record<string, number>;
    byPaymentStatus: Record<string, number>;
  };
  applicants: ApplicantRow[];
};

const emptyDashboard: DashboardResponse = {
  stats: {
    pending: 0,
    paid: 0,
    rejected: 0,
    approved: 0,
    revenue: 0
  },
  charts: {
    bySkill: {},
    byState: {},
    byPaymentStatus: {}
  },
  applicants: []
};

export function AdminDashboard() {
  const [adminKey, setAdminKey] = useState("");
  const [filters, setFilters] = useState({
    search: "",
    state: "",
    skill: "",
    paymentStatus: "",
    stage: ""
  });
  const [dashboard, setDashboard] = useState<DashboardResponse>(emptyDashboard);
  const [loading, setLoading] = useState(false);
  const [notice, setNotice] = useState("");

  useEffect(() => {
    setAdminKey(sessionStorage.getItem("stage2-admin-key") ?? "");
  }, []);

  const query = useMemo(() => {
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(filters)) {
      if (value) {
        params.set(key, value);
      }
    }
    return params;
  }, [filters]);

  async function loadDashboard(event?: FormEvent<HTMLFormElement>) {
    event?.preventDefault();
    if (!adminKey) {
      setNotice("Enter the admin API key.");
      return;
    }

    try {
      setLoading(true);
      setNotice("");
      sessionStorage.setItem("stage2-admin-key", adminKey);
      const response = await getAdminDashboard(adminKey, query);
      setDashboard(response as DashboardResponse);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Unable to load dashboard");
    } finally {
      setLoading(false);
    }
  }

  async function download(format: "csv" | "excel") {
    try {
      const params = new URLSearchParams(query);
      params.set("format", format);
      const file = await exportApplicants(adminKey, params);
      const type =
        format === "csv"
          ? "text/csv;charset=utf-8"
          : "application/vnd.ms-excel;charset=utf-8";
      const extension = format === "csv" ? "csv" : "xls";
      const blob = new Blob([file], { type });
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = `stage2-applicants.${extension}`;
      anchor.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Export failed");
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-7xl px-4 py-5 sm:px-6 md:px-8 md:py-8">
      <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="inline-flex items-center gap-2 rounded-full bg-brand-green/10 px-3 py-1 text-xs font-bold uppercase tracking-wide text-brand-green dark:bg-white/10 dark:text-brand-gold">
            <ShieldCheck size={14} />
            Admin
          </p>
          <h1 className="mt-3 text-3xl font-black text-brand-ink dark:text-white">
            Stage 2 dashboard
          </h1>
        </div>
        <ThemeToggle />
      </div>

      <form
        className="glass-panel grid gap-4 rounded-2xl p-5 md:grid-cols-[1.2fr_1fr_1fr_1fr_1fr_1fr_auto]"
        onSubmit={loadDashboard}
      >
        <label>
          <span className="field-label">Admin Key</span>
          <input
            className="input-base"
            onChange={(event) => setAdminKey(event.target.value)}
            type="password"
            value={adminKey}
          />
        </label>
        <FilterInput
          label="Search"
          onChange={(value) => setFilters((current) => ({ ...current, search: value }))}
          value={filters.search}
        />
        <FilterSelect
          label="State"
          onChange={(value) => setFilters((current) => ({ ...current, state: value }))}
          options={states}
          value={filters.state}
        />
        <FilterSelect
          label="Skill"
          onChange={(value) => setFilters((current) => ({ ...current, skill: value }))}
          options={digitalSkills}
          value={filters.skill}
        />
        <FilterSelect
          label="Payment"
          onChange={(value) =>
            setFilters((current) => ({ ...current, paymentStatus: value }))
          }
          options={["Pending", "Paid", "Failed"]}
          value={filters.paymentStatus}
        />
        <FilterSelect
          label="Stage"
          onChange={(value) => setFilters((current) => ({ ...current, stage: value }))}
          options={["Stage2"]}
          value={filters.stage}
        />
        <button
          className="mt-auto inline-flex min-h-12 items-center justify-center gap-2 rounded-lg bg-brand-green px-5 py-3 text-sm font-black text-white disabled:opacity-60"
          disabled={loading}
          type="submit"
        >
          {loading ? <RefreshCcw className="animate-spin" size={17} /> : <Search size={17} />}
          Load
        </button>
      </form>

      {notice ? (
        <p className="mt-4 rounded-lg border border-brand-gold/30 bg-brand-gold/10 px-4 py-3 text-sm font-semibold text-brand-ink dark:text-brand-gold">
          {notice}
        </p>
      ) : null}

      <section className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
        <StatCard label="Pending" value={dashboard.stats.pending} />
        <StatCard label="Paid" value={dashboard.stats.paid} />
        <StatCard label="Rejected" value={dashboard.stats.rejected} />
        <StatCard label="Approved" value={dashboard.stats.approved} />
        <StatCard
          label="Revenue"
          value={`NGN ${(dashboard.stats.revenue / 100).toLocaleString()}`}
        />
      </section>

      <section className="mt-6 grid gap-5 lg:grid-cols-3">
        <Chart title="Skills" values={dashboard.charts.bySkill} />
        <Chart title="States" values={dashboard.charts.byState} />
        <Chart title="Payments" values={dashboard.charts.byPaymentStatus} />
      </section>

      <section className="glass-panel mt-6 rounded-2xl p-5">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-xl font-black text-brand-ink dark:text-white">
            Applicants
          </h2>
          <div className="flex gap-2">
            <button
              className="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-emerald-900/10 bg-white/80 px-4 text-sm font-bold text-brand-ink dark:border-white/10 dark:bg-white/10 dark:text-white"
              onClick={() => download("csv")}
              type="button"
            >
              <Download size={16} />
              CSV
            </button>
            <button
              className="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-emerald-900/10 bg-white/80 px-4 text-sm font-bold text-brand-ink dark:border-white/10 dark:bg-white/10 dark:text-white"
              onClick={() => download("excel")}
              type="button"
            >
              <FileSpreadsheet size={16} />
              Excel
            </button>
          </div>
        </div>

        <div className="mt-5 overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="text-xs uppercase tracking-wide text-emerald-950/50 dark:text-white/50">
              <tr>
                {[
                  "Applicant",
                  "Email",
                  "Phone",
                  "State",
                  "Skill",
                  "Payment",
                  "Stage",
                  "Submitted"
                ].map((header) => (
                  <th className="whitespace-nowrap px-3 py-3" key={header}>
                    {header}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-emerald-900/10 dark:divide-white/10">
              {dashboard.applicants.map((applicant) => (
                <tr key={applicant.applicantId}>
                  <td className="whitespace-nowrap px-3 py-4 font-bold text-brand-ink dark:text-white">
                    {applicant.fullName}
                    <span className="block text-xs font-medium text-emerald-950/50 dark:text-white/50">
                      {applicant.applicantId}
                    </span>
                  </td>
                  <td className="whitespace-nowrap px-3 py-4">{applicant.email}</td>
                  <td className="whitespace-nowrap px-3 py-4">{applicant.phone}</td>
                  <td className="whitespace-nowrap px-3 py-4">{applicant.state}</td>
                  <td className="whitespace-nowrap px-3 py-4">
                    {applicant.preferredDigitalSkill}
                  </td>
                  <td className="whitespace-nowrap px-3 py-4">
                    {applicant.paymentStatus}
                  </td>
                  <td className="whitespace-nowrap px-3 py-4">{applicant.stage}</td>
                  <td className="whitespace-nowrap px-3 py-4">
                    {applicant.submittedAt}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}

function FilterInput({
  label,
  onChange,
  value
}: {
  label: string;
  onChange: (value: string) => void;
  value: string;
}) {
  return (
    <label>
      <span className="field-label">{label}</span>
      <input
        className="input-base"
        onChange={(event) => onChange(event.target.value)}
        value={value}
      />
    </label>
  );
}

function FilterSelect({
  label,
  onChange,
  options,
  value
}: {
  label: string;
  onChange: (value: string) => void;
  options: string[];
  value: string;
}) {
  return (
    <label>
      <span className="field-label">{label}</span>
      <select
        className="input-base"
        onChange={(event) => onChange(event.target.value)}
        value={value}
      >
        <option value="">All</option>
        {options.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
    </label>
  );
}

function StatCard({ label, value }: { label: string; value: number | string }) {
  return (
    <motion.div
      animate={{ opacity: 1, y: 0 }}
      className="glass-panel rounded-xl p-5"
      initial={{ opacity: 0, y: 12 }}
    >
      <p className="text-xs font-bold uppercase tracking-wide text-emerald-950/50 dark:text-white/50">
        {label}
      </p>
      <p className="mt-2 text-2xl font-black text-brand-ink dark:text-white">
        {value}
      </p>
    </motion.div>
  );
}

function Chart({ title, values }: { title: string; values: Record<string, number> }) {
  const entries = Object.entries(values).slice(0, 7);
  const max = Math.max(...entries.map(([, value]) => value), 1);

  return (
    <div className="glass-panel rounded-xl p-5">
      <div className="flex items-center gap-2">
        <BarChart3 className="text-brand-green dark:text-brand-gold" size={18} />
        <h2 className="font-black text-brand-ink dark:text-white">{title}</h2>
      </div>
      <div className="mt-5 space-y-4">
        {entries.length ? (
          entries.map(([label, value]) => (
            <div key={label}>
              <div className="flex items-center justify-between gap-3 text-xs font-bold">
                <span className="truncate text-brand-ink dark:text-white">{label}</span>
                <span className="text-emerald-950/60 dark:text-white/60">{value}</span>
              </div>
              <div className="mt-2 h-2 overflow-hidden rounded-full bg-emerald-900/10 dark:bg-white/10">
                <div
                  className="h-full rounded-full bg-brand-gold"
                  style={{ width: `${(value / max) * 100}%` }}
                />
              </div>
            </div>
          ))
        ) : (
          <p className="text-sm text-emerald-950/60 dark:text-white/60">
            No data loaded.
          </p>
        )}
      </div>
    </div>
  );
}

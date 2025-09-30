"use client";

import { FormEvent, useState } from "react";

import { FileUpload } from "@/components/FileUpload";
import type { AnalysisResult } from "@/types/analysis";
import { ResultCard } from "@/components/ResultCard";
import { RiskToleranceSelector, riskLevels } from "@/components/RiskToleranceSelector";
import type { RiskLevel } from "@/components/RiskToleranceSelector";
import { ShareButton } from "@/components/ShareButton";

const DEFAULT_RISK: RiskLevel = "moderate";

export default function HomePage() {
  const [riskTolerance, setRiskTolerance] = useState<RiskLevel>(DEFAULT_RISK);
  const [files, setFiles] = useState<File[]>([]);
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);

    if (files.length === 0) {
      setError("Please upload at least one document so we can review your portfolio.");
      return;
    }

    const formData = new FormData();
    formData.append("riskTolerance", riskTolerance);
    files.forEach((file) => formData.append("files", file));

    setIsSubmitting(true);
    setResult(null);

    try {
      const response = await fetch("/api/rate", {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({ error: "Unknown error" }));
        throw new Error(data.error ?? "Unable to analyze the portfolio.");
      }

      const data = (await response.json()) as AnalysisResult;
      setResult(data);
    } catch (submissionError) {
      setError((submissionError as Error).message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_#0f172a,_#020617_70%)] pb-16 text-white">
      <main className="mx-auto flex w-full max-w-6xl flex-col gap-12 px-6 pt-16 sm:px-10">
        <header className="space-y-6 text-center sm:text-left">
          <p className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/10 px-4 py-1 text-xs uppercase tracking-[0.2em] text-white/70">
            Intelligent portfolio analysis
          </p>
          <h1 className="text-4xl font-semibold leading-tight sm:text-5xl md:text-6xl">
            Rate My Portfolio
          </h1>
          <p className="mx-auto max-w-2xl text-base text-white/70 sm:mx-0 sm:text-lg">
            Upload the documents that describe your holdings, choose how much risk you can stomach, and let our AI co-pilot rate
            your alignment across risk, growth, diversification, and more.
          </p>
        </header>

        <form
          onSubmit={handleSubmit}
          className="grid gap-10 rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl md:grid-cols-[2fr,1fr]"
        >
          <div className="space-y-8">
            <FileUpload files={files} onFilesChange={setFiles} />
            <RiskToleranceSelector value={riskTolerance} onChange={setRiskTolerance} />
            <p className="text-xs text-white/60">
              Tip: Include a recent statement or export from your broker along with notes about your objectives for the clearest
              recommendation.
            </p>
          </div>

          <aside className="flex flex-col justify-between gap-8 rounded-2xl border border-white/10 bg-black/40 p-6">
            <div className="space-y-3">
              <h2 className="text-lg font-semibold text-white">Your selection</h2>
              <ul className="space-y-2 text-sm text-white/70">
                <li>
                  <span className="font-medium text-white">Risk tolerance:</span>
                  {" "}
                  {riskLevels.find((level) => level.id === riskTolerance)?.label}
                </li>
                <li>
                  <span className="font-medium text-white">Files:</span> {files.length}
                </li>
              </ul>
            </div>
            <button
              type="submit"
              disabled={isSubmitting}
              className="inline-flex items-center justify-center rounded-full bg-gradient-to-r from-emerald-400 via-cyan-400 to-sky-400 px-6 py-3 text-sm font-semibold text-slate-950 shadow-lg shadow-emerald-500/25 transition hover:from-emerald-300 hover:via-cyan-300 hover:to-sky-300 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {isSubmitting ? "Rating portfolio..." : "Rate my portfolio"}
            </button>
            {error && <p className="text-xs text-rose-200">{error}</p>}
          </aside>
        </form>

        {result && (
          <section className="space-y-6 rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl">
            <ResultCard result={result} />
            <ShareButton result={result} />
          </section>
        )}
      </main>
    </div>
  );
}

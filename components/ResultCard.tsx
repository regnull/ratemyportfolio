"use client";

import type { AnalysisResult } from "@/types/analysis";

type ResultCardProps = {
  result: AnalysisResult;
};

export function ResultCard({ result }: ResultCardProps) {
  return (
    <article className="space-y-8 rounded-3xl border border-white/10 bg-black/40 px-8 py-10 shadow-xl shadow-emerald-500/10">
      <div className="space-y-3">
        <h2 className="text-2xl font-semibold text-white">Portfolio verdict</h2>
        <p className="text-base text-white/70 leading-relaxed">{result.summary}</p>
      </div>

      <div className="grid gap-5 md:grid-cols-2">
        {result.ratings.map((item) => (
          <div
            key={item.axis}
            className="rounded-2xl bg-white/5 p-5 transition hover:bg-white/10"
          >
            <div className="flex items-baseline justify-between">
              <h3 className="text-lg font-semibold text-white">{item.axis}</h3>
              <span className="text-sm font-medium text-emerald-200">{item.score}</span>
            </div>
            <p className="mt-3 text-sm text-white/70 leading-relaxed">
              {item.explanation}
            </p>
          </div>
        ))}
      </div>

      <div className="space-y-3">
        <h3 className="text-lg font-semibold text-white">Suggested next steps</h3>
        <ul className="space-y-2">
          {result.suggestions.map((suggestion, index) => (
            <li
              key={`${suggestion}-${index}`}
              className="flex gap-3 text-sm text-white/80"
            >
              <span className="mt-1 inline-block h-2 w-2 rounded-full bg-emerald-400" aria-hidden />
              <span className="leading-relaxed">{suggestion}</span>
            </li>
          ))}
        </ul>
      </div>
    </article>
  );
}

export type { AnalysisResult } from "@/types/analysis";

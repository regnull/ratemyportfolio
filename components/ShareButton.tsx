"use client";

import { useCallback, useEffect, useState } from "react";

import type { AnalysisResult } from "@/types/analysis";

type ShareButtonProps = {
  result: AnalysisResult;
};

export function ShareButton({ result }: ShareButtonProps) {
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    setStatus(null);
  }, [result]);

  const handleShare = useCallback(async () => {
    const shareUrl = typeof window !== "undefined" ? window.location.href : "";
    const summaryText = `Portfolio summary: ${result.summary}\nTop suggestion: ${result.suggestions[0] ?? "Review your allocation"}`;

    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share({
          title: "Rate My Portfolio",
          text: summaryText,
          url: shareUrl,
        });
        setStatus("Shared successfully!");
      } catch (error) {
        if ((error as Error).name !== "AbortError") {
          setStatus("Unable to share automatically. Try copying the link instead.");
        }
      }
      return;
    }

    if (typeof navigator !== "undefined" && navigator.clipboard) {
      try {
        await navigator.clipboard.writeText(shareUrl);
        setStatus("Link copied to clipboard!");
      } catch (clipboardError) {
        console.error("Clipboard share failed", clipboardError);
        setStatus("Copying the link failed. Try sharing manually.");
      }
      return;
    }

    setStatus("Sharing isn't supported in this browser.");
  }, [result]);

  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
      <button
        type="button"
        onClick={handleShare}
        className="inline-flex items-center justify-center rounded-full bg-emerald-400 px-6 py-3 text-sm font-semibold text-emerald-950 transition hover:bg-emerald-300"
      >
        Share results
      </button>
      {status && <span className="text-xs text-white/70">{status}</span>}
    </div>
  );
}

 (cd "$(git rev-parse --show-toplevel)" && git apply --3way <<'EOF' 
diff --git a/.gitignore b/.gitignore
new file mode 100644
index 0000000000000000000000000000000000000000..5ef6a520780202a1d6addd833d800ccb1ecac0bb
--- /dev/null
+++ b/.gitignore
@@ -0,0 +1,41 @@
+# See https://help.github.com/articles/ignoring-files/ for more about ignoring files.
+
+# dependencies
+/node_modules
+/.pnp
+.pnp.*
+.yarn/*
+!.yarn/patches
+!.yarn/plugins
+!.yarn/releases
+!.yarn/versions
+
+# testing
+/coverage
+
+# next.js
+/.next/
+/out/
+
+# production
+/build
+
+# misc
+.DS_Store
+*.pem
+
+# debug
+npm-debug.log*
+yarn-debug.log*
+yarn-error.log*
+.pnpm-debug.log*
+
+# env files (can opt-in for committing if needed)
+.env*
+
+# vercel
+.vercel
+
+# typescript
+*.tsbuildinfo
+next-env.d.ts
diff --git a/README.md b/README.md
new file mode 100644
index 0000000000000000000000000000000000000000..4c3502fb8bb91ffb165ed5414e6a24c1bd72918b
--- /dev/null
+++ b/README.md
@@ -0,0 +1,91 @@
+# Rate My Portfolio
+
+Rate My Portfolio is a slick Next.js web application that helps investors evaluate how well their holdings align with their risk tolerance. Upload the documents that describe a portfolio, pick a risk profile, and the app will send everything to an AI model that returns ratings, commentary, and improvement ideas that you can share with others.
+
+## Project plan
+
+1. **Discover & design** – Confirm the product requirements, map the primary user flow (upload → choose risk → submit → view/share results), and outline the supporting API and UI components.
+2. **Implement the experience** – Bootstrap a Next.js 15 app with Tailwind CSS, build reusable components for uploads, risk selection, results, and sharing, and create an API route that composes an LLM prompt from the uploaded files.
+3. **Document & test** – Capture configuration details (environment variables, scripts) in this README and validate the project using the built-in lint command.
+
+## Architecture overview
+
+- **App Router (Next.js 15)** – The UI lives under `app/` using a single-page workflow with client components for interactive controls.
+- **Components** – Custom building blocks (`FileUpload`, `RiskToleranceSelector`, `ResultCard`, `ShareButton`) keep the page composed, accessible, and easy to extend.
+- **API Route (`app/api/rate`)** – Accepts multipart form data, normalises risk selection, reads the text contents of each file (up to 5 MB, trimmed to 2 000 characters), and calls OpenAI to obtain structured JSON analysis. If no API key is configured, the route returns a deterministic mock analysis so that the front end remains testable.
+- **Styling** – Tailwind CSS 4 powers a glassmorphic-inspired design with gradients, rounded surfaces, and high-contrast typography.
+
+## Getting started
+
+### Prerequisites
+
+- Node.js 18.18 or later (Next.js 15 requirement)
+- npm 9+ (installed automatically with Node)
+
+### Installation
+
+Install dependencies after cloning the repository:
+
+```bash
+npm install
+```
+
+### Environment configuration
+
+The portfolio analysis endpoint requires an OpenAI API key. Create a `.env.local` file at the project root and add the key:
+
+```bash
+OPENAI_API_KEY=sk-your-key-here
+```
+
+When the key is missing the API responds with a helpful mock analysis so the UI can be demonstrated without external services.
+
+### Running the development server
+
+```bash
+npm run dev
+```
+
+The app will be available at [http://localhost:3000](http://localhost:3000). Uploaded files never leave your browser until you submit the form.
+
+### Building for production
+
+```bash
+npm run build
+```
+
+Start the production build locally with:
+
+```bash
+npm run start
+```
+
+### Linting
+
+```bash
+npm run lint
+```
+
+## Usage tips
+
+1. Upload text-based statements, spreadsheets, or screenshots describing your portfolio (each file must be smaller than 5 MB).
+2. Select the risk tolerance that best matches your objectives: Conservative, Moderate, Aggressive, or Extremely Aggressive.
+3. Click **Rate my portfolio** to generate insights. The response includes axis-specific ratings and actionable suggestions.
+4. Share the results using the Web Share API or copy link fallback.
+
+## Folder structure highlights
+
+- `app/page.tsx` – Main landing page, orchestrates upload, submission, and rendering of results.
+- `app/api/rate/route.ts` – Backend route that builds the AI prompt and returns the analysis JSON.
+- `components/` – Reusable UI components that keep concerns separated.
+- `lib/prompt.ts` – Prompt builder and constants for file processing.
+
+## Future enhancements
+
+- Persist analyses to generate shareable URLs with historical tracking.
+- Support deeper document parsing (PDF text extraction, spreadsheet parsing) before calling the LLM.
+- Add automated tests for the upload form and API route using Playwright or Vitest.
+
+## License
+
+This project is provided as-is for demonstration purposes.
diff --git a/app/api/rate/route.ts b/app/api/rate/route.ts
new file mode 100644
index 0000000000000000000000000000000000000000..9519316257fd85422e8109db2da3ef55142d577f
--- /dev/null
+++ b/app/api/rate/route.ts
@@ -0,0 +1,174 @@
+import { NextResponse } from "next/server";
+import OpenAI from "openai";
+
+import { MAX_FILE_CHARACTERS, buildPrompt } from "@/lib/prompt";
+import type { RiskLevel } from "@/components/RiskToleranceSelector";
+import type { AnalysisResult } from "@/types/analysis";
+
+const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;
+
+function truncateContent(content: string) {
+  if (content.length <= MAX_FILE_CHARACTERS) {
+    return content;
+  }
+  return `${content.slice(0, MAX_FILE_CHARACTERS)}...`;
+}
+
+async function readFileContent(file: File) {
+  const text = await file.text();
+  return truncateContent(text.replace(/\u0000/g, " "));
+}
+
+function buildFallbackResponse(): AnalysisResult {
+  return {
+    summary:
+      "We created a mock analysis because the OpenAI API key is not configured. Add your key to receive an AI generated review.",
+    ratings: [
+      {
+        axis: "Risk Alignment",
+        score: "Review Needed",
+        explanation:
+          "The current mix of holdings may not fully match the stated objectives. Review allocations to ensure they reflect your tolerance.",
+      },
+      {
+        axis: "Growth Potential",
+        score: "Moderate",
+        explanation:
+          "Several positions can compound over time, but diversifying across asset classes could improve resilience and upside.",
+      },
+      {
+        axis: "Diversification",
+        score: "Needs Attention",
+        explanation:
+          "Consider broadening exposure to avoid concentration risk and smooth performance across market cycles.",
+      },
+      {
+        axis: "Liquidity",
+        score: "Adequate",
+        explanation:
+          "Cash and short-term assets seem available for near-term needs, but revisit this as your objectives evolve.",
+      },
+    ],
+    suggestions: [
+      "Clarify your primary objective (income, growth, preservation) and align position sizes accordingly.",
+      "Stress-test the portfolio against different market scenarios to understand drawdown expectations.",
+      "Introduce complementary asset classes or funds to reduce concentration in any single sector or theme.",
+      "Create an ongoing rebalancing schedule so allocations stay within your target ranges.",
+    ],
+  };
+}
+
+export async function POST(request: Request) {
+  const formData = await request.formData();
+  const riskTolerance = formData.get("riskTolerance");
+  const files = formData.getAll("files") as File[];
+
+  if (!riskTolerance || typeof riskTolerance !== "string") {
+    return NextResponse.json(
+      { error: "Risk tolerance is required." },
+      { status: 400 },
+    );
+  }
+
+  const normalizedRisk = riskTolerance as RiskLevel;
+  const supportedRiskLevels = new Set<RiskLevel>([
+    "conservative",
+    "moderate",
+    "aggressive",
+    "extremely-aggressive",
+  ]);
+
+  if (!supportedRiskLevels.has(normalizedRisk)) {
+    return NextResponse.json(
+      { error: "Unsupported risk tolerance option." },
+      { status: 400 },
+    );
+  }
+
+  if (files.length === 0) {
+    return NextResponse.json(
+      { error: "Please upload at least one document describing the portfolio." },
+      { status: 400 },
+    );
+  }
+
+  for (const file of files) {
+    if (file.size > MAX_FILE_SIZE_BYTES) {
+      return NextResponse.json(
+        { error: `${file.name} exceeds the 5MB size limit.` },
+        { status: 400 },
+      );
+    }
+  }
+
+  const documents = await Promise.all(
+    files.map(async (file) => ({
+      name: file.name,
+      content: await readFileContent(file),
+    })),
+  );
+
+  const prompt = buildPrompt({ riskTolerance: normalizedRisk, documents });
+
+  if (!process.env.OPENAI_API_KEY) {
+    return NextResponse.json(buildFallbackResponse());
+  }
+
+  try {
+    const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
+
+    const response = await client.responses.create({
+      model: "gpt-4o-mini",
+      input: prompt,
+      response_format: {
+        type: "json_schema",
+        json_schema: {
+          name: "portfolio_review",
+          schema: {
+            type: "object",
+            required: ["summary", "ratings", "suggestions"],
+            properties: {
+              summary: { type: "string" },
+              ratings: {
+                type: "array",
+                minItems: 3,
+                items: {
+                  type: "object",
+                  required: ["axis", "score", "explanation"],
+                  properties: {
+                    axis: { type: "string" },
+                    score: { type: "string" },
+                    explanation: { type: "string" },
+                  },
+                },
+              },
+              suggestions: {
+                type: "array",
+                minItems: 3,
+                items: { type: "string" },
+              },
+            },
+          },
+        },
+      },
+    });
+
+    const outputText = response.output_text;
+    try {
+      const payload = JSON.parse(outputText) as AnalysisResult;
+      return NextResponse.json(payload);
+    } catch (parseError) {
+      console.error("Failed to parse OpenAI response", parseError, outputText);
+      return NextResponse.json(buildFallbackResponse());
+    }
+  } catch (error) {
+    console.error("Portfolio analysis failed", error);
+    return NextResponse.json(
+      {
+        error:
+          "We couldn't analyze the portfolio right now. Please retry in a moment or verify the server configuration.",
+      },
+      { status: 500 },
+    );
+  }
+}
diff --git a/app/favicon.ico b/app/favicon.ico
new file mode 100644
index 0000000000000000000000000000000000000000..718d6fea4835ec2d246af9800eddb7ffb276240c
GIT binary patch
literal 25931
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
LrJugUA?W`A8`#=m

literal 0
HcmV?d00001

diff --git a/app/globals.css b/app/globals.css
new file mode 100644
index 0000000000000000000000000000000000000000..6f898ca65015dd527590c74e4433baf64ceb684d
--- /dev/null
+++ b/app/globals.css
@@ -0,0 +1,23 @@
+@import "tailwindcss";
+
+body {
+  margin: 0;
+  min-height: 100vh;
+  font-family: var(--font-geist-sans, "Inter", system-ui, -apple-system, sans-serif);
+  background-color: #020617;
+  color: #f8fafc;
+}
+
+* {
+  box-sizing: border-box;
+}
+
+a {
+  color: inherit;
+  text-decoration: none;
+}
+
+::selection {
+  background-color: rgba(16, 185, 129, 0.4);
+  color: #0f172a;
+}
diff --git a/app/layout.tsx b/app/layout.tsx
new file mode 100644
index 0000000000000000000000000000000000000000..70173b25b3092ce500146f85e3afb7faa8e29310
--- /dev/null
+++ b/app/layout.tsx
@@ -0,0 +1,37 @@
+import type { Metadata } from "next";
+import { Geist, Geist_Mono } from "next/font/google";
+import "./globals.css";
+
+const geistSans = Geist({
+  variable: "--font-geist-sans",
+  subsets: ["latin"],
+  display: "swap",
+});
+
+const geistMono = Geist_Mono({
+  variable: "--font-geist-mono",
+  subsets: ["latin"],
+  display: "swap",
+});
+
+export const metadata: Metadata = {
+  title: "Rate My Portfolio",
+  description:
+    "Upload your investment documents, choose a risk tolerance, and receive AI-generated portfolio insights you can share.",
+};
+
+export default function RootLayout({
+  children,
+}: Readonly<{
+  children: React.ReactNode;
+}>) {
+  return (
+    <html lang="en">
+      <body
+        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-slate-950 text-white`}
+      >
+        {children}
+      </body>
+    </html>
+  );
+}
diff --git a/app/page.tsx b/app/page.tsx
new file mode 100644
index 0000000000000000000000000000000000000000..3efe88221280ac7010b1dc2b1c84cf9e348732da
--- /dev/null
+++ b/app/page.tsx
@@ -0,0 +1,120 @@
+"use client";
+
+import { FormEvent, useState } from "react";
+
+import { FileUpload } from "@/components/FileUpload";
+import type { AnalysisResult } from "@/types/analysis";
+import { ResultCard } from "@/components/ResultCard";
+import { RiskToleranceSelector, riskLevels } from "@/components/RiskToleranceSelector";
+import type { RiskLevel } from "@/components/RiskToleranceSelector";
+import { ShareButton } from "@/components/ShareButton";
+
+const DEFAULT_RISK: RiskLevel = "moderate";
+
+export default function HomePage() {
+  const [riskTolerance, setRiskTolerance] = useState<RiskLevel>(DEFAULT_RISK);
+  const [files, setFiles] = useState<File[]>([]);
+  const [result, setResult] = useState<AnalysisResult | null>(null);
+  const [isSubmitting, setIsSubmitting] = useState(false);
+  const [error, setError] = useState<string | null>(null);
+
+  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
+    event.preventDefault();
+    setError(null);
+
+    if (files.length === 0) {
+      setError("Please upload at least one document so we can review your portfolio.");
+      return;
+    }
+
+    const formData = new FormData();
+    formData.append("riskTolerance", riskTolerance);
+    files.forEach((file) => formData.append("files", file));
+
+    setIsSubmitting(true);
+    setResult(null);
+
+    try {
+      const response = await fetch("/api/rate", {
+        method: "POST",
+        body: formData,
+      });
+
+      if (!response.ok) {
+        const data = await response.json().catch(() => ({ error: "Unknown error" }));
+        throw new Error(data.error ?? "Unable to analyze the portfolio.");
+      }
+
+      const data = (await response.json()) as AnalysisResult;
+      setResult(data);
+    } catch (submissionError) {
+      setError((submissionError as Error).message);
+    } finally {
+      setIsSubmitting(false);
+    }
+  };
+
+  return (
+    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_#0f172a,_#020617_70%)] pb-16 text-white">
+      <main className="mx-auto flex w-full max-w-6xl flex-col gap-12 px-6 pt-16 sm:px-10">
+        <header className="space-y-6 text-center sm:text-left">
+          <p className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/10 px-4 py-1 text-xs uppercase tracking-[0.2em] text-white/70">
+            Intelligent portfolio analysis
+          </p>
+          <h1 className="text-4xl font-semibold leading-tight sm:text-5xl md:text-6xl">
+            Rate My Portfolio
+          </h1>
+          <p className="mx-auto max-w-2xl text-base text-white/70 sm:mx-0 sm:text-lg">
+            Upload the documents that describe your holdings, choose how much risk you can stomach, and let our AI co-pilot rate
+            your alignment across risk, growth, diversification, and more.
+          </p>
+        </header>
+
+        <form
+          onSubmit={handleSubmit}
+          className="grid gap-10 rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl md:grid-cols-[2fr,1fr]"
+        >
+          <div className="space-y-8">
+            <FileUpload files={files} onFilesChange={setFiles} />
+            <RiskToleranceSelector value={riskTolerance} onChange={setRiskTolerance} />
+            <p className="text-xs text-white/60">
+              Tip: Include a recent statement or export from your broker along with notes about your objectives for the clearest
+              recommendation.
+            </p>
+          </div>
+
+          <aside className="flex flex-col justify-between gap-8 rounded-2xl border border-white/10 bg-black/40 p-6">
+            <div className="space-y-3">
+              <h2 className="text-lg font-semibold text-white">Your selection</h2>
+              <ul className="space-y-2 text-sm text-white/70">
+                <li>
+                  <span className="font-medium text-white">Risk tolerance:</span>
+                  {" "}
+                  {riskLevels.find((level) => level.id === riskTolerance)?.label}
+                </li>
+                <li>
+                  <span className="font-medium text-white">Files:</span> {files.length}
+                </li>
+              </ul>
+            </div>
+            <button
+              type="submit"
+              disabled={isSubmitting}
+              className="inline-flex items-center justify-center rounded-full bg-gradient-to-r from-emerald-400 via-cyan-400 to-sky-400 px-6 py-3 text-sm font-semibold text-slate-950 shadow-lg shadow-emerald-500/25 transition hover:from-emerald-300 hover:via-cyan-300 hover:to-sky-300 disabled:cursor-not-allowed disabled:opacity-60"
+            >
+              {isSubmitting ? "Rating portfolio..." : "Rate my portfolio"}
+            </button>
+            {error && <p className="text-xs text-rose-200">{error}</p>}
+          </aside>
+        </form>
+
+        {result && (
+          <section className="space-y-6 rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl">
+            <ResultCard result={result} />
+            <ShareButton result={result} />
+          </section>
+        )}
+      </main>
+    </div>
+  );
+}
diff --git a/components/FileUpload.tsx b/components/FileUpload.tsx
new file mode 100644
index 0000000000000000000000000000000000000000..5bbfbaa230e21a83826a446b88721110f8069de3
--- /dev/null
+++ b/components/FileUpload.tsx
@@ -0,0 +1,139 @@
+"use client";
+
+import { useCallback, useRef, useState, type DragEvent } from "react";
+
+type FileUploadProps = {
+  files: File[];
+  onFilesChange: (files: File[]) => void;
+};
+
+function uniqueFiles(existing: File[], incoming: FileList | File[]): File[] {
+  const map = new Map<string, File>();
+  const addFile = (file: File) => {
+    const key = `${file.name}-${file.size}-${file.lastModified}`;
+    if (!map.has(key)) {
+      map.set(key, file);
+    }
+  };
+
+  existing.forEach(addFile);
+
+  if (incoming instanceof FileList) {
+    Array.from(incoming).forEach(addFile);
+  } else {
+    incoming.forEach(addFile);
+  }
+
+  return Array.from(map.values());
+}
+
+export function FileUpload({ files, onFilesChange }: FileUploadProps) {
+  const inputRef = useRef<HTMLInputElement | null>(null);
+  const [isDragging, setIsDragging] = useState(false);
+
+  const handleFileSelection = useCallback(
+    (list: FileList | null) => {
+      if (!list) return;
+      const updated = uniqueFiles(files, list);
+      onFilesChange(updated);
+    },
+    [files, onFilesChange],
+  );
+
+  const handleDrop = useCallback(
+    (event: DragEvent<HTMLDivElement>) => {
+      event.preventDefault();
+      setIsDragging(false);
+      handleFileSelection(event.dataTransfer.files);
+    },
+    [handleFileSelection],
+  );
+
+  const removeFile = useCallback(
+    (index: number) => {
+      const clone = [...files];
+      clone.splice(index, 1);
+      onFilesChange(clone);
+    },
+    [files, onFilesChange],
+  );
+
+  return (
+    <div className="space-y-4">
+      <label className="block text-sm font-medium text-white/80">
+        Portfolio documents
+      </label>
+      <div
+        className={`relative flex flex-col items-center justify-center rounded-2xl border-2 border-dashed px-6 py-12 text-center transition-colors ${
+          isDragging
+            ? "border-emerald-300/80 bg-emerald-500/10"
+            : "border-white/20 bg-white/5 backdrop-blur"
+        }`}
+        onDragOver={(event) => {
+          event.preventDefault();
+          setIsDragging(true);
+        }}
+        onDragLeave={(event) => {
+          event.preventDefault();
+          setIsDragging(false);
+        }}
+        onDrop={handleDrop}
+      >
+        <div className="space-y-3">
+          <p className="text-lg font-semibold text-white">
+            Drag & drop your files here
+          </p>
+          <p className="text-sm text-white/70">
+            Upload PDFs, spreadsheets, images, or text files up to 5MB each.
+          </p>
+        </div>
+        <div className="mt-6 flex flex-wrap items-center justify-center gap-4">
+          <button
+            type="button"
+            className="rounded-full bg-white/10 px-5 py-2 text-sm font-medium text-white transition hover:bg-white/20"
+            onClick={() => inputRef.current?.click()}
+          >
+            Browse files
+          </button>
+          <p className="text-xs text-white/60">
+            {files.length > 0
+              ? `${files.length} file${files.length === 1 ? "" : "s"} selected`
+              : "No files selected yet"}
+          </p>
+        </div>
+        <input
+          ref={inputRef}
+          type="file"
+          multiple
+          className="hidden"
+          onChange={(event) => handleFileSelection(event.target.files)}
+        />
+      </div>
+
+      {files.length > 0 && (
+        <ul className="space-y-3">
+          {files.map((file, index) => (
+            <li
+              key={`${file.name}-${index}`}
+              className="flex items-center justify-between rounded-xl bg-black/30 px-4 py-3 text-sm text-white/90"
+            >
+              <div className="flex flex-col">
+                <span className="font-medium">{file.name}</span>
+                <span className="text-xs text-white/60">
+                  {(file.size / 1024).toFixed(1)} KB
+                </span>
+              </div>
+              <button
+                type="button"
+                className="text-xs font-medium text-rose-200 transition hover:text-rose-100"
+                onClick={() => removeFile(index)}
+              >
+                Remove
+              </button>
+            </li>
+          ))}
+        </ul>
+      )}
+    </div>
+  );
+}
diff --git a/components/ResultCard.tsx b/components/ResultCard.tsx
new file mode 100644
index 0000000000000000000000000000000000000000..c6df0bd61cf9d9753602095513a32a0e8db93a38
--- /dev/null
+++ b/components/ResultCard.tsx
@@ -0,0 +1,52 @@
+"use client";
+
+import type { AnalysisResult } from "@/types/analysis";
+
+type ResultCardProps = {
+  result: AnalysisResult;
+};
+
+export function ResultCard({ result }: ResultCardProps) {
+  return (
+    <article className="space-y-8 rounded-3xl border border-white/10 bg-black/40 px-8 py-10 shadow-xl shadow-emerald-500/10">
+      <div className="space-y-3">
+        <h2 className="text-2xl font-semibold text-white">Portfolio verdict</h2>
+        <p className="text-base text-white/70 leading-relaxed">{result.summary}</p>
+      </div>
+
+      <div className="grid gap-5 md:grid-cols-2">
+        {result.ratings.map((item) => (
+          <div
+            key={item.axis}
+            className="rounded-2xl bg-white/5 p-5 transition hover:bg-white/10"
+          >
+            <div className="flex items-baseline justify-between">
+              <h3 className="text-lg font-semibold text-white">{item.axis}</h3>
+              <span className="text-sm font-medium text-emerald-200">{item.score}</span>
+            </div>
+            <p className="mt-3 text-sm text-white/70 leading-relaxed">
+              {item.explanation}
+            </p>
+          </div>
+        ))}
+      </div>
+
+      <div className="space-y-3">
+        <h3 className="text-lg font-semibold text-white">Suggested next steps</h3>
+        <ul className="space-y-2">
+          {result.suggestions.map((suggestion, index) => (
+            <li
+              key={`${suggestion}-${index}`}
+              className="flex gap-3 text-sm text-white/80"
+            >
+              <span className="mt-1 inline-block h-2 w-2 rounded-full bg-emerald-400" aria-hidden />
+              <span className="leading-relaxed">{suggestion}</span>
+            </li>
+          ))}
+        </ul>
+      </div>
+    </article>
+  );
+}
+
+export type { AnalysisResult } from "@/types/analysis";
diff --git a/components/RiskToleranceSelector.tsx b/components/RiskToleranceSelector.tsx
new file mode 100644
index 0000000000000000000000000000000000000000..eaee9cdd16be8ee440c72a86c8e7437ca8d42449
--- /dev/null
+++ b/components/RiskToleranceSelector.tsx
@@ -0,0 +1,46 @@
+"use client";
+
+const RISK_LEVELS = [
+  { id: "conservative", label: "Conservative", description: "Capital preservation with steady returns." },
+  { id: "moderate", label: "Moderate", description: "Balanced growth with measured risk." },
+  { id: "aggressive", label: "Aggressive", description: "Higher growth potential with volatility." },
+  { id: "extremely-aggressive", label: "Extremely Aggressive", description: "Maximum growth with significant risk." },
+] as const;
+
+type RiskToleranceSelectorProps = {
+  value: (typeof RISK_LEVELS)[number]["id"];
+  onChange: (value: (typeof RISK_LEVELS)[number]["id"]) => void;
+};
+
+export function RiskToleranceSelector({ value, onChange }: RiskToleranceSelectorProps) {
+  return (
+    <div className="space-y-4">
+      <label className="block text-sm font-medium text-white/80">Risk tolerance</label>
+      <div className="grid gap-3 sm:grid-cols-2">
+        {RISK_LEVELS.map((risk) => {
+          const isActive = value === risk.id;
+          return (
+            <button
+              key={risk.id}
+              type="button"
+              onClick={() => onChange(risk.id)}
+              className={`rounded-2xl border px-5 py-4 text-left transition ${
+                isActive
+                  ? "border-white/80 bg-white/15 shadow-lg shadow-emerald-500/20"
+                  : "border-white/10 bg-white/5 hover:border-white/30 hover:bg-white/10"
+              }`}
+            >
+              <span className="block text-base font-semibold text-white">
+                {risk.label}
+              </span>
+              <span className="mt-2 block text-sm text-white/70">{risk.description}</span>
+            </button>
+          );
+        })}
+      </div>
+    </div>
+  );
+}
+
+export type RiskLevel = (typeof RISK_LEVELS)[number]["id"];
+export const riskLevels = RISK_LEVELS;
diff --git a/components/ShareButton.tsx b/components/ShareButton.tsx
new file mode 100644
index 0000000000000000000000000000000000000000..5880d9fe1902175bc993271a643a7a8676029453
--- /dev/null
+++ b/components/ShareButton.tsx
@@ -0,0 +1,64 @@
+"use client";
+
+import { useCallback, useEffect, useState } from "react";
+
+import type { AnalysisResult } from "@/types/analysis";
+
+type ShareButtonProps = {
+  result: AnalysisResult;
+};
+
+export function ShareButton({ result }: ShareButtonProps) {
+  const [status, setStatus] = useState<string | null>(null);
+
+  useEffect(() => {
+    setStatus(null);
+  }, [result]);
+
+  const handleShare = useCallback(async () => {
+    const shareUrl = typeof window !== "undefined" ? window.location.href : "";
+    const summaryText = `Portfolio summary: ${result.summary}\nTop suggestion: ${result.suggestions[0] ?? "Review your allocation"}`;
+
+    if (typeof navigator !== "undefined" && navigator.share) {
+      try {
+        await navigator.share({
+          title: "Rate My Portfolio",
+          text: summaryText,
+          url: shareUrl,
+        });
+        setStatus("Shared successfully!");
+      } catch (error) {
+        if ((error as Error).name !== "AbortError") {
+          setStatus("Unable to share automatically. Try copying the link instead.");
+        }
+      }
+      return;
+    }
+
+    if (typeof navigator !== "undefined" && navigator.clipboard) {
+      try {
+        await navigator.clipboard.writeText(shareUrl);
+        setStatus("Link copied to clipboard!");
+      } catch (clipboardError) {
+        console.error("Clipboard share failed", clipboardError);
+        setStatus("Copying the link failed. Try sharing manually.");
+      }
+      return;
+    }
+
+    setStatus("Sharing isn't supported in this browser.");
+  }, [result]);
+
+  return (
+    <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
+      <button
+        type="button"
+        onClick={handleShare}
+        className="inline-flex items-center justify-center rounded-full bg-emerald-400 px-6 py-3 text-sm font-semibold text-emerald-950 transition hover:bg-emerald-300"
+      >
+        Share results
+      </button>
+      {status && <span className="text-xs text-white/70">{status}</span>}
+    </div>
+  );
+}
diff --git a/docs/product-brief.md b/docs/product-brief.md
new file mode 100644
index 0000000000000000000000000000000000000000..d6e1bf618823a11b0335938e37c4a44c75b4aa1c
--- /dev/null
+++ b/docs/product-brief.md
@@ -0,0 +1,17 @@
+# Product brief
+
+The "Rate My Portfolio" experience should:
+
+- Run as a Next.js web application.
+- Let investors upload one or more documents that describe their portfolio (statements, screenshots, notes).
+- Allow the user to specify a risk tolerance: Conservative, Moderate, Aggressive, or Extremely Aggressive.
+- Send the documents and risk tolerance to a backend endpoint that prompts an LLM for analysis.
+- Return a response with ratings across several axes (risk alignment, growth potential, diversification, etc.), narrative commentary, and recommended improvements.
+- Provide a way to share the resulting insights via link sharing or native share sheets.
+- Present the journey with an attractive, modern interface.
+
+The build process followed these steps:
+
+1. Investigated the requirements and designed the end-to-end flow.
+2. Implemented the interface, API route, and AI prompt scaffolding.
+3. Documented configuration and validated the solution with lint checks.
diff --git a/eslint.config.mjs b/eslint.config.mjs
new file mode 100644
index 0000000000000000000000000000000000000000..719cea2b59f3222f4830a756100e1f756b8a18af
--- /dev/null
+++ b/eslint.config.mjs
@@ -0,0 +1,25 @@
+import { dirname } from "path";
+import { fileURLToPath } from "url";
+import { FlatCompat } from "@eslint/eslintrc";
+
+const __filename = fileURLToPath(import.meta.url);
+const __dirname = dirname(__filename);
+
+const compat = new FlatCompat({
+  baseDirectory: __dirname,
+});
+
+const eslintConfig = [
+  ...compat.extends("next/core-web-vitals", "next/typescript"),
+  {
+    ignores: [
+      "node_modules/**",
+      ".next/**",
+      "out/**",
+      "build/**",
+      "next-env.d.ts",
+    ],
+  },
+];
+
+export default eslintConfig;
diff --git a/instructions.md b/instructions.md
index 577c2ff3d7908224c4653fd999625f0e0a1219aa..11d6a8860bfb9c3105a950e8f7677f6435917885 100644
--- a/instructions.md
+++ b/instructions.md
@@ -1,23 +1,23 @@
 I want to create a web app, "Rate My Portfolio". Here's the description:
 
 - the app must be written in next.js
 - this is a web app
 - it will allow users to check their portfolio and rate it
 - the front page will have a control where users will be able to upload files, which can be files describing the portfolio, screenshots, or any other files describing the positions.
-- on the front page, there is also a control to indicate the risk tolerance - convervative, moderate, aggressive or extremely aggressive.
+- on the front page, there is also a control to indicate the risk tolerance - conservative, moderate, aggressive or extremely aggressive.
 - once a user uploads the files and selects the risk tolerance the user will click
 "Rate my portfolio" button
 - when this happen, the files and the goal will be sent to the backend, where we will invoke an LLM with a proper prompt. The LLM will
-respond with portfolio rating, along a few axis (risk, growth, alighment with the goal, etc). It will also provide text discussing the
+respond with portfolio rating, along a few axis (risk, growth, alighnment with the goal, etc). It will also provide text discussing the
 positions and how they contribute to the goal. If there is a misalignment, it will discuss it and suggest improvements. Actually, it
 should suggest improvements in most cases.
 - the user will be able to share this page (there is a "share" button on the results page), either by email, text (link to the page), or
 any other way
 - The app must be slick and attractive, with appealing visual style
 
 The process:
 
 - before coding, investigate the idea completely and come up with a comprehensive plan. Think.
 - implement the plan. Follow the generally accepted software development principles
 - document your work, including the required configuration for the system.
 - test your work as much as possible. If you need user intervention, for example to configure the OPENAI key, stop and ask for it.
diff --git a/lib/prompt.ts b/lib/prompt.ts
new file mode 100644
index 0000000000000000000000000000000000000000..57d6498728c13671b2907b4cd752778e6b024839
--- /dev/null
+++ b/lib/prompt.ts
@@ -0,0 +1,48 @@
+import type { RiskLevel } from "@/components/RiskToleranceSelector";
+
+export const MAX_FILE_CHARACTERS = 2000;
+
+const RISK_DESCRIPTIONS: Record<RiskLevel, string> = {
+  conservative:
+    "The client prefers stability and capital preservation. They accept lower returns in exchange for lower volatility.",
+  moderate:
+    "The client is comfortable with a balance of growth and protection. They can tolerate moderate fluctuations to pursue growth.",
+  aggressive:
+    "The client is willing to embrace meaningful volatility in pursuit of higher long-term appreciation.",
+  "extremely-aggressive":
+    "The client is focused on maximum growth and is comfortable with substantial drawdowns and concentrated exposures.",
+};
+
+export function buildPrompt({
+  riskTolerance,
+  documents,
+}: {
+  riskTolerance: RiskLevel;
+  documents: Array<{ name: string; content: string }>;
+}) {
+  const documentSummaries = documents
+    .map((doc, index) => {
+      const trimmed = doc.content.trim().replace(/\s+/g, " ");
+      return `Document ${index + 1} (${doc.name}): ${trimmed}`;
+    })
+    .join("\n\n");
+
+  return `You are a fiduciary financial advisor evaluating a client's investment portfolio.
+The client identifies their risk tolerance as "${riskTolerance}" which means: ${RISK_DESCRIPTIONS[riskTolerance]}.
+
+You are provided with notes from the client about their holdings, allocation, or objectives:
+${documentSummaries || "No documents were supplied. Ask for more detail."}
+
+Respond with a JSON object that follows this schema:
+{
+  "summary": string // A concise assessment (4-5 sentences) of how well the portfolio aligns with the stated risk tolerance.
+  "ratings": Array<{
+    "axis": string // e.g. "Risk Alignment", "Growth Potential", "Diversification", "Liquidity"
+    "score": string // A short label like "Strong", "Moderate", or "Needs Attention"
+    "explanation": string // 2-3 sentences explaining the score with references to the provided holdings
+  }>
+  "suggestions": string[] // 3-5 actionable steps that the client can take to close gaps or improve the portfolio alignment
+}
+
+Always recommend improvements or adjustments, even if the portfolio is generally aligned. Avoid markdown in the JSON.`;
+}
diff --git a/next.config.ts b/next.config.ts
new file mode 100644
index 0000000000000000000000000000000000000000..e9ffa3083ad279ecf95fd8eae59cb253e9a539c4
--- /dev/null
+++ b/next.config.ts
@@ -0,0 +1,7 @@
+import type { NextConfig } from "next";
+
+const nextConfig: NextConfig = {
+  /* config options here */
+};
+
+export default nextConfig;
diff --git a/package-lock.json b/package-lock.json
new file mode 100644
index 0000000000000000000000000000000000000000..470a75aeeb2c399a754d2c8e5d8520bfe9af1174
--- /dev/null
+++ b/package-lock.json
@@ -0,0 +1,6123 @@
+{
+  "name": "ratemyportfolio",
+  "version": "0.1.0",
+  "lockfileVersion": 3,
+  "requires": true,
+  "packages": {
+    "": {
+      "name": "ratemyportfolio",
+      "version": "0.1.0",
+      "dependencies": {
+        "next": "15.5.4",
+        "openai": "^6.0.0",
+        "react": "19.1.0",
+        "react-dom": "19.1.0"
+      },
+      "devDependencies": {
+        "@eslint/eslintrc": "^3",
+        "@tailwindcss/postcss": "^4",
+        "@types/node": "^20",
+        "@types/react": "^19",
+        "@types/react-dom": "^19",
+        "eslint": "^9",
+        "eslint-config-next": "15.5.4",
+        "tailwindcss": "^4",
+        "typescript": "^5"
+      }
+    },
+    "node_modules/@alloc/quick-lru": {
+      "version": "5.2.0",
+      "resolved": "https://registry.npmjs.org/@alloc/quick-lru/-/quick-lru-5.2.0.tgz",
+      "integrity": "sha512-UrcABB+4bUrFABwbluTIBErXwvbsU/V7TZWfmbgJfbkwiBuziS9gxdODUyuiecfdGQ85jglMW6juS3+z5TsKLw==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=10"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    },
+    "node_modules/@emnapi/core": {
+      "version": "1.5.0",
+      "resolved": "https://registry.npmjs.org/@emnapi/core/-/core-1.5.0.tgz",
+      "integrity": "sha512-sbP8GzB1WDzacS8fgNPpHlp6C9VZe+SJP3F90W9rLemaQj2PzIuTEl1qDOYQf58YIpyjViI24y9aPWCjEzY2cg==",
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "dependencies": {
+        "@emnapi/wasi-threads": "1.1.0",
+        "tslib": "^2.4.0"
+      }
+    },
+    "node_modules/@emnapi/runtime": {
+      "version": "1.5.0",
+      "resolved": "https://registry.npmjs.org/@emnapi/runtime/-/runtime-1.5.0.tgz",
+      "integrity": "sha512-97/BJ3iXHww3djw6hYIfErCZFee7qCtrneuLa20UXFCOTCfBM2cvQHjWJ2EG0s0MtdNwInarqCTz35i4wWXHsQ==",
+      "license": "MIT",
+      "optional": true,
+      "dependencies": {
+        "tslib": "^2.4.0"
+      }
+    },
+    "node_modules/@emnapi/wasi-threads": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/@emnapi/wasi-threads/-/wasi-threads-1.1.0.tgz",
+      "integrity": "sha512-WI0DdZ8xFSbgMjR1sFsKABJ/C5OnRrjT06JXbZKexJGrDuPTzZdDYfFlsgcCXCyf+suG5QU2e/y1Wo2V/OapLQ==",
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "dependencies": {
+        "tslib": "^2.4.0"
+      }
+    },
+    "node_modules/@eslint-community/eslint-utils": {
+      "version": "4.9.0",
+      "resolved": "https://registry.npmjs.org/@eslint-community/eslint-utils/-/eslint-utils-4.9.0.tgz",
+      "integrity": "sha512-ayVFHdtZ+hsq1t2Dy24wCmGXGe4q9Gu3smhLYALJrr473ZH27MsnSL+LKUlimp4BWJqMDMLmPpx/Q9R3OAlL4g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "eslint-visitor-keys": "^3.4.3"
+      },
+      "engines": {
+        "node": "^12.22.0 || ^14.17.0 || >=16.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/eslint"
+      },
+      "peerDependencies": {
+        "eslint": "^6.0.0 || ^7.0.0 || >=8.0.0"
+      }
+    },
+    "node_modules/@eslint-community/eslint-utils/node_modules/eslint-visitor-keys": {
+      "version": "3.4.3",
+      "resolved": "https://registry.npmjs.org/eslint-visitor-keys/-/eslint-visitor-keys-3.4.3.tgz",
+      "integrity": "sha512-wpc+LXeiyiisxPlEkUzU6svyS1frIO3Mgxj1fdy7Pm8Ygzguax2N3Fa/D/ag1WqbOprdI+uY6wMUl8/a2G+iag==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": "^12.22.0 || ^14.17.0 || >=16.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/eslint"
+      }
+    },
+    "node_modules/@eslint-community/regexpp": {
+      "version": "4.12.1",
+      "resolved": "https://registry.npmjs.org/@eslint-community/regexpp/-/regexpp-4.12.1.tgz",
+      "integrity": "sha512-CCZCDJuduB9OUkFkY2IgppNZMi2lBQgD2qzwXkEia16cge2pijY/aXi96CJMquDMn3nJdlPV1A5KrJEXwfLNzQ==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": "^12.0.0 || ^14.0.0 || >=16.0.0"
+      }
+    },
+    "node_modules/@eslint/config-array": {
+      "version": "0.21.0",
+      "resolved": "https://registry.npmjs.org/@eslint/config-array/-/config-array-0.21.0.tgz",
+      "integrity": "sha512-ENIdc4iLu0d93HeYirvKmrzshzofPw6VkZRKQGe9Nv46ZnWUzcF1xV01dcvEg/1wXUR61OmmlSfyeyO7EvjLxQ==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "dependencies": {
+        "@eslint/object-schema": "^2.1.6",
+        "debug": "^4.3.1",
+        "minimatch": "^3.1.2"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      }
+    },
+    "node_modules/@eslint/config-helpers": {
+      "version": "0.3.1",
+      "resolved": "https://registry.npmjs.org/@eslint/config-helpers/-/config-helpers-0.3.1.tgz",
+      "integrity": "sha512-xR93k9WhrDYpXHORXpxVL5oHj3Era7wo6k/Wd8/IsQNnZUTzkGS29lyn3nAT05v6ltUuTFVCCYDEGfy2Or/sPA==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      }
+    },
+    "node_modules/@eslint/core": {
+      "version": "0.15.2",
+      "resolved": "https://registry.npmjs.org/@eslint/core/-/core-0.15.2.tgz",
+      "integrity": "sha512-78Md3/Rrxh83gCxoUc0EiciuOHsIITzLy53m3d9UyiW8y9Dj2D29FeETqyKA+BRK76tnTp6RXWb3pCay8Oyomg==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "dependencies": {
+        "@types/json-schema": "^7.0.15"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      }
+    },
+    "node_modules/@eslint/eslintrc": {
+      "version": "3.3.1",
+      "resolved": "https://registry.npmjs.org/@eslint/eslintrc/-/eslintrc-3.3.1.tgz",
+      "integrity": "sha512-gtF186CXhIl1p4pJNGZw8Yc6RlshoePRvE0X91oPGb3vZ8pM3qOS9W9NGPat9LziaBV7XrJWGylNQXkGcnM3IQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "ajv": "^6.12.4",
+        "debug": "^4.3.2",
+        "espree": "^10.0.1",
+        "globals": "^14.0.0",
+        "ignore": "^5.2.0",
+        "import-fresh": "^3.2.1",
+        "js-yaml": "^4.1.0",
+        "minimatch": "^3.1.2",
+        "strip-json-comments": "^3.1.1"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/eslint"
+      }
+    },
+    "node_modules/@eslint/js": {
+      "version": "9.36.0",
+      "resolved": "https://registry.npmjs.org/@eslint/js/-/js-9.36.0.tgz",
+      "integrity": "sha512-uhCbYtYynH30iZErszX78U+nR3pJU3RHGQ57NXy5QupD4SBVwDeU8TNBy+MjMngc1UyIW9noKqsRqfjQTBU2dw==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "url": "https://eslint.org/donate"
+      }
+    },
+    "node_modules/@eslint/object-schema": {
+      "version": "2.1.6",
+      "resolved": "https://registry.npmjs.org/@eslint/object-schema/-/object-schema-2.1.6.tgz",
+      "integrity": "sha512-RBMg5FRL0I0gs51M/guSAj5/e14VQ4tpZnQNWwuDT66P14I43ItmPfIZRhO9fUVIPOAQXU47atlywZ/czoqFPA==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      }
+    },
+    "node_modules/@eslint/plugin-kit": {
+      "version": "0.3.5",
+      "resolved": "https://registry.npmjs.org/@eslint/plugin-kit/-/plugin-kit-0.3.5.tgz",
+      "integrity": "sha512-Z5kJ+wU3oA7MMIqVR9tyZRtjYPr4OC004Q4Rw7pgOKUOKkJfZ3O24nz3WYfGRpMDNmcOi3TwQOmgm7B7Tpii0w==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "dependencies": {
+        "@eslint/core": "^0.15.2",
+        "levn": "^0.4.1"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      }
+    },
+    "node_modules/@humanfs/core": {
+      "version": "0.19.1",
+      "resolved": "https://registry.npmjs.org/@humanfs/core/-/core-0.19.1.tgz",
+      "integrity": "sha512-5DyQ4+1JEUzejeK1JGICcideyfUbGixgS9jNgex5nqkW+cY7WZhxBigmieN5Qnw9ZosSNVC9KQKyb+GUaGyKUA==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": ">=18.18.0"
+      }
+    },
+    "node_modules/@humanfs/node": {
+      "version": "0.16.7",
+      "resolved": "https://registry.npmjs.org/@humanfs/node/-/node-0.16.7.tgz",
+      "integrity": "sha512-/zUx+yOsIrG4Y43Eh2peDeKCxlRt/gET6aHfaKpuq267qXdYDFViVHfMaLyygZOnl0kGWxFIgsBy8QFuTLUXEQ==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "dependencies": {
+        "@humanfs/core": "^0.19.1",
+        "@humanwhocodes/retry": "^0.4.0"
+      },
+      "engines": {
+        "node": ">=18.18.0"
+      }
+    },
+    "node_modules/@humanwhocodes/module-importer": {
+      "version": "1.0.1",
+      "resolved": "https://registry.npmjs.org/@humanwhocodes/module-importer/-/module-importer-1.0.1.tgz",
+      "integrity": "sha512-bxveV4V8v5Yb4ncFTT3rPSgZBOpCkjfK0y4oVVVJwIuDVBRMDXrPyXRL988i5ap9m9bnyEEjWfm5WkBmtffLfA==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": ">=12.22"
+      },
+      "funding": {
+        "type": "github",
+        "url": "https://github.com/sponsors/nzakas"
+      }
+    },
+    "node_modules/@humanwhocodes/retry": {
+      "version": "0.4.3",
+      "resolved": "https://registry.npmjs.org/@humanwhocodes/retry/-/retry-0.4.3.tgz",
+      "integrity": "sha512-bV0Tgo9K4hfPCek+aMAn81RppFKv2ySDQeMoSZuvTASywNTnVJCArCZE2FWqpvIatKu7VMRLWlR1EazvVhDyhQ==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": ">=18.18"
+      },
+      "funding": {
+        "type": "github",
+        "url": "https://github.com/sponsors/nzakas"
+      }
+    },
+    "node_modules/@img/colour": {
+      "version": "1.0.0",
+      "resolved": "https://registry.npmjs.org/@img/colour/-/colour-1.0.0.tgz",
+      "integrity": "sha512-A5P/LfWGFSl6nsckYtjw9da+19jB8hkJ6ACTGcDfEJ0aE+l2n2El7dsVM7UVHZQ9s2lmYMWlrS21YLy2IR1LUw==",
+      "license": "MIT",
+      "optional": true,
+      "engines": {
+        "node": ">=18"
+      }
+    },
+    "node_modules/@img/sharp-darwin-arm64": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-darwin-arm64/-/sharp-darwin-arm64-0.34.4.tgz",
+      "integrity": "sha512-sitdlPzDVyvmINUdJle3TNHl+AG9QcwiAMsXmccqsCOMZNIdW2/7S26w0LyU8euiLVzFBL3dXPwVCq/ODnf2vA==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-darwin-arm64": "1.2.3"
+      }
+    },
+    "node_modules/@img/sharp-darwin-x64": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-darwin-x64/-/sharp-darwin-x64-0.34.4.tgz",
+      "integrity": "sha512-rZheupWIoa3+SOdF/IcUe1ah4ZDpKBGWcsPX6MT0lYniH9micvIU7HQkYTfrx5Xi8u+YqwLtxC/3vl8TQN6rMg==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-darwin-x64": "1.2.3"
+      }
+    },
+    "node_modules/@img/sharp-libvips-darwin-arm64": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-darwin-arm64/-/sharp-libvips-darwin-arm64-1.2.3.tgz",
+      "integrity": "sha512-QzWAKo7kpHxbuHqUC28DZ9pIKpSi2ts2OJnoIGI26+HMgq92ZZ4vk8iJd4XsxN+tYfNJxzH6W62X5eTcsBymHw==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-darwin-x64": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-darwin-x64/-/sharp-libvips-darwin-x64-1.2.3.tgz",
+      "integrity": "sha512-Ju+g2xn1E2AKO6YBhxjj+ACcsPQRHT0bhpglxcEf+3uyPY+/gL8veniKoo96335ZaPo03bdDXMv0t+BBFAbmRA==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-arm": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-arm/-/sharp-libvips-linux-arm-1.2.3.tgz",
+      "integrity": "sha512-x1uE93lyP6wEwGvgAIV0gP6zmaL/a0tGzJs/BIDDG0zeBhMnuUPm7ptxGhUbcGs4okDJrk4nxgrmxpib9g6HpA==",
+      "cpu": [
+        "arm"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-arm64": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-arm64/-/sharp-libvips-linux-arm64-1.2.3.tgz",
+      "integrity": "sha512-I4RxkXU90cpufazhGPyVujYwfIm9Nk1QDEmiIsaPwdnm013F7RIceaCc87kAH+oUB1ezqEvC6ga4m7MSlqsJvQ==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-ppc64": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-ppc64/-/sharp-libvips-linux-ppc64-1.2.3.tgz",
+      "integrity": "sha512-Y2T7IsQvJLMCBM+pmPbM3bKT/yYJvVtLJGfCs4Sp95SjvnFIjynbjzsa7dY1fRJX45FTSfDksbTp6AGWudiyCg==",
+      "cpu": [
+        "ppc64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-s390x": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-s390x/-/sharp-libvips-linux-s390x-1.2.3.tgz",
+      "integrity": "sha512-RgWrs/gVU7f+K7P+KeHFaBAJlNkD1nIZuVXdQv6S+fNA6syCcoboNjsV2Pou7zNlVdNQoQUpQTk8SWDHUA3y/w==",
+      "cpu": [
+        "s390x"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-x64": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-x64/-/sharp-libvips-linux-x64-1.2.3.tgz",
+      "integrity": "sha512-3JU7LmR85K6bBiRzSUc/Ff9JBVIFVvq6bomKE0e63UXGeRw2HPVEjoJke1Yx+iU4rL7/7kUjES4dZ/81Qjhyxg==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linuxmusl-arm64": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linuxmusl-arm64/-/sharp-libvips-linuxmusl-arm64-1.2.3.tgz",
+      "integrity": "sha512-F9q83RZ8yaCwENw1GieztSfj5msz7GGykG/BA+MOUefvER69K/ubgFHNeSyUu64amHIYKGDs4sRCMzXVj8sEyw==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linuxmusl-x64": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linuxmusl-x64/-/sharp-libvips-linuxmusl-x64-1.2.3.tgz",
+      "integrity": "sha512-U5PUY5jbc45ANM6tSJpsgqmBF/VsL6LnxJmIf11kB7J5DctHgqm0SkuXzVWtIY90GnJxKnC/JT251TDnk1fu/g==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-linux-arm": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-arm/-/sharp-linux-arm-0.34.4.tgz",
+      "integrity": "sha512-Xyam4mlqM0KkTHYVSuc6wXRmM7LGN0P12li03jAnZ3EJWZqj83+hi8Y9UxZUbxsgsK1qOEwg7O0Bc0LjqQVtxA==",
+      "cpu": [
+        "arm"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-arm": "1.2.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-arm64": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-arm64/-/sharp-linux-arm64-0.34.4.tgz",
+      "integrity": "sha512-YXU1F/mN/Wu786tl72CyJjP/Ngl8mGHN1hST4BGl+hiW5jhCnV2uRVTNOcaYPs73NeT/H8Upm3y9582JVuZHrQ==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-arm64": "1.2.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-ppc64": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-ppc64/-/sharp-linux-ppc64-0.34.4.tgz",
+      "integrity": "sha512-F4PDtF4Cy8L8hXA2p3TO6s4aDt93v+LKmpcYFLAVdkkD3hSxZzee0rh6/+94FpAynsuMpLX5h+LRsSG3rIciUQ==",
+      "cpu": [
+        "ppc64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-ppc64": "1.2.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-s390x": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-s390x/-/sharp-linux-s390x-0.34.4.tgz",
+      "integrity": "sha512-qVrZKE9Bsnzy+myf7lFKvng6bQzhNUAYcVORq2P7bDlvmF6u2sCmK2KyEQEBdYk+u3T01pVsPrkj943T1aJAsw==",
+      "cpu": [
+        "s390x"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-s390x": "1.2.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-x64": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-x64/-/sharp-linux-x64-0.34.4.tgz",
+      "integrity": "sha512-ZfGtcp2xS51iG79c6Vhw9CWqQC8l2Ot8dygxoDoIQPTat/Ov3qAa8qpxSrtAEAJW+UjTXc4yxCjNfxm4h6Xm2A==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-x64": "1.2.3"
+      }
+    },
+    "node_modules/@img/sharp-linuxmusl-arm64": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linuxmusl-arm64/-/sharp-linuxmusl-arm64-0.34.4.tgz",
+      "integrity": "sha512-8hDVvW9eu4yHWnjaOOR8kHVrew1iIX+MUgwxSuH2XyYeNRtLUe4VNioSqbNkB7ZYQJj9rUTT4PyRscyk2PXFKA==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linuxmusl-arm64": "1.2.3"
+      }
+    },
+    "node_modules/@img/sharp-linuxmusl-x64": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linuxmusl-x64/-/sharp-linuxmusl-x64-0.34.4.tgz",
+      "integrity": "sha512-lU0aA5L8QTlfKjpDCEFOZsTYGn3AEiO6db8W5aQDxj0nQkVrZWmN3ZP9sYKWJdtq3PWPhUNlqehWyXpYDcI9Sg==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linuxmusl-x64": "1.2.3"
+      }
+    },
+    "node_modules/@img/sharp-wasm32": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-wasm32/-/sharp-wasm32-0.34.4.tgz",
+      "integrity": "sha512-33QL6ZO/qpRyG7woB/HUALz28WnTMI2W1jgX3Nu2bypqLIKx/QKMILLJzJjI+SIbvXdG9fUnmrxR7vbi1sTBeA==",
+      "cpu": [
+        "wasm32"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later AND MIT",
+      "optional": true,
+      "dependencies": {
+        "@emnapi/runtime": "^1.5.0"
+      },
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-win32-arm64": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-win32-arm64/-/sharp-win32-arm64-0.34.4.tgz",
+      "integrity": "sha512-2Q250do/5WXTwxW3zjsEuMSv5sUU4Tq9VThWKlU2EYLm4MB7ZeMwF+SFJutldYODXF6jzc6YEOC+VfX0SZQPqA==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-win32-ia32": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-win32-ia32/-/sharp-win32-ia32-0.34.4.tgz",
+      "integrity": "sha512-3ZeLue5V82dT92CNL6rsal6I2weKw1cYu+rGKm8fOCCtJTR2gYeUfY3FqUnIJsMUPIH68oS5jmZ0NiJ508YpEw==",
+      "cpu": [
+        "ia32"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-win32-x64": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-win32-x64/-/sharp-win32-x64-0.34.4.tgz",
+      "integrity": "sha512-xIyj4wpYs8J18sVN3mSQjwrw7fKUqRw+Z5rnHNCy5fYTxigBz81u5mOMPmFumwjcn8+ld1ppptMBCLic1nz6ig==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@isaacs/fs-minipass": {
+      "version": "4.0.1",
+      "resolved": "https://registry.npmjs.org/@isaacs/fs-minipass/-/fs-minipass-4.0.1.tgz",
+      "integrity": "sha512-wgm9Ehl2jpeqP3zw/7mo3kRHFp5MEDhqAdwy1fTGkHAwnkGOVsgpvQhL8B5n1qlb01jV3n/bI0ZfZp5lWA1k4w==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "minipass": "^7.0.4"
+      },
+      "engines": {
+        "node": ">=18.0.0"
+      }
+    },
+    "node_modules/@jridgewell/gen-mapping": {
+      "version": "0.3.13",
+      "resolved": "https://registry.npmjs.org/@jridgewell/gen-mapping/-/gen-mapping-0.3.13.tgz",
+      "integrity": "sha512-2kkt/7niJ6MgEPxF0bYdQ6etZaA+fQvDcLKckhy1yIQOzaoKjBBjSj63/aLVjYE3qhRt5dvM+uUyfCg6UKCBbA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@jridgewell/sourcemap-codec": "^1.5.0",
+        "@jridgewell/trace-mapping": "^0.3.24"
+      }
+    },
+    "node_modules/@jridgewell/remapping": {
+      "version": "2.3.5",
+      "resolved": "https://registry.npmjs.org/@jridgewell/remapping/-/remapping-2.3.5.tgz",
+      "integrity": "sha512-LI9u/+laYG4Ds1TDKSJW2YPrIlcVYOwi2fUC6xB43lueCjgxV4lffOCZCtYFiH6TNOX+tQKXx97T4IKHbhyHEQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@jridgewell/gen-mapping": "^0.3.5",
+        "@jridgewell/trace-mapping": "^0.3.24"
+      }
+    },
+    "node_modules/@jridgewell/resolve-uri": {
+      "version": "3.1.2",
+      "resolved": "https://registry.npmjs.org/@jridgewell/resolve-uri/-/resolve-uri-3.1.2.tgz",
+      "integrity": "sha512-bRISgCIjP20/tbWSPWMEi54QVPRZExkuD9lJL+UIxUKtwVJA8wW1Trb1jMs1RFXo1CBTNZ/5hpC9QvmKWdopKw==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=6.0.0"
+      }
+    },
+    "node_modules/@jridgewell/sourcemap-codec": {
+      "version": "1.5.5",
+      "resolved": "https://registry.npmjs.org/@jridgewell/sourcemap-codec/-/sourcemap-codec-1.5.5.tgz",
+      "integrity": "sha512-cYQ9310grqxueWbl+WuIUIaiUaDcj7WOq5fVhEljNVgRfOUhY9fy2zTvfoqWsnebh8Sl70VScFbICvJnLKB0Og==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/@jridgewell/trace-mapping": {
+      "version": "0.3.31",
+      "resolved": "https://registry.npmjs.org/@jridgewell/trace-mapping/-/trace-mapping-0.3.31.tgz",
+      "integrity": "sha512-zzNR+SdQSDJzc8joaeP8QQoCQr8NuYx2dIIytl1QeBEZHJ9uW6hebsrYgbz8hJwUQao3TWCMtmfV8Nu1twOLAw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@jridgewell/resolve-uri": "^3.1.0",
+        "@jridgewell/sourcemap-codec": "^1.4.14"
+      }
+    },
+    "node_modules/@napi-rs/wasm-runtime": {
+      "version": "0.2.12",
+      "resolved": "https://registry.npmjs.org/@napi-rs/wasm-runtime/-/wasm-runtime-0.2.12.tgz",
+      "integrity": "sha512-ZVWUcfwY4E/yPitQJl481FjFo3K22D6qF0DuFH6Y/nbnE11GY5uguDxZMGXPQ8WQ0128MXQD7TnfHyK4oWoIJQ==",
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "dependencies": {
+        "@emnapi/core": "^1.4.3",
+        "@emnapi/runtime": "^1.4.3",
+        "@tybys/wasm-util": "^0.10.0"
+      }
+    },
+    "node_modules/@next/env": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/env/-/env-15.5.4.tgz",
+      "integrity": "sha512-27SQhYp5QryzIT5uO8hq99C69eLQ7qkzkDPsk3N+GuS2XgOgoYEeOav7Pf8Tn4drECOVDsDg8oj+/DVy8qQL2A==",
+      "license": "MIT"
+    },
+    "node_modules/@next/eslint-plugin-next": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/eslint-plugin-next/-/eslint-plugin-next-15.5.4.tgz",
+      "integrity": "sha512-SR1vhXNNg16T4zffhJ4TS7Xn7eq4NfKfcOsRwea7RIAHrjRpI9ALYbamqIJqkAhowLlERffiwk0FMvTLNdnVtw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "fast-glob": "3.3.1"
+      }
+    },
+    "node_modules/@next/swc-darwin-arm64": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/swc-darwin-arm64/-/swc-darwin-arm64-15.5.4.tgz",
+      "integrity": "sha512-nopqz+Ov6uvorej8ndRX6HlxCYWCO3AHLfKK2TYvxoSB2scETOcfm/HSS3piPqc3A+MUgyHoqE6je4wnkjfrOA==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@next/swc-darwin-x64": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/swc-darwin-x64/-/swc-darwin-x64-15.5.4.tgz",
+      "integrity": "sha512-QOTCFq8b09ghfjRJKfb68kU9k2K+2wsC4A67psOiMn849K9ZXgCSRQr0oVHfmKnoqCbEmQWG1f2h1T2vtJJ9mA==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@next/swc-linux-arm64-gnu": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/swc-linux-arm64-gnu/-/swc-linux-arm64-gnu-15.5.4.tgz",
+      "integrity": "sha512-eRD5zkts6jS3VfE/J0Kt1VxdFqTnMc3QgO5lFE5GKN3KDI/uUpSyK3CjQHmfEkYR4wCOl0R0XrsjpxfWEA++XA==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@next/swc-linux-arm64-musl": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/swc-linux-arm64-musl/-/swc-linux-arm64-musl-15.5.4.tgz",
+      "integrity": "sha512-TOK7iTxmXFc45UrtKqWdZ1shfxuL4tnVAOuuJK4S88rX3oyVV4ZkLjtMT85wQkfBrOOvU55aLty+MV8xmcJR8A==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@next/swc-linux-x64-gnu": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/swc-linux-x64-gnu/-/swc-linux-x64-gnu-15.5.4.tgz",
+      "integrity": "sha512-7HKolaj+481FSW/5lL0BcTkA4Ueam9SPYWyN/ib/WGAFZf0DGAN8frNpNZYFHtM4ZstrHZS3LY3vrwlIQfsiMA==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@next/swc-linux-x64-musl": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/swc-linux-x64-musl/-/swc-linux-x64-musl-15.5.4.tgz",
+      "integrity": "sha512-nlQQ6nfgN0nCO/KuyEUwwOdwQIGjOs4WNMjEUtpIQJPR2NUfmGpW2wkJln1d4nJ7oUzd1g4GivH5GoEPBgfsdw==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@next/swc-win32-arm64-msvc": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/swc-win32-arm64-msvc/-/swc-win32-arm64-msvc-15.5.4.tgz",
+      "integrity": "sha512-PcR2bN7FlM32XM6eumklmyWLLbu2vs+D7nJX8OAIoWy69Kef8mfiN4e8TUv2KohprwifdpFKPzIP1njuCjD0YA==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@next/swc-win32-x64-msvc": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/@next/swc-win32-x64-msvc/-/swc-win32-x64-msvc-15.5.4.tgz",
+      "integrity": "sha512-1ur2tSHZj8Px/KMAthmuI9FMp/YFusMMGoRNJaRZMOlSkgvLjzosSdQI0cJAKogdHl3qXUQKL9MGaYvKwA7DXg==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@nodelib/fs.scandir": {
+      "version": "2.1.5",
+      "resolved": "https://registry.npmjs.org/@nodelib/fs.scandir/-/fs.scandir-2.1.5.tgz",
+      "integrity": "sha512-vq24Bq3ym5HEQm2NKCr3yXDwjc7vTsEThRDnkp2DK9p1uqLR+DHurm/NOTo0KG7HYHU7eppKZj3MyqYuMBf62g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@nodelib/fs.stat": "2.0.5",
+        "run-parallel": "^1.1.9"
+      },
+      "engines": {
+        "node": ">= 8"
+      }
+    },
+    "node_modules/@nodelib/fs.stat": {
+      "version": "2.0.5",
+      "resolved": "https://registry.npmjs.org/@nodelib/fs.stat/-/fs.stat-2.0.5.tgz",
+      "integrity": "sha512-RkhPPp2zrqDAQA/2jNhnztcPAlv64XdhIp7a7454A5ovI7Bukxgt7MX7udwAu3zg1DcpPU0rz3VV1SeaqvY4+A==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 8"
+      }
+    },
+    "node_modules/@nodelib/fs.walk": {
+      "version": "1.2.8",
+      "resolved": "https://registry.npmjs.org/@nodelib/fs.walk/-/fs.walk-1.2.8.tgz",
+      "integrity": "sha512-oGB+UxlgWcgQkgwo8GcEGwemoTFt3FIO9ababBmaGwXIoBKZ+GTy0pP185beGg7Llih/NSHSV2XAs1lnznocSg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@nodelib/fs.scandir": "2.1.5",
+        "fastq": "^1.6.0"
+      },
+      "engines": {
+        "node": ">= 8"
+      }
+    },
+    "node_modules/@nolyfill/is-core-module": {
+      "version": "1.0.39",
+      "resolved": "https://registry.npmjs.org/@nolyfill/is-core-module/-/is-core-module-1.0.39.tgz",
+      "integrity": "sha512-nn5ozdjYQpUCZlWGuxcJY/KpxkWQs4DcbMCmKojjyrYDEAGy4Ce19NN4v5MduafTwJlbKc99UA8YhSVqq9yPZA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=12.4.0"
+      }
+    },
+    "node_modules/@rtsao/scc": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/@rtsao/scc/-/scc-1.1.0.tgz",
+      "integrity": "sha512-zt6OdqaDoOnJ1ZYsCYGt9YmWzDXl4vQdKTyJev62gFhRGKdx7mcT54V9KIjg+d2wi9EXsPvAPKe7i7WjfVWB8g==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/@rushstack/eslint-patch": {
+      "version": "1.12.0",
+      "resolved": "https://registry.npmjs.org/@rushstack/eslint-patch/-/eslint-patch-1.12.0.tgz",
+      "integrity": "sha512-5EwMtOqvJMMa3HbmxLlF74e+3/HhwBTMcvt3nqVJgGCozO6hzIPOBlwm8mGVNR9SN2IJpxSnlxczyDjcn7qIyw==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/@swc/helpers": {
+      "version": "0.5.15",
+      "resolved": "https://registry.npmjs.org/@swc/helpers/-/helpers-0.5.15.tgz",
+      "integrity": "sha512-JQ5TuMi45Owi4/BIMAJBoSQoOJu12oOk/gADqlcUL9JEdHB8vyjUSsxqeNXnmXHjYKMi2WcYtezGEEhqUI/E2g==",
+      "license": "Apache-2.0",
+      "dependencies": {
+        "tslib": "^2.8.0"
+      }
+    },
+    "node_modules/@tailwindcss/node": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/node/-/node-4.1.13.tgz",
+      "integrity": "sha512-eq3ouolC1oEFOAvOMOBAmfCIqZBJuvWvvYWh5h5iOYfe1HFC6+GZ6EIL0JdM3/niGRJmnrOc+8gl9/HGUaaptw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@jridgewell/remapping": "^2.3.4",
+        "enhanced-resolve": "^5.18.3",
+        "jiti": "^2.5.1",
+        "lightningcss": "1.30.1",
+        "magic-string": "^0.30.18",
+        "source-map-js": "^1.2.1",
+        "tailwindcss": "4.1.13"
+      }
+    },
+    "node_modules/@tailwindcss/oxide": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide/-/oxide-4.1.13.tgz",
+      "integrity": "sha512-CPgsM1IpGRa880sMbYmG1s4xhAy3xEt1QULgTJGQmZUeNgXFR7s1YxYygmJyBGtou4SyEosGAGEeYqY7R53bIA==",
+      "dev": true,
+      "hasInstallScript": true,
+      "license": "MIT",
+      "dependencies": {
+        "detect-libc": "^2.0.4",
+        "tar": "^7.4.3"
+      },
+      "engines": {
+        "node": ">= 10"
+      },
+      "optionalDependencies": {
+        "@tailwindcss/oxide-android-arm64": "4.1.13",
+        "@tailwindcss/oxide-darwin-arm64": "4.1.13",
+        "@tailwindcss/oxide-darwin-x64": "4.1.13",
+        "@tailwindcss/oxide-freebsd-x64": "4.1.13",
+        "@tailwindcss/oxide-linux-arm-gnueabihf": "4.1.13",
+        "@tailwindcss/oxide-linux-arm64-gnu": "4.1.13",
+        "@tailwindcss/oxide-linux-arm64-musl": "4.1.13",
+        "@tailwindcss/oxide-linux-x64-gnu": "4.1.13",
+        "@tailwindcss/oxide-linux-x64-musl": "4.1.13",
+        "@tailwindcss/oxide-wasm32-wasi": "4.1.13",
+        "@tailwindcss/oxide-win32-arm64-msvc": "4.1.13",
+        "@tailwindcss/oxide-win32-x64-msvc": "4.1.13"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-android-arm64": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-android-arm64/-/oxide-android-arm64-4.1.13.tgz",
+      "integrity": "sha512-BrpTrVYyejbgGo57yc8ieE+D6VT9GOgnNdmh5Sac6+t0m+v+sKQevpFVpwX3pBrM2qKrQwJ0c5eDbtjouY/+ew==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "android"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-darwin-arm64": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-darwin-arm64/-/oxide-darwin-arm64-4.1.13.tgz",
+      "integrity": "sha512-YP+Jksc4U0KHcu76UhRDHq9bx4qtBftp9ShK/7UGfq0wpaP96YVnnjFnj3ZFrUAjc5iECzODl/Ts0AN7ZPOANQ==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-darwin-x64": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-darwin-x64/-/oxide-darwin-x64-4.1.13.tgz",
+      "integrity": "sha512-aAJ3bbwrn/PQHDxCto9sxwQfT30PzyYJFG0u/BWZGeVXi5Hx6uuUOQEI2Fa43qvmUjTRQNZnGqe9t0Zntexeuw==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-freebsd-x64": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-freebsd-x64/-/oxide-freebsd-x64-4.1.13.tgz",
+      "integrity": "sha512-Wt8KvASHwSXhKE/dJLCCWcTSVmBj3xhVhp/aF3RpAhGeZ3sVo7+NTfgiN8Vey/Fi8prRClDs6/f0KXPDTZE6nQ==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "freebsd"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-linux-arm-gnueabihf": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-linux-arm-gnueabihf/-/oxide-linux-arm-gnueabihf-4.1.13.tgz",
+      "integrity": "sha512-mbVbcAsW3Gkm2MGwA93eLtWrwajz91aXZCNSkGTx/R5eb6KpKD5q8Ueckkh9YNboU8RH7jiv+ol/I7ZyQ9H7Bw==",
+      "cpu": [
+        "arm"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-linux-arm64-gnu": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-linux-arm64-gnu/-/oxide-linux-arm64-gnu-4.1.13.tgz",
+      "integrity": "sha512-wdtfkmpXiwej/yoAkrCP2DNzRXCALq9NVLgLELgLim1QpSfhQM5+ZxQQF8fkOiEpuNoKLp4nKZ6RC4kmeFH0HQ==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-linux-arm64-musl": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-linux-arm64-musl/-/oxide-linux-arm64-musl-4.1.13.tgz",
+      "integrity": "sha512-hZQrmtLdhyqzXHB7mkXfq0IYbxegaqTmfa1p9MBj72WPoDD3oNOh1Lnxf6xZLY9C3OV6qiCYkO1i/LrzEdW2mg==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-linux-x64-gnu": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-linux-x64-gnu/-/oxide-linux-x64-gnu-4.1.13.tgz",
+      "integrity": "sha512-uaZTYWxSXyMWDJZNY1Ul7XkJTCBRFZ5Fo6wtjrgBKzZLoJNrG+WderJwAjPzuNZOnmdrVg260DKwXCFtJ/hWRQ==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-linux-x64-musl": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-linux-x64-musl/-/oxide-linux-x64-musl-4.1.13.tgz",
+      "integrity": "sha512-oXiPj5mi4Hdn50v5RdnuuIms0PVPI/EG4fxAfFiIKQh5TgQgX7oSuDWntHW7WNIi/yVLAiS+CRGW4RkoGSSgVQ==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-wasm32-wasi": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-wasm32-wasi/-/oxide-wasm32-wasi-4.1.13.tgz",
+      "integrity": "sha512-+LC2nNtPovtrDwBc/nqnIKYh/W2+R69FA0hgoeOn64BdCX522u19ryLh3Vf3F8W49XBcMIxSe665kwy21FkhvA==",
+      "bundleDependencies": [
+        "@napi-rs/wasm-runtime",
+        "@emnapi/core",
+        "@emnapi/runtime",
+        "@tybys/wasm-util",
+        "@emnapi/wasi-threads",
+        "tslib"
+      ],
+      "cpu": [
+        "wasm32"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "dependencies": {
+        "@emnapi/core": "^1.4.5",
+        "@emnapi/runtime": "^1.4.5",
+        "@emnapi/wasi-threads": "^1.0.4",
+        "@napi-rs/wasm-runtime": "^0.2.12",
+        "@tybys/wasm-util": "^0.10.0",
+        "tslib": "^2.8.0"
+      },
+      "engines": {
+        "node": ">=14.0.0"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-win32-arm64-msvc": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-win32-arm64-msvc/-/oxide-win32-arm64-msvc-4.1.13.tgz",
+      "integrity": "sha512-dziTNeQXtoQ2KBXmrjCxsuPk3F3CQ/yb7ZNZNA+UkNTeiTGgfeh+gH5Pi7mRncVgcPD2xgHvkFCh/MhZWSgyQg==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/oxide-win32-x64-msvc": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/oxide-win32-x64-msvc/-/oxide-win32-x64-msvc-4.1.13.tgz",
+      "integrity": "sha512-3+LKesjXydTkHk5zXX01b5KMzLV1xl2mcktBJkje7rhFUpUlYJy7IMOLqjIRQncLTa1WZZiFY/foAeB5nmaiTw==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">= 10"
+      }
+    },
+    "node_modules/@tailwindcss/postcss": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/@tailwindcss/postcss/-/postcss-4.1.13.tgz",
+      "integrity": "sha512-HLgx6YSFKJT7rJqh9oJs/TkBFhxuMOfUKSBEPYwV+t78POOBsdQ7crhZLzwcH3T0UyUuOzU/GK5pk5eKr3wCiQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@alloc/quick-lru": "^5.2.0",
+        "@tailwindcss/node": "4.1.13",
+        "@tailwindcss/oxide": "4.1.13",
+        "postcss": "^8.4.41",
+        "tailwindcss": "4.1.13"
+      }
+    },
+    "node_modules/@tybys/wasm-util": {
+      "version": "0.10.1",
+      "resolved": "https://registry.npmjs.org/@tybys/wasm-util/-/wasm-util-0.10.1.tgz",
+      "integrity": "sha512-9tTaPJLSiejZKx+Bmog4uSubteqTvFrVrURwkmHixBo0G4seD0zUxp98E1DzUBJxLQ3NPwXrGKDiVjwx/DpPsg==",
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "dependencies": {
+        "tslib": "^2.4.0"
+      }
+    },
+    "node_modules/@types/estree": {
+      "version": "1.0.8",
+      "resolved": "https://registry.npmjs.org/@types/estree/-/estree-1.0.8.tgz",
+      "integrity": "sha512-dWHzHa2WqEXI/O1E9OjrocMTKJl2mSrEolh1Iomrv6U+JuNwaHXsXx9bLu5gG7BUWFIN0skIQJQ/L1rIex4X6w==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/@types/json-schema": {
+      "version": "7.0.15",
+      "resolved": "https://registry.npmjs.org/@types/json-schema/-/json-schema-7.0.15.tgz",
+      "integrity": "sha512-5+fP8P8MFNC+AyZCDxrB2pkZFPGzqQWUzpSeuuVLvm8VMcorNYavBqoFcxK8bQz4Qsbn4oUEEem4wDLfcysGHA==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/@types/json5": {
+      "version": "0.0.29",
+      "resolved": "https://registry.npmjs.org/@types/json5/-/json5-0.0.29.tgz",
+      "integrity": "sha512-dRLjCWHYg4oaA77cxO64oO+7JwCwnIzkZPdrrC71jQmQtlhM556pwKo5bUzqvZndkVbeFLIIi+9TC40JNF5hNQ==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/@types/node": {
+      "version": "20.19.18",
+      "resolved": "https://registry.npmjs.org/@types/node/-/node-20.19.18.tgz",
+      "integrity": "sha512-KeYVbfnbsBCyKG8e3gmUqAfyZNcoj/qpEbHRkQkfZdKOBrU7QQ+BsTdfqLSWX9/m1ytYreMhpKvp+EZi3UFYAg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "undici-types": "~6.21.0"
+      }
+    },
+    "node_modules/@types/react": {
+      "version": "19.1.16",
+      "resolved": "https://registry.npmjs.org/@types/react/-/react-19.1.16.tgz",
+      "integrity": "sha512-WBM/nDbEZmDUORKnh5i1bTnAz6vTohUf9b8esSMu+b24+srbaxa04UbJgWx78CVfNXA20sNu0odEIluZDFdCog==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "csstype": "^3.0.2"
+      }
+    },
+    "node_modules/@types/react-dom": {
+      "version": "19.1.9",
+      "resolved": "https://registry.npmjs.org/@types/react-dom/-/react-dom-19.1.9.tgz",
+      "integrity": "sha512-qXRuZaOsAdXKFyOhRBg6Lqqc0yay13vN7KrIg4L7N4aaHN68ma9OK3NE1BoDFgFOTfM7zg+3/8+2n8rLUH3OKQ==",
+      "dev": true,
+      "license": "MIT",
+      "peerDependencies": {
+        "@types/react": "^19.0.0"
+      }
+    },
+    "node_modules/@typescript-eslint/eslint-plugin": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/eslint-plugin/-/eslint-plugin-8.45.0.tgz",
+      "integrity": "sha512-HC3y9CVuevvWCl/oyZuI47dOeDF9ztdMEfMH8/DW/Mhwa9cCLnK1oD7JoTVGW/u7kFzNZUKUoyJEqkaJh5y3Wg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@eslint-community/regexpp": "^4.10.0",
+        "@typescript-eslint/scope-manager": "8.45.0",
+        "@typescript-eslint/type-utils": "8.45.0",
+        "@typescript-eslint/utils": "8.45.0",
+        "@typescript-eslint/visitor-keys": "8.45.0",
+        "graphemer": "^1.4.0",
+        "ignore": "^7.0.0",
+        "natural-compare": "^1.4.0",
+        "ts-api-utils": "^2.1.0"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      },
+      "peerDependencies": {
+        "@typescript-eslint/parser": "^8.45.0",
+        "eslint": "^8.57.0 || ^9.0.0",
+        "typescript": ">=4.8.4 <6.0.0"
+      }
+    },
+    "node_modules/@typescript-eslint/eslint-plugin/node_modules/ignore": {
+      "version": "7.0.5",
+      "resolved": "https://registry.npmjs.org/ignore/-/ignore-7.0.5.tgz",
+      "integrity": "sha512-Hs59xBNfUIunMFgWAbGX5cq6893IbWg4KnrjbYwX3tx0ztorVgTDA6B2sxf8ejHJ4wz8BqGUMYlnzNBer5NvGg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 4"
+      }
+    },
+    "node_modules/@typescript-eslint/parser": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/parser/-/parser-8.45.0.tgz",
+      "integrity": "sha512-TGf22kon8KW+DeKaUmOibKWktRY8b2NSAZNdtWh798COm1NWx8+xJ6iFBtk3IvLdv6+LGLJLRlyhrhEDZWargQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@typescript-eslint/scope-manager": "8.45.0",
+        "@typescript-eslint/types": "8.45.0",
+        "@typescript-eslint/typescript-estree": "8.45.0",
+        "@typescript-eslint/visitor-keys": "8.45.0",
+        "debug": "^4.3.4"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      },
+      "peerDependencies": {
+        "eslint": "^8.57.0 || ^9.0.0",
+        "typescript": ">=4.8.4 <6.0.0"
+      }
+    },
+    "node_modules/@typescript-eslint/project-service": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/project-service/-/project-service-8.45.0.tgz",
+      "integrity": "sha512-3pcVHwMG/iA8afdGLMuTibGR7pDsn9RjDev6CCB+naRsSYs2pns5QbinF4Xqw6YC/Sj3lMrm/Im0eMfaa61WUg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@typescript-eslint/tsconfig-utils": "^8.45.0",
+        "@typescript-eslint/types": "^8.45.0",
+        "debug": "^4.3.4"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      },
+      "peerDependencies": {
+        "typescript": ">=4.8.4 <6.0.0"
+      }
+    },
+    "node_modules/@typescript-eslint/scope-manager": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/scope-manager/-/scope-manager-8.45.0.tgz",
+      "integrity": "sha512-clmm8XSNj/1dGvJeO6VGH7EUSeA0FMs+5au/u3lrA3KfG8iJ4u8ym9/j2tTEoacAffdW1TVUzXO30W1JTJS7dA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@typescript-eslint/types": "8.45.0",
+        "@typescript-eslint/visitor-keys": "8.45.0"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      }
+    },
+    "node_modules/@typescript-eslint/tsconfig-utils": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/tsconfig-utils/-/tsconfig-utils-8.45.0.tgz",
+      "integrity": "sha512-aFdr+c37sc+jqNMGhH+ajxPXwjv9UtFZk79k8pLoJ6p4y0snmYpPA52GuWHgt2ZF4gRRW6odsEj41uZLojDt5w==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      },
+      "peerDependencies": {
+        "typescript": ">=4.8.4 <6.0.0"
+      }
+    },
+    "node_modules/@typescript-eslint/type-utils": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/type-utils/-/type-utils-8.45.0.tgz",
+      "integrity": "sha512-bpjepLlHceKgyMEPglAeULX1vixJDgaKocp0RVJ5u4wLJIMNuKtUXIczpJCPcn2waII0yuvks/5m5/h3ZQKs0A==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@typescript-eslint/types": "8.45.0",
+        "@typescript-eslint/typescript-estree": "8.45.0",
+        "@typescript-eslint/utils": "8.45.0",
+        "debug": "^4.3.4",
+        "ts-api-utils": "^2.1.0"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      },
+      "peerDependencies": {
+        "eslint": "^8.57.0 || ^9.0.0",
+        "typescript": ">=4.8.4 <6.0.0"
+      }
+    },
+    "node_modules/@typescript-eslint/types": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/types/-/types-8.45.0.tgz",
+      "integrity": "sha512-WugXLuOIq67BMgQInIxxnsSyRLFxdkJEJu8r4ngLR56q/4Q5LrbfkFRH27vMTjxEK8Pyz7QfzuZe/G15qQnVRA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      }
+    },
+    "node_modules/@typescript-eslint/typescript-estree": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/typescript-estree/-/typescript-estree-8.45.0.tgz",
+      "integrity": "sha512-GfE1NfVbLam6XQ0LcERKwdTTPlLvHvXXhOeUGC1OXi4eQBoyy1iVsW+uzJ/J9jtCz6/7GCQ9MtrQ0fml/jWCnA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@typescript-eslint/project-service": "8.45.0",
+        "@typescript-eslint/tsconfig-utils": "8.45.0",
+        "@typescript-eslint/types": "8.45.0",
+        "@typescript-eslint/visitor-keys": "8.45.0",
+        "debug": "^4.3.4",
+        "fast-glob": "^3.3.2",
+        "is-glob": "^4.0.3",
+        "minimatch": "^9.0.4",
+        "semver": "^7.6.0",
+        "ts-api-utils": "^2.1.0"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      },
+      "peerDependencies": {
+        "typescript": ">=4.8.4 <6.0.0"
+      }
+    },
+    "node_modules/@typescript-eslint/typescript-estree/node_modules/brace-expansion": {
+      "version": "2.0.2",
+      "resolved": "https://registry.npmjs.org/brace-expansion/-/brace-expansion-2.0.2.tgz",
+      "integrity": "sha512-Jt0vHyM+jmUBqojB7E1NIYadt0vI0Qxjxd2TErW94wDz+E2LAm5vKMXXwg6ZZBTHPuUlDgQHKXvjGBdfcF1ZDQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "balanced-match": "^1.0.0"
+      }
+    },
+    "node_modules/@typescript-eslint/typescript-estree/node_modules/fast-glob": {
+      "version": "3.3.3",
+      "resolved": "https://registry.npmjs.org/fast-glob/-/fast-glob-3.3.3.tgz",
+      "integrity": "sha512-7MptL8U0cqcFdzIzwOTHoilX9x5BrNqye7Z/LuC7kCMRio1EMSyqRK3BEAUD7sXRq4iT4AzTVuZdhgQ2TCvYLg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@nodelib/fs.stat": "^2.0.2",
+        "@nodelib/fs.walk": "^1.2.3",
+        "glob-parent": "^5.1.2",
+        "merge2": "^1.3.0",
+        "micromatch": "^4.0.8"
+      },
+      "engines": {
+        "node": ">=8.6.0"
+      }
+    },
+    "node_modules/@typescript-eslint/typescript-estree/node_modules/glob-parent": {
+      "version": "5.1.2",
+      "resolved": "https://registry.npmjs.org/glob-parent/-/glob-parent-5.1.2.tgz",
+      "integrity": "sha512-AOIgSQCepiJYwP3ARnGx+5VnTu2HBYdzbGP45eLw1vr3zB3vZLeyed1sC9hnbcOc9/SrMyM5RPQrkGz4aS9Zow==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "is-glob": "^4.0.1"
+      },
+      "engines": {
+        "node": ">= 6"
+      }
+    },
+    "node_modules/@typescript-eslint/typescript-estree/node_modules/minimatch": {
+      "version": "9.0.5",
+      "resolved": "https://registry.npmjs.org/minimatch/-/minimatch-9.0.5.tgz",
+      "integrity": "sha512-G6T0ZX48xgozx7587koeX9Ys2NYy6Gmv//P89sEte9V9whIapMNF4idKxnW2QtCcLiTWlb/wfCabAtAFWhhBow==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "brace-expansion": "^2.0.1"
+      },
+      "engines": {
+        "node": ">=16 || 14 >=14.17"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/isaacs"
+      }
+    },
+    "node_modules/@typescript-eslint/utils": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/utils/-/utils-8.45.0.tgz",
+      "integrity": "sha512-bxi1ht+tLYg4+XV2knz/F7RVhU0k6VrSMc9sb8DQ6fyCTrGQLHfo7lDtN0QJjZjKkLA2ThrKuCdHEvLReqtIGg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@eslint-community/eslint-utils": "^4.7.0",
+        "@typescript-eslint/scope-manager": "8.45.0",
+        "@typescript-eslint/types": "8.45.0",
+        "@typescript-eslint/typescript-estree": "8.45.0"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      },
+      "peerDependencies": {
+        "eslint": "^8.57.0 || ^9.0.0",
+        "typescript": ">=4.8.4 <6.0.0"
+      }
+    },
+    "node_modules/@typescript-eslint/visitor-keys": {
+      "version": "8.45.0",
+      "resolved": "https://registry.npmjs.org/@typescript-eslint/visitor-keys/-/visitor-keys-8.45.0.tgz",
+      "integrity": "sha512-qsaFBA3e09MIDAGFUrTk+dzqtfv1XPVz8t8d1f0ybTzrCY7BKiMC5cjrl1O/P7UmHsNyW90EYSkU/ZWpmXelag==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@typescript-eslint/types": "8.45.0",
+        "eslint-visitor-keys": "^4.2.1"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/typescript-eslint"
+      }
+    },
+    "node_modules/@unrs/resolver-binding-android-arm-eabi": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-android-arm-eabi/-/resolver-binding-android-arm-eabi-1.11.1.tgz",
+      "integrity": "sha512-ppLRUgHVaGRWUx0R0Ut06Mjo9gBaBkg3v/8AxusGLhsIotbBLuRk51rAzqLC8gq6NyyAojEXglNjzf6R948DNw==",
+      "cpu": [
+        "arm"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "android"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-android-arm64": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-android-arm64/-/resolver-binding-android-arm64-1.11.1.tgz",
+      "integrity": "sha512-lCxkVtb4wp1v+EoN+HjIG9cIIzPkX5OtM03pQYkG+U5O/wL53LC4QbIeazgiKqluGeVEeBlZahHalCaBvU1a2g==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "android"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-darwin-arm64": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-darwin-arm64/-/resolver-binding-darwin-arm64-1.11.1.tgz",
+      "integrity": "sha512-gPVA1UjRu1Y/IsB/dQEsp2V1pm44Of6+LWvbLc9SDk1c2KhhDRDBUkQCYVWe6f26uJb3fOK8saWMgtX8IrMk3g==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "darwin"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-darwin-x64": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-darwin-x64/-/resolver-binding-darwin-x64-1.11.1.tgz",
+      "integrity": "sha512-cFzP7rWKd3lZaCsDze07QX1SC24lO8mPty9vdP+YVa3MGdVgPmFc59317b2ioXtgCMKGiCLxJ4HQs62oz6GfRQ==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "darwin"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-freebsd-x64": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-freebsd-x64/-/resolver-binding-freebsd-x64-1.11.1.tgz",
+      "integrity": "sha512-fqtGgak3zX4DCB6PFpsH5+Kmt/8CIi4Bry4rb1ho6Av2QHTREM+47y282Uqiu3ZRF5IQioJQ5qWRV6jduA+iGw==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "freebsd"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-arm-gnueabihf": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-arm-gnueabihf/-/resolver-binding-linux-arm-gnueabihf-1.11.1.tgz",
+      "integrity": "sha512-u92mvlcYtp9MRKmP+ZvMmtPN34+/3lMHlyMj7wXJDeXxuM0Vgzz0+PPJNsro1m3IZPYChIkn944wW8TYgGKFHw==",
+      "cpu": [
+        "arm"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-arm-musleabihf": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-arm-musleabihf/-/resolver-binding-linux-arm-musleabihf-1.11.1.tgz",
+      "integrity": "sha512-cINaoY2z7LVCrfHkIcmvj7osTOtm6VVT16b5oQdS4beibX2SYBwgYLmqhBjA1t51CarSaBuX5YNsWLjsqfW5Cw==",
+      "cpu": [
+        "arm"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-arm64-gnu": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-arm64-gnu/-/resolver-binding-linux-arm64-gnu-1.11.1.tgz",
+      "integrity": "sha512-34gw7PjDGB9JgePJEmhEqBhWvCiiWCuXsL9hYphDF7crW7UgI05gyBAi6MF58uGcMOiOqSJ2ybEeCvHcq0BCmQ==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-arm64-musl": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-arm64-musl/-/resolver-binding-linux-arm64-musl-1.11.1.tgz",
+      "integrity": "sha512-RyMIx6Uf53hhOtJDIamSbTskA99sPHS96wxVE/bJtePJJtpdKGXO1wY90oRdXuYOGOTuqjT8ACccMc4K6QmT3w==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-ppc64-gnu": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-ppc64-gnu/-/resolver-binding-linux-ppc64-gnu-1.11.1.tgz",
+      "integrity": "sha512-D8Vae74A4/a+mZH0FbOkFJL9DSK2R6TFPC9M+jCWYia/q2einCubX10pecpDiTmkJVUH+y8K3BZClycD8nCShA==",
+      "cpu": [
+        "ppc64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-riscv64-gnu": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-riscv64-gnu/-/resolver-binding-linux-riscv64-gnu-1.11.1.tgz",
+      "integrity": "sha512-frxL4OrzOWVVsOc96+V3aqTIQl1O2TjgExV4EKgRY09AJ9leZpEg8Ak9phadbuX0BA4k8U5qtvMSQQGGmaJqcQ==",
+      "cpu": [
+        "riscv64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-riscv64-musl": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-riscv64-musl/-/resolver-binding-linux-riscv64-musl-1.11.1.tgz",
+      "integrity": "sha512-mJ5vuDaIZ+l/acv01sHoXfpnyrNKOk/3aDoEdLO/Xtn9HuZlDD6jKxHlkN8ZhWyLJsRBxfv9GYM2utQ1SChKew==",
+      "cpu": [
+        "riscv64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-s390x-gnu": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-s390x-gnu/-/resolver-binding-linux-s390x-gnu-1.11.1.tgz",
+      "integrity": "sha512-kELo8ebBVtb9sA7rMe1Cph4QHreByhaZ2QEADd9NzIQsYNQpt9UkM9iqr2lhGr5afh885d/cB5QeTXSbZHTYPg==",
+      "cpu": [
+        "s390x"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-x64-gnu": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-x64-gnu/-/resolver-binding-linux-x64-gnu-1.11.1.tgz",
+      "integrity": "sha512-C3ZAHugKgovV5YvAMsxhq0gtXuwESUKc5MhEtjBpLoHPLYM+iuwSj3lflFwK3DPm68660rZ7G8BMcwSro7hD5w==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-linux-x64-musl": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-linux-x64-musl/-/resolver-binding-linux-x64-musl-1.11.1.tgz",
+      "integrity": "sha512-rV0YSoyhK2nZ4vEswT/QwqzqQXw5I6CjoaYMOX0TqBlWhojUf8P94mvI7nuJTeaCkkds3QE4+zS8Ko+GdXuZtA==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "linux"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-wasm32-wasi": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-wasm32-wasi/-/resolver-binding-wasm32-wasi-1.11.1.tgz",
+      "integrity": "sha512-5u4RkfxJm+Ng7IWgkzi3qrFOvLvQYnPBmjmZQ8+szTK/b31fQCnleNl1GgEt7nIsZRIf5PLhPwT0WM+q45x/UQ==",
+      "cpu": [
+        "wasm32"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "dependencies": {
+        "@napi-rs/wasm-runtime": "^0.2.11"
+      },
+      "engines": {
+        "node": ">=14.0.0"
+      }
+    },
+    "node_modules/@unrs/resolver-binding-win32-arm64-msvc": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-win32-arm64-msvc/-/resolver-binding-win32-arm64-msvc-1.11.1.tgz",
+      "integrity": "sha512-nRcz5Il4ln0kMhfL8S3hLkxI85BXs3o8EYoattsJNdsX4YUU89iOkVn7g0VHSRxFuVMdM4Q1jEpIId1Ihim/Uw==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "win32"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-win32-ia32-msvc": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-win32-ia32-msvc/-/resolver-binding-win32-ia32-msvc-1.11.1.tgz",
+      "integrity": "sha512-DCEI6t5i1NmAZp6pFonpD5m7i6aFrpofcp4LA2i8IIq60Jyo28hamKBxNrZcyOwVOZkgsRp9O2sXWBWP8MnvIQ==",
+      "cpu": [
+        "ia32"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "win32"
+      ]
+    },
+    "node_modules/@unrs/resolver-binding-win32-x64-msvc": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/@unrs/resolver-binding-win32-x64-msvc/-/resolver-binding-win32-x64-msvc-1.11.1.tgz",
+      "integrity": "sha512-lrW200hZdbfRtztbygyaq/6jP6AKE8qQN2KvPcJ+x7wiD038YtnYtZ82IMNJ69GJibV7bwL3y9FgK+5w/pYt6g==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MIT",
+      "optional": true,
+      "os": [
+        "win32"
+      ]
+    },
+    "node_modules/acorn": {
+      "version": "8.15.0",
+      "resolved": "https://registry.npmjs.org/acorn/-/acorn-8.15.0.tgz",
+      "integrity": "sha512-NZyJarBfL7nWwIq+FDL6Zp/yHEhePMNnnJ0y3qfieCrmNvYct8uvtiV41UvlSe6apAfk0fY1FbWx+NwfmpvtTg==",
+      "dev": true,
+      "license": "MIT",
+      "bin": {
+        "acorn": "bin/acorn"
+      },
+      "engines": {
+        "node": ">=0.4.0"
+      }
+    },
+    "node_modules/acorn-jsx": {
+      "version": "5.3.2",
+      "resolved": "https://registry.npmjs.org/acorn-jsx/-/acorn-jsx-5.3.2.tgz",
+      "integrity": "sha512-rq9s+JNhf0IChjtDXxllJ7g41oZk5SlXtp0LHwyA5cejwn7vKmKp4pPri6YEePv2PU65sAsegbXtIinmDFDXgQ==",
+      "dev": true,
+      "license": "MIT",
+      "peerDependencies": {
+        "acorn": "^6.0.0 || ^7.0.0 || ^8.0.0"
+      }
+    },
+    "node_modules/ajv": {
+      "version": "6.12.6",
+      "resolved": "https://registry.npmjs.org/ajv/-/ajv-6.12.6.tgz",
+      "integrity": "sha512-j3fVLgvTo527anyYyJOGTYJbG+vnnQYvE0m5mmkc1TK+nxAppkCLMIL0aZ4dblVCNoGShhm+kzE4ZUykBoMg4g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "fast-deep-equal": "^3.1.1",
+        "fast-json-stable-stringify": "^2.0.0",
+        "json-schema-traverse": "^0.4.1",
+        "uri-js": "^4.2.2"
+      },
+      "funding": {
+        "type": "github",
+        "url": "https://github.com/sponsors/epoberezkin"
+      }
+    },
+    "node_modules/ansi-styles": {
+      "version": "4.3.0",
+      "resolved": "https://registry.npmjs.org/ansi-styles/-/ansi-styles-4.3.0.tgz",
+      "integrity": "sha512-zbB9rCJAT1rbjiVDb2hqKFHNYLxgtk8NURxZ3IZwD3F6NtxbXZQCnnSi1Lkx+IDohdPlFp222wVALIheZJQSEg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "color-convert": "^2.0.1"
+      },
+      "engines": {
+        "node": ">=8"
+      },
+      "funding": {
+        "url": "https://github.com/chalk/ansi-styles?sponsor=1"
+      }
+    },
+    "node_modules/argparse": {
+      "version": "2.0.1",
+      "resolved": "https://registry.npmjs.org/argparse/-/argparse-2.0.1.tgz",
+      "integrity": "sha512-8+9WqebbFzpX9OR+Wa6O29asIogeRMzcGtAINdpMHHyAg10f05aSFVBbcEqGf/PXw1EjAZ+q2/bEBg3DvurK3Q==",
+      "dev": true,
+      "license": "Python-2.0"
+    },
+    "node_modules/aria-query": {
+      "version": "5.3.2",
+      "resolved": "https://registry.npmjs.org/aria-query/-/aria-query-5.3.2.tgz",
+      "integrity": "sha512-COROpnaoap1E2F000S62r6A60uHZnmlvomhfyT2DlTcrY1OrBKn2UhH7qn5wTC9zMvD0AY7csdPSNwKP+7WiQw==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/array-buffer-byte-length": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/array-buffer-byte-length/-/array-buffer-byte-length-1.0.2.tgz",
+      "integrity": "sha512-LHE+8BuR7RYGDKvnrmcuSq3tDcKv9OFEXQt/HpbZhY7V6h0zlUXutnAD82GiFx9rdieCMjkvtcsPqBwgUl1Iiw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "is-array-buffer": "^3.0.5"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/array-includes": {
+      "version": "3.1.9",
+      "resolved": "https://registry.npmjs.org/array-includes/-/array-includes-3.1.9.tgz",
+      "integrity": "sha512-FmeCCAenzH0KH381SPT5FZmiA/TmpndpcaShhfgEN9eCVjnFBqq3l1xrI42y8+PPLI6hypzou4GXw00WHmPBLQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.4",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.24.0",
+        "es-object-atoms": "^1.1.1",
+        "get-intrinsic": "^1.3.0",
+        "is-string": "^1.1.1",
+        "math-intrinsics": "^1.1.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/array.prototype.findlast": {
+      "version": "1.2.5",
+      "resolved": "https://registry.npmjs.org/array.prototype.findlast/-/array.prototype.findlast-1.2.5.tgz",
+      "integrity": "sha512-CVvd6FHg1Z3POpBLxO6E6zr+rSKEQ9L6rZHAaY7lLfhKsWYUBBOuMs0e9o24oopj6H+geRCX0YJ+TJLBK2eHyQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.7",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.2",
+        "es-errors": "^1.3.0",
+        "es-object-atoms": "^1.0.0",
+        "es-shim-unscopables": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/array.prototype.findlastindex": {
+      "version": "1.2.6",
+      "resolved": "https://registry.npmjs.org/array.prototype.findlastindex/-/array.prototype.findlastindex-1.2.6.tgz",
+      "integrity": "sha512-F/TKATkzseUExPlfvmwQKGITM3DGTK+vkAsCZoDc5daVygbJBnjEUCbgkAvVFsgfXfX4YIqZ/27G3k3tdXrTxQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.4",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.9",
+        "es-errors": "^1.3.0",
+        "es-object-atoms": "^1.1.1",
+        "es-shim-unscopables": "^1.1.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/array.prototype.flat": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/array.prototype.flat/-/array.prototype.flat-1.3.3.tgz",
+      "integrity": "sha512-rwG/ja1neyLqCuGZ5YYrznA62D4mZXg0i1cIskIUKSiqF3Cje9/wXAls9B9s1Wa2fomMsIv8czB8jZcPmxCXFg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.5",
+        "es-shim-unscopables": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/array.prototype.flatmap": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/array.prototype.flatmap/-/array.prototype.flatmap-1.3.3.tgz",
+      "integrity": "sha512-Y7Wt51eKJSyi80hFrJCePGGNo5ktJCslFuboqJsbf57CCPcm5zztluPlc4/aD8sWsKvlwatezpV4U1efk8kpjg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.5",
+        "es-shim-unscopables": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/array.prototype.tosorted": {
+      "version": "1.1.4",
+      "resolved": "https://registry.npmjs.org/array.prototype.tosorted/-/array.prototype.tosorted-1.1.4.tgz",
+      "integrity": "sha512-p6Fx8B7b7ZhL/gmUsAy0D15WhvDccw3mnGNbZpi3pmeJdxtWsj2jEaI4Y6oo3XiHfzuSgPwKc04MYt6KgvC/wA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.7",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.3",
+        "es-errors": "^1.3.0",
+        "es-shim-unscopables": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/arraybuffer.prototype.slice": {
+      "version": "1.0.4",
+      "resolved": "https://registry.npmjs.org/arraybuffer.prototype.slice/-/arraybuffer.prototype.slice-1.0.4.tgz",
+      "integrity": "sha512-BNoCY6SXXPQ7gF2opIP4GBE+Xw7U+pHMYKuzjgCN3GwiaIR09UUeKfheyIry77QtrCBlC0KK0q5/TER/tYh3PQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "array-buffer-byte-length": "^1.0.1",
+        "call-bind": "^1.0.8",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.5",
+        "es-errors": "^1.3.0",
+        "get-intrinsic": "^1.2.6",
+        "is-array-buffer": "^3.0.4"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/ast-types-flow": {
+      "version": "0.0.8",
+      "resolved": "https://registry.npmjs.org/ast-types-flow/-/ast-types-flow-0.0.8.tgz",
+      "integrity": "sha512-OH/2E5Fg20h2aPrbe+QL8JZQFko0YZaF+j4mnQ7BGhfavO7OpSLa8a0y9sBwomHdSbkhTS8TQNayBfnW5DwbvQ==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/async-function": {
+      "version": "1.0.0",
+      "resolved": "https://registry.npmjs.org/async-function/-/async-function-1.0.0.tgz",
+      "integrity": "sha512-hsU18Ae8CDTR6Kgu9DYf0EbCr/a5iGL0rytQDobUcdpYOKokk8LEjVphnXkDkgpi0wYVsqrXuP0bZxJaTqdgoA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/available-typed-arrays": {
+      "version": "1.0.7",
+      "resolved": "https://registry.npmjs.org/available-typed-arrays/-/available-typed-arrays-1.0.7.tgz",
+      "integrity": "sha512-wvUjBtSGN7+7SjNpq/9M2Tg350UZD3q62IFZLbRAR1bSMlCo1ZaeW+BJ+D090e4hIIZLBcTDWe4Mh4jvUDajzQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "possible-typed-array-names": "^1.0.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/axe-core": {
+      "version": "4.10.3",
+      "resolved": "https://registry.npmjs.org/axe-core/-/axe-core-4.10.3.tgz",
+      "integrity": "sha512-Xm7bpRXnDSX2YE2YFfBk2FnF0ep6tmG7xPh8iHee8MIcrgq762Nkce856dYtJYLkuIoYZvGfTs/PbZhideTcEg==",
+      "dev": true,
+      "license": "MPL-2.0",
+      "engines": {
+        "node": ">=4"
+      }
+    },
+    "node_modules/axobject-query": {
+      "version": "4.1.0",
+      "resolved": "https://registry.npmjs.org/axobject-query/-/axobject-query-4.1.0.tgz",
+      "integrity": "sha512-qIj0G9wZbMGNLjLmg1PT6v2mE9AH2zlnADJD/2tC6E00hgmhUOfEB6greHPAfLRSufHqROIUTkw6E+M3lH0PTQ==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/balanced-match": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/balanced-match/-/balanced-match-1.0.2.tgz",
+      "integrity": "sha512-3oSeUO0TMV67hN1AmbXsK4yaqU7tjiHlbxRDZOpH0KW9+CeX4bRAaX0Anxt0tx2MrpRpWwQaPwIlISEJhYU5Pw==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/brace-expansion": {
+      "version": "1.1.12",
+      "resolved": "https://registry.npmjs.org/brace-expansion/-/brace-expansion-1.1.12.tgz",
+      "integrity": "sha512-9T9UjW3r0UW5c1Q7GTwllptXwhvYmEzFhzMfZ9H7FQWt+uZePjZPjBP/W1ZEyZ1twGWom5/56TF4lPcqjnDHcg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "balanced-match": "^1.0.0",
+        "concat-map": "0.0.1"
+      }
+    },
+    "node_modules/braces": {
+      "version": "3.0.3",
+      "resolved": "https://registry.npmjs.org/braces/-/braces-3.0.3.tgz",
+      "integrity": "sha512-yQbXgO/OSZVD2IsiLlro+7Hf6Q18EJrKSEsdoMzKePKXct3gvD8oLcOQdIzGupr5Fj+EDe8gO/lxc1BzfMpxvA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "fill-range": "^7.1.1"
+      },
+      "engines": {
+        "node": ">=8"
+      }
+    },
+    "node_modules/call-bind": {
+      "version": "1.0.8",
+      "resolved": "https://registry.npmjs.org/call-bind/-/call-bind-1.0.8.tgz",
+      "integrity": "sha512-oKlSFMcMwpUg2ednkhQ454wfWiU/ul3CkJe/PEHcTKuiX6RpbehUiFMXu13HalGZxfUwCQzZG747YXBn1im9ww==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind-apply-helpers": "^1.0.0",
+        "es-define-property": "^1.0.0",
+        "get-intrinsic": "^1.2.4",
+        "set-function-length": "^1.2.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/call-bind-apply-helpers": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/call-bind-apply-helpers/-/call-bind-apply-helpers-1.0.2.tgz",
+      "integrity": "sha512-Sp1ablJ0ivDkSzjcaJdxEunN5/XvksFJ2sMBFfq6x0ryhQV/2b/KwFe21cMpmHtPOSij8K99/wSfoEuTObmuMQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-errors": "^1.3.0",
+        "function-bind": "^1.1.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/call-bound": {
+      "version": "1.0.4",
+      "resolved": "https://registry.npmjs.org/call-bound/-/call-bound-1.0.4.tgz",
+      "integrity": "sha512-+ys997U96po4Kx/ABpBCqhA9EuxJaQWDQg7295H4hBphv3IZg0boBKuwYpt4YXp6MZ5AmZQnU/tyMTlRpaSejg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind-apply-helpers": "^1.0.2",
+        "get-intrinsic": "^1.3.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/callsites": {
+      "version": "3.1.0",
+      "resolved": "https://registry.npmjs.org/callsites/-/callsites-3.1.0.tgz",
+      "integrity": "sha512-P8BjAsXvZS+VIDUI11hHCQEv74YT67YUi5JJFNWIqL235sBmjX4+qx9Muvls5ivyNENctx46xQLQ3aTuE7ssaQ==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=6"
+      }
+    },
+    "node_modules/caniuse-lite": {
+      "version": "1.0.30001746",
+      "resolved": "https://registry.npmjs.org/caniuse-lite/-/caniuse-lite-1.0.30001746.tgz",
+      "integrity": "sha512-eA7Ys/DGw+pnkWWSE/id29f2IcPHVoE8wxtvE5JdvD2V28VTDPy1yEeo11Guz0sJ4ZeGRcm3uaTcAqK1LXaphA==",
+      "funding": [
+        {
+          "type": "opencollective",
+          "url": "https://opencollective.com/browserslist"
+        },
+        {
+          "type": "tidelift",
+          "url": "https://tidelift.com/funding/github/npm/caniuse-lite"
+        },
+        {
+          "type": "github",
+          "url": "https://github.com/sponsors/ai"
+        }
+      ],
+      "license": "CC-BY-4.0"
+    },
+    "node_modules/chalk": {
+      "version": "4.1.2",
+      "resolved": "https://registry.npmjs.org/chalk/-/chalk-4.1.2.tgz",
+      "integrity": "sha512-oKnbhFyRIXpUuez8iBMmyEa4nbj4IOQyuhc/wy9kY7/WVPcwIO9VA668Pu8RkO7+0G76SLROeyw9CpQ061i4mA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "ansi-styles": "^4.1.0",
+        "supports-color": "^7.1.0"
+      },
+      "engines": {
+        "node": ">=10"
+      },
+      "funding": {
+        "url": "https://github.com/chalk/chalk?sponsor=1"
+      }
+    },
+    "node_modules/chownr": {
+      "version": "3.0.0",
+      "resolved": "https://registry.npmjs.org/chownr/-/chownr-3.0.0.tgz",
+      "integrity": "sha512-+IxzY9BZOQd/XuYPRmrvEVjF/nqj5kgT4kEq7VofrDoM1MxoRjEWkrCC3EtLi59TVawxTAn+orJwFQcrqEN1+g==",
+      "dev": true,
+      "license": "BlueOak-1.0.0",
+      "engines": {
+        "node": ">=18"
+      }
+    },
+    "node_modules/client-only": {
+      "version": "0.0.1",
+      "resolved": "https://registry.npmjs.org/client-only/-/client-only-0.0.1.tgz",
+      "integrity": "sha512-IV3Ou0jSMzZrd3pZ48nLkT9DA7Ag1pnPzaiQhpW7c3RbcqqzvzzVu+L8gfqMp/8IM2MQtSiqaCxrrcfu8I8rMA==",
+      "license": "MIT"
+    },
+    "node_modules/color-convert": {
+      "version": "2.0.1",
+      "resolved": "https://registry.npmjs.org/color-convert/-/color-convert-2.0.1.tgz",
+      "integrity": "sha512-RRECPsj7iu/xb5oKYcsFHSppFNnsj/52OVTRKb4zP5onXwVF3zVmmToNcOfGC+CRDpfK/U584fMg38ZHCaElKQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "color-name": "~1.1.4"
+      },
+      "engines": {
+        "node": ">=7.0.0"
+      }
+    },
+    "node_modules/color-name": {
+      "version": "1.1.4",
+      "resolved": "https://registry.npmjs.org/color-name/-/color-name-1.1.4.tgz",
+      "integrity": "sha512-dOy+3AuW3a2wNbZHIuMZpTcgjGuLU/uBL/ubcZF9OXbDo8ff4O8yVp5Bf0efS8uEoYo5q4Fx7dY9OgQGXgAsQA==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/concat-map": {
+      "version": "0.0.1",
+      "resolved": "https://registry.npmjs.org/concat-map/-/concat-map-0.0.1.tgz",
+      "integrity": "sha512-/Srv4dswyQNBfohGpz9o6Yb3Gz3SrUDqBH5rTuhGR7ahtlbYKnVxw2bCFMRljaA7EXHaXZ8wsHdodFvbkhKmqg==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/cross-spawn": {
+      "version": "7.0.6",
+      "resolved": "https://registry.npmjs.org/cross-spawn/-/cross-spawn-7.0.6.tgz",
+      "integrity": "sha512-uV2QOWP2nWzsy2aMp8aRibhi9dlzF5Hgh5SHaB9OiTGEyDTiJJyx0uy51QXdyWbtAHNua4XJzUKca3OzKUd3vA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "path-key": "^3.1.0",
+        "shebang-command": "^2.0.0",
+        "which": "^2.0.1"
+      },
+      "engines": {
+        "node": ">= 8"
+      }
+    },
+    "node_modules/csstype": {
+      "version": "3.1.3",
+      "resolved": "https://registry.npmjs.org/csstype/-/csstype-3.1.3.tgz",
+      "integrity": "sha512-M1uQkMl8rQK/szD0LNhtqxIPLpimGm8sOBwU7lLnCpSbTyY3yeU1Vc7l4KT5zT4s/yOxHH5O7tIuuLOCnLADRw==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/damerau-levenshtein": {
+      "version": "1.0.8",
+      "resolved": "https://registry.npmjs.org/damerau-levenshtein/-/damerau-levenshtein-1.0.8.tgz",
+      "integrity": "sha512-sdQSFB7+llfUcQHUQO3+B8ERRj0Oa4w9POWMI/puGtuf7gFywGmkaLCElnudfTiKZV+NvHqL0ifzdrI8Ro7ESA==",
+      "dev": true,
+      "license": "BSD-2-Clause"
+    },
+    "node_modules/data-view-buffer": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/data-view-buffer/-/data-view-buffer-1.0.2.tgz",
+      "integrity": "sha512-EmKO5V3OLXh1rtK2wgXRansaK1/mtVdTUEiEI0W8RkvgT05kfxaH29PliLnpLP73yYO6142Q72QNa8Wx/A5CqQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "es-errors": "^1.3.0",
+        "is-data-view": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/data-view-byte-length": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/data-view-byte-length/-/data-view-byte-length-1.0.2.tgz",
+      "integrity": "sha512-tuhGbE6CfTM9+5ANGf+oQb72Ky/0+s3xKUpHvShfiz2RxMFgFPjsXuRLBVMtvMs15awe45SRb83D6wH4ew6wlQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "es-errors": "^1.3.0",
+        "is-data-view": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/inspect-js"
+      }
+    },
+    "node_modules/data-view-byte-offset": {
+      "version": "1.0.1",
+      "resolved": "https://registry.npmjs.org/data-view-byte-offset/-/data-view-byte-offset-1.0.1.tgz",
+      "integrity": "sha512-BS8PfmtDGnrgYdOonGZQdLZslWIeCGFP9tpan0hi1Co2Zr2NKADsvGYA8XxuG/4UWgJ6Cjtv+YJnB6MM69QGlQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.2",
+        "es-errors": "^1.3.0",
+        "is-data-view": "^1.0.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/debug": {
+      "version": "4.4.3",
+      "resolved": "https://registry.npmjs.org/debug/-/debug-4.4.3.tgz",
+      "integrity": "sha512-RGwwWnwQvkVfavKVt22FGLw+xYSdzARwm0ru6DhTVA3umU5hZc28V3kO4stgYryrTlLpuvgI9GiijltAjNbcqA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "ms": "^2.1.3"
+      },
+      "engines": {
+        "node": ">=6.0"
+      },
+      "peerDependenciesMeta": {
+        "supports-color": {
+          "optional": true
+        }
+      }
+    },
+    "node_modules/deep-is": {
+      "version": "0.1.4",
+      "resolved": "https://registry.npmjs.org/deep-is/-/deep-is-0.1.4.tgz",
+      "integrity": "sha512-oIPzksmTg4/MriiaYGO+okXDT7ztn/w3Eptv/+gSIdMdKsJo0u4CfYNFJPy+4SKMuCqGw2wxnA+URMg3t8a/bQ==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/define-data-property": {
+      "version": "1.1.4",
+      "resolved": "https://registry.npmjs.org/define-data-property/-/define-data-property-1.1.4.tgz",
+      "integrity": "sha512-rBMvIzlpA8v6E+SJZoo++HAYqsLrkg7MSfIinMPFhmkorw7X+dOXVJQs+QT69zGkzMyfDnIMN2Wid1+NbL3T+A==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-define-property": "^1.0.0",
+        "es-errors": "^1.3.0",
+        "gopd": "^1.0.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/define-properties": {
+      "version": "1.2.1",
+      "resolved": "https://registry.npmjs.org/define-properties/-/define-properties-1.2.1.tgz",
+      "integrity": "sha512-8QmQKqEASLd5nx0U1B1okLElbUuuttJ/AnYmRXbbbGDWh6uS208EjD4Xqq/I9wK7u0v6O08XhTWnt5XtEbR6Dg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "define-data-property": "^1.0.1",
+        "has-property-descriptors": "^1.0.0",
+        "object-keys": "^1.1.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/detect-libc": {
+      "version": "2.1.1",
+      "resolved": "https://registry.npmjs.org/detect-libc/-/detect-libc-2.1.1.tgz",
+      "integrity": "sha512-ecqj/sy1jcK1uWrwpR67UhYrIFQ+5WlGxth34WquCbamhFA6hkkwiu37o6J5xCHdo1oixJRfVRw+ywV+Hq/0Aw==",
+      "devOptional": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": ">=8"
+      }
+    },
+    "node_modules/doctrine": {
+      "version": "2.1.0",
+      "resolved": "https://registry.npmjs.org/doctrine/-/doctrine-2.1.0.tgz",
+      "integrity": "sha512-35mSku4ZXK0vfCuHEDAwt55dg2jNajHZ1odvF+8SSr82EsZY4QmXfuWso8oEd8zRhVObSN18aM0CjSdoBX7zIw==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "dependencies": {
+        "esutils": "^2.0.2"
+      },
+      "engines": {
+        "node": ">=0.10.0"
+      }
+    },
+    "node_modules/dunder-proto": {
+      "version": "1.0.1",
+      "resolved": "https://registry.npmjs.org/dunder-proto/-/dunder-proto-1.0.1.tgz",
+      "integrity": "sha512-KIN/nDJBQRcXw0MLVhZE9iQHmG68qAVIBg9CqmUYjmQIhgij9U5MFvrqkUL5FbtyyzZuOeOt0zdeRe4UY7ct+A==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind-apply-helpers": "^1.0.1",
+        "es-errors": "^1.3.0",
+        "gopd": "^1.2.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/emoji-regex": {
+      "version": "9.2.2",
+      "resolved": "https://registry.npmjs.org/emoji-regex/-/emoji-regex-9.2.2.tgz",
+      "integrity": "sha512-L18DaJsXSUk2+42pv8mLs5jJT2hqFkFE4j21wOmgbUqsZ2hL72NsUU785g9RXgo3s0ZNgVl42TiHp3ZtOv/Vyg==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/enhanced-resolve": {
+      "version": "5.18.3",
+      "resolved": "https://registry.npmjs.org/enhanced-resolve/-/enhanced-resolve-5.18.3.tgz",
+      "integrity": "sha512-d4lC8xfavMeBjzGr2vECC3fsGXziXZQyJxD868h2M/mBI3PwAuODxAkLkq5HYuvrPYcUtiLzsTo8U3PgX3Ocww==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "graceful-fs": "^4.2.4",
+        "tapable": "^2.2.0"
+      },
+      "engines": {
+        "node": ">=10.13.0"
+      }
+    },
+    "node_modules/es-abstract": {
+      "version": "1.24.0",
+      "resolved": "https://registry.npmjs.org/es-abstract/-/es-abstract-1.24.0.tgz",
+      "integrity": "sha512-WSzPgsdLtTcQwm4CROfS5ju2Wa1QQcVeT37jFjYzdFz1r9ahadC8B8/a4qxJxM+09F18iumCdRmlr96ZYkQvEg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "array-buffer-byte-length": "^1.0.2",
+        "arraybuffer.prototype.slice": "^1.0.4",
+        "available-typed-arrays": "^1.0.7",
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.4",
+        "data-view-buffer": "^1.0.2",
+        "data-view-byte-length": "^1.0.2",
+        "data-view-byte-offset": "^1.0.1",
+        "es-define-property": "^1.0.1",
+        "es-errors": "^1.3.0",
+        "es-object-atoms": "^1.1.1",
+        "es-set-tostringtag": "^2.1.0",
+        "es-to-primitive": "^1.3.0",
+        "function.prototype.name": "^1.1.8",
+        "get-intrinsic": "^1.3.0",
+        "get-proto": "^1.0.1",
+        "get-symbol-description": "^1.1.0",
+        "globalthis": "^1.0.4",
+        "gopd": "^1.2.0",
+        "has-property-descriptors": "^1.0.2",
+        "has-proto": "^1.2.0",
+        "has-symbols": "^1.1.0",
+        "hasown": "^2.0.2",
+        "internal-slot": "^1.1.0",
+        "is-array-buffer": "^3.0.5",
+        "is-callable": "^1.2.7",
+        "is-data-view": "^1.0.2",
+        "is-negative-zero": "^2.0.3",
+        "is-regex": "^1.2.1",
+        "is-set": "^2.0.3",
+        "is-shared-array-buffer": "^1.0.4",
+        "is-string": "^1.1.1",
+        "is-typed-array": "^1.1.15",
+        "is-weakref": "^1.1.1",
+        "math-intrinsics": "^1.1.0",
+        "object-inspect": "^1.13.4",
+        "object-keys": "^1.1.1",
+        "object.assign": "^4.1.7",
+        "own-keys": "^1.0.1",
+        "regexp.prototype.flags": "^1.5.4",
+        "safe-array-concat": "^1.1.3",
+        "safe-push-apply": "^1.0.0",
+        "safe-regex-test": "^1.1.0",
+        "set-proto": "^1.0.0",
+        "stop-iteration-iterator": "^1.1.0",
+        "string.prototype.trim": "^1.2.10",
+        "string.prototype.trimend": "^1.0.9",
+        "string.prototype.trimstart": "^1.0.8",
+        "typed-array-buffer": "^1.0.3",
+        "typed-array-byte-length": "^1.0.3",
+        "typed-array-byte-offset": "^1.0.4",
+        "typed-array-length": "^1.0.7",
+        "unbox-primitive": "^1.1.0",
+        "which-typed-array": "^1.1.19"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/es-define-property": {
+      "version": "1.0.1",
+      "resolved": "https://registry.npmjs.org/es-define-property/-/es-define-property-1.0.1.tgz",
+      "integrity": "sha512-e3nRfgfUZ4rNGL232gUgX06QNyyez04KdjFrF+LTRoOXmrOgFKDg4BCdsjW8EnT69eqdYGmRpJwiPVYNrCaW3g==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/es-errors": {
+      "version": "1.3.0",
+      "resolved": "https://registry.npmjs.org/es-errors/-/es-errors-1.3.0.tgz",
+      "integrity": "sha512-Zf5H2Kxt2xjTvbJvP2ZWLEICxA6j+hAmMzIlypy4xcBg1vKVnx89Wy0GbS+kf5cwCVFFzdCFh2XSCFNULS6csw==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/es-iterator-helpers": {
+      "version": "1.2.1",
+      "resolved": "https://registry.npmjs.org/es-iterator-helpers/-/es-iterator-helpers-1.2.1.tgz",
+      "integrity": "sha512-uDn+FE1yrDzyC0pCo961B2IHbdM8y/ACZsKD4dG6WqrjV53BADjwa7D+1aom2rsNVfLyDgU/eigvlJGJ08OQ4w==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.3",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.6",
+        "es-errors": "^1.3.0",
+        "es-set-tostringtag": "^2.0.3",
+        "function-bind": "^1.1.2",
+        "get-intrinsic": "^1.2.6",
+        "globalthis": "^1.0.4",
+        "gopd": "^1.2.0",
+        "has-property-descriptors": "^1.0.2",
+        "has-proto": "^1.2.0",
+        "has-symbols": "^1.1.0",
+        "internal-slot": "^1.1.0",
+        "iterator.prototype": "^1.1.4",
+        "safe-array-concat": "^1.1.3"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/es-object-atoms": {
+      "version": "1.1.1",
+      "resolved": "https://registry.npmjs.org/es-object-atoms/-/es-object-atoms-1.1.1.tgz",
+      "integrity": "sha512-FGgH2h8zKNim9ljj7dankFPcICIK9Cp5bm+c2gQSYePhpaG5+esrLODihIorn+Pe6FGJzWhXQotPv73jTaldXA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-errors": "^1.3.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/es-set-tostringtag": {
+      "version": "2.1.0",
+      "resolved": "https://registry.npmjs.org/es-set-tostringtag/-/es-set-tostringtag-2.1.0.tgz",
+      "integrity": "sha512-j6vWzfrGVfyXxge+O0x5sh6cvxAog0a/4Rdd2K36zCMV5eJ+/+tOAngRO8cODMNWbVRdVlmGZQL2YS3yR8bIUA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-errors": "^1.3.0",
+        "get-intrinsic": "^1.2.6",
+        "has-tostringtag": "^1.0.2",
+        "hasown": "^2.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/es-shim-unscopables": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/es-shim-unscopables/-/es-shim-unscopables-1.1.0.tgz",
+      "integrity": "sha512-d9T8ucsEhh8Bi1woXCf+TIKDIROLG5WCkxg8geBCbvk22kzwC5G2OnXVMO6FUsvQlgUUXQ2itephWDLqDzbeCw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "hasown": "^2.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/es-to-primitive": {
+      "version": "1.3.0",
+      "resolved": "https://registry.npmjs.org/es-to-primitive/-/es-to-primitive-1.3.0.tgz",
+      "integrity": "sha512-w+5mJ3GuFL+NjVtJlvydShqE1eN3h3PbI7/5LAsYJP/2qtuMXjfL2LpHSRqo4b4eSF5K/DH1JXKUAHSB2UW50g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "is-callable": "^1.2.7",
+        "is-date-object": "^1.0.5",
+        "is-symbol": "^1.0.4"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/escape-string-regexp": {
+      "version": "4.0.0",
+      "resolved": "https://registry.npmjs.org/escape-string-regexp/-/escape-string-regexp-4.0.0.tgz",
+      "integrity": "sha512-TtpcNJ3XAzx3Gq8sWRzJaVajRs0uVxA2YAkdb1jm2YkPz4G6egUFAyA3n5vtEIZefPk5Wa4UXbKuS5fKkJWdgA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=10"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    },
+    "node_modules/eslint": {
+      "version": "9.36.0",
+      "resolved": "https://registry.npmjs.org/eslint/-/eslint-9.36.0.tgz",
+      "integrity": "sha512-hB4FIzXovouYzwzECDcUkJ4OcfOEkXTv2zRY6B9bkwjx/cprAq0uvm1nl7zvQ0/TsUk0zQiN4uPfJpB9m+rPMQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@eslint-community/eslint-utils": "^4.8.0",
+        "@eslint-community/regexpp": "^4.12.1",
+        "@eslint/config-array": "^0.21.0",
+        "@eslint/config-helpers": "^0.3.1",
+        "@eslint/core": "^0.15.2",
+        "@eslint/eslintrc": "^3.3.1",
+        "@eslint/js": "9.36.0",
+        "@eslint/plugin-kit": "^0.3.5",
+        "@humanfs/node": "^0.16.6",
+        "@humanwhocodes/module-importer": "^1.0.1",
+        "@humanwhocodes/retry": "^0.4.2",
+        "@types/estree": "^1.0.6",
+        "@types/json-schema": "^7.0.15",
+        "ajv": "^6.12.4",
+        "chalk": "^4.0.0",
+        "cross-spawn": "^7.0.6",
+        "debug": "^4.3.2",
+        "escape-string-regexp": "^4.0.0",
+        "eslint-scope": "^8.4.0",
+        "eslint-visitor-keys": "^4.2.1",
+        "espree": "^10.4.0",
+        "esquery": "^1.5.0",
+        "esutils": "^2.0.2",
+        "fast-deep-equal": "^3.1.3",
+        "file-entry-cache": "^8.0.0",
+        "find-up": "^5.0.0",
+        "glob-parent": "^6.0.2",
+        "ignore": "^5.2.0",
+        "imurmurhash": "^0.1.4",
+        "is-glob": "^4.0.0",
+        "json-stable-stringify-without-jsonify": "^1.0.1",
+        "lodash.merge": "^4.6.2",
+        "minimatch": "^3.1.2",
+        "natural-compare": "^1.4.0",
+        "optionator": "^0.9.3"
+      },
+      "bin": {
+        "eslint": "bin/eslint.js"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "url": "https://eslint.org/donate"
+      },
+      "peerDependencies": {
+        "jiti": "*"
+      },
+      "peerDependenciesMeta": {
+        "jiti": {
+          "optional": true
+        }
+      }
+    },
+    "node_modules/eslint-config-next": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/eslint-config-next/-/eslint-config-next-15.5.4.tgz",
+      "integrity": "sha512-BzgVVuT3kfJes8i2GHenC1SRJ+W3BTML11lAOYFOOPzrk2xp66jBOAGEFRw+3LkYCln5UzvFsLhojrshb5Zfaw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@next/eslint-plugin-next": "15.5.4",
+        "@rushstack/eslint-patch": "^1.10.3",
+        "@typescript-eslint/eslint-plugin": "^5.4.2 || ^6.0.0 || ^7.0.0 || ^8.0.0",
+        "@typescript-eslint/parser": "^5.4.2 || ^6.0.0 || ^7.0.0 || ^8.0.0",
+        "eslint-import-resolver-node": "^0.3.6",
+        "eslint-import-resolver-typescript": "^3.5.2",
+        "eslint-plugin-import": "^2.31.0",
+        "eslint-plugin-jsx-a11y": "^6.10.0",
+        "eslint-plugin-react": "^7.37.0",
+        "eslint-plugin-react-hooks": "^5.0.0"
+      },
+      "peerDependencies": {
+        "eslint": "^7.23.0 || ^8.0.0 || ^9.0.0",
+        "typescript": ">=3.3.1"
+      },
+      "peerDependenciesMeta": {
+        "typescript": {
+          "optional": true
+        }
+      }
+    },
+    "node_modules/eslint-import-resolver-node": {
+      "version": "0.3.9",
+      "resolved": "https://registry.npmjs.org/eslint-import-resolver-node/-/eslint-import-resolver-node-0.3.9.tgz",
+      "integrity": "sha512-WFj2isz22JahUv+B788TlO3N6zL3nNJGU8CcZbPZvVEkBPaJdCV4vy5wyghty5ROFbCRnm132v8BScu5/1BQ8g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "debug": "^3.2.7",
+        "is-core-module": "^2.13.0",
+        "resolve": "^1.22.4"
+      }
+    },
+    "node_modules/eslint-import-resolver-node/node_modules/debug": {
+      "version": "3.2.7",
+      "resolved": "https://registry.npmjs.org/debug/-/debug-3.2.7.tgz",
+      "integrity": "sha512-CFjzYYAi4ThfiQvizrFQevTTXHtnCqWfe7x1AhgEscTz6ZbLbfoLRLPugTQyBth6f8ZERVUSyWHFD/7Wu4t1XQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "ms": "^2.1.1"
+      }
+    },
+    "node_modules/eslint-import-resolver-typescript": {
+      "version": "3.10.1",
+      "resolved": "https://registry.npmjs.org/eslint-import-resolver-typescript/-/eslint-import-resolver-typescript-3.10.1.tgz",
+      "integrity": "sha512-A1rHYb06zjMGAxdLSkN2fXPBwuSaQ0iO5M/hdyS0Ajj1VBaRp0sPD3dn1FhME3c/JluGFbwSxyCfqdSbtQLAHQ==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "@nolyfill/is-core-module": "1.0.39",
+        "debug": "^4.4.0",
+        "get-tsconfig": "^4.10.0",
+        "is-bun-module": "^2.0.0",
+        "stable-hash": "^0.0.5",
+        "tinyglobby": "^0.2.13",
+        "unrs-resolver": "^1.6.2"
+      },
+      "engines": {
+        "node": "^14.18.0 || >=16.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/eslint-import-resolver-typescript"
+      },
+      "peerDependencies": {
+        "eslint": "*",
+        "eslint-plugin-import": "*",
+        "eslint-plugin-import-x": "*"
+      },
+      "peerDependenciesMeta": {
+        "eslint-plugin-import": {
+          "optional": true
+        },
+        "eslint-plugin-import-x": {
+          "optional": true
+        }
+      }
+    },
+    "node_modules/eslint-module-utils": {
+      "version": "2.12.1",
+      "resolved": "https://registry.npmjs.org/eslint-module-utils/-/eslint-module-utils-2.12.1.tgz",
+      "integrity": "sha512-L8jSWTze7K2mTg0vos/RuLRS5soomksDPoJLXIslC7c8Wmut3bx7CPpJijDcBZtxQ5lrbUdM+s0OlNbz0DCDNw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "debug": "^3.2.7"
+      },
+      "engines": {
+        "node": ">=4"
+      },
+      "peerDependenciesMeta": {
+        "eslint": {
+          "optional": true
+        }
+      }
+    },
+    "node_modules/eslint-module-utils/node_modules/debug": {
+      "version": "3.2.7",
+      "resolved": "https://registry.npmjs.org/debug/-/debug-3.2.7.tgz",
+      "integrity": "sha512-CFjzYYAi4ThfiQvizrFQevTTXHtnCqWfe7x1AhgEscTz6ZbLbfoLRLPugTQyBth6f8ZERVUSyWHFD/7Wu4t1XQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "ms": "^2.1.1"
+      }
+    },
+    "node_modules/eslint-plugin-import": {
+      "version": "2.32.0",
+      "resolved": "https://registry.npmjs.org/eslint-plugin-import/-/eslint-plugin-import-2.32.0.tgz",
+      "integrity": "sha512-whOE1HFo/qJDyX4SnXzP4N6zOWn79WhnCUY/iDR0mPfQZO8wcYE4JClzI2oZrhBnnMUCBCHZhO6VQyoBU95mZA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@rtsao/scc": "^1.1.0",
+        "array-includes": "^3.1.9",
+        "array.prototype.findlastindex": "^1.2.6",
+        "array.prototype.flat": "^1.3.3",
+        "array.prototype.flatmap": "^1.3.3",
+        "debug": "^3.2.7",
+        "doctrine": "^2.1.0",
+        "eslint-import-resolver-node": "^0.3.9",
+        "eslint-module-utils": "^2.12.1",
+        "hasown": "^2.0.2",
+        "is-core-module": "^2.16.1",
+        "is-glob": "^4.0.3",
+        "minimatch": "^3.1.2",
+        "object.fromentries": "^2.0.8",
+        "object.groupby": "^1.0.3",
+        "object.values": "^1.2.1",
+        "semver": "^6.3.1",
+        "string.prototype.trimend": "^1.0.9",
+        "tsconfig-paths": "^3.15.0"
+      },
+      "engines": {
+        "node": ">=4"
+      },
+      "peerDependencies": {
+        "eslint": "^2 || ^3 || ^4 || ^5 || ^6 || ^7.2.0 || ^8 || ^9"
+      }
+    },
+    "node_modules/eslint-plugin-import/node_modules/debug": {
+      "version": "3.2.7",
+      "resolved": "https://registry.npmjs.org/debug/-/debug-3.2.7.tgz",
+      "integrity": "sha512-CFjzYYAi4ThfiQvizrFQevTTXHtnCqWfe7x1AhgEscTz6ZbLbfoLRLPugTQyBth6f8ZERVUSyWHFD/7Wu4t1XQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "ms": "^2.1.1"
+      }
+    },
+    "node_modules/eslint-plugin-import/node_modules/semver": {
+      "version": "6.3.1",
+      "resolved": "https://registry.npmjs.org/semver/-/semver-6.3.1.tgz",
+      "integrity": "sha512-BR7VvDCVHO+q2xBEWskxS6DJE1qRnb7DxzUrogb71CWoSficBxYsiAGd+Kl0mmq/MprG9yArRkyrQxTO6XjMzA==",
+      "dev": true,
+      "license": "ISC",
+      "bin": {
+        "semver": "bin/semver.js"
+      }
+    },
+    "node_modules/eslint-plugin-jsx-a11y": {
+      "version": "6.10.2",
+      "resolved": "https://registry.npmjs.org/eslint-plugin-jsx-a11y/-/eslint-plugin-jsx-a11y-6.10.2.tgz",
+      "integrity": "sha512-scB3nz4WmG75pV8+3eRUQOHZlNSUhFNq37xnpgRkCCELU3XMvXAxLk1eqWWyE22Ki4Q01Fnsw9BA3cJHDPgn2Q==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "aria-query": "^5.3.2",
+        "array-includes": "^3.1.8",
+        "array.prototype.flatmap": "^1.3.2",
+        "ast-types-flow": "^0.0.8",
+        "axe-core": "^4.10.0",
+        "axobject-query": "^4.1.0",
+        "damerau-levenshtein": "^1.0.8",
+        "emoji-regex": "^9.2.2",
+        "hasown": "^2.0.2",
+        "jsx-ast-utils": "^3.3.5",
+        "language-tags": "^1.0.9",
+        "minimatch": "^3.1.2",
+        "object.fromentries": "^2.0.8",
+        "safe-regex-test": "^1.0.3",
+        "string.prototype.includes": "^2.0.1"
+      },
+      "engines": {
+        "node": ">=4.0"
+      },
+      "peerDependencies": {
+        "eslint": "^3 || ^4 || ^5 || ^6 || ^7 || ^8 || ^9"
+      }
+    },
+    "node_modules/eslint-plugin-react": {
+      "version": "7.37.5",
+      "resolved": "https://registry.npmjs.org/eslint-plugin-react/-/eslint-plugin-react-7.37.5.tgz",
+      "integrity": "sha512-Qteup0SqU15kdocexFNAJMvCJEfa2xUKNV4CC1xsVMrIIqEy3SQ/rqyxCWNzfrd3/ldy6HMlD2e0JDVpDg2qIA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "array-includes": "^3.1.8",
+        "array.prototype.findlast": "^1.2.5",
+        "array.prototype.flatmap": "^1.3.3",
+        "array.prototype.tosorted": "^1.1.4",
+        "doctrine": "^2.1.0",
+        "es-iterator-helpers": "^1.2.1",
+        "estraverse": "^5.3.0",
+        "hasown": "^2.0.2",
+        "jsx-ast-utils": "^2.4.1 || ^3.0.0",
+        "minimatch": "^3.1.2",
+        "object.entries": "^1.1.9",
+        "object.fromentries": "^2.0.8",
+        "object.values": "^1.2.1",
+        "prop-types": "^15.8.1",
+        "resolve": "^2.0.0-next.5",
+        "semver": "^6.3.1",
+        "string.prototype.matchall": "^4.0.12",
+        "string.prototype.repeat": "^1.0.0"
+      },
+      "engines": {
+        "node": ">=4"
+      },
+      "peerDependencies": {
+        "eslint": "^3 || ^4 || ^5 || ^6 || ^7 || ^8 || ^9.7"
+      }
+    },
+    "node_modules/eslint-plugin-react-hooks": {
+      "version": "5.2.0",
+      "resolved": "https://registry.npmjs.org/eslint-plugin-react-hooks/-/eslint-plugin-react-hooks-5.2.0.tgz",
+      "integrity": "sha512-+f15FfK64YQwZdJNELETdn5ibXEUQmW1DZL6KXhNnc2heoy/sg9VJJeT7n8TlMWouzWqSWavFkIhHyIbIAEapg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=10"
+      },
+      "peerDependencies": {
+        "eslint": "^3.0.0 || ^4.0.0 || ^5.0.0 || ^6.0.0 || ^7.0.0 || ^8.0.0-0 || ^9.0.0"
+      }
+    },
+    "node_modules/eslint-plugin-react/node_modules/resolve": {
+      "version": "2.0.0-next.5",
+      "resolved": "https://registry.npmjs.org/resolve/-/resolve-2.0.0-next.5.tgz",
+      "integrity": "sha512-U7WjGVG9sH8tvjW5SmGbQuui75FiyjAX72HX15DwBBwF9dNiQZRQAg9nnPhYy+TUnE0+VcrttuvNI8oSxZcocA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "is-core-module": "^2.13.0",
+        "path-parse": "^1.0.7",
+        "supports-preserve-symlinks-flag": "^1.0.0"
+      },
+      "bin": {
+        "resolve": "bin/resolve"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/eslint-plugin-react/node_modules/semver": {
+      "version": "6.3.1",
+      "resolved": "https://registry.npmjs.org/semver/-/semver-6.3.1.tgz",
+      "integrity": "sha512-BR7VvDCVHO+q2xBEWskxS6DJE1qRnb7DxzUrogb71CWoSficBxYsiAGd+Kl0mmq/MprG9yArRkyrQxTO6XjMzA==",
+      "dev": true,
+      "license": "ISC",
+      "bin": {
+        "semver": "bin/semver.js"
+      }
+    },
+    "node_modules/eslint-scope": {
+      "version": "8.4.0",
+      "resolved": "https://registry.npmjs.org/eslint-scope/-/eslint-scope-8.4.0.tgz",
+      "integrity": "sha512-sNXOfKCn74rt8RICKMvJS7XKV/Xk9kA7DyJr8mJik3S7Cwgy3qlkkmyS2uQB3jiJg6VNdZd/pDBJu0nvG2NlTg==",
+      "dev": true,
+      "license": "BSD-2-Clause",
+      "dependencies": {
+        "esrecurse": "^4.3.0",
+        "estraverse": "^5.2.0"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/eslint"
+      }
+    },
+    "node_modules/eslint-visitor-keys": {
+      "version": "4.2.1",
+      "resolved": "https://registry.npmjs.org/eslint-visitor-keys/-/eslint-visitor-keys-4.2.1.tgz",
+      "integrity": "sha512-Uhdk5sfqcee/9H/rCOJikYz67o0a2Tw2hGRPOG2Y1R2dg7brRe1uG0yaNQDHu+TO/uQPF/5eCapvYSmHUjt7JQ==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/eslint"
+      }
+    },
+    "node_modules/espree": {
+      "version": "10.4.0",
+      "resolved": "https://registry.npmjs.org/espree/-/espree-10.4.0.tgz",
+      "integrity": "sha512-j6PAQ2uUr79PZhBjP5C5fhl8e39FmRnOjsD5lGnWrFU8i2G776tBK7+nP8KuQUTTyAZUwfQqXAgrVH5MbH9CYQ==",
+      "dev": true,
+      "license": "BSD-2-Clause",
+      "dependencies": {
+        "acorn": "^8.15.0",
+        "acorn-jsx": "^5.3.2",
+        "eslint-visitor-keys": "^4.2.1"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^20.9.0 || >=21.1.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/eslint"
+      }
+    },
+    "node_modules/esquery": {
+      "version": "1.6.0",
+      "resolved": "https://registry.npmjs.org/esquery/-/esquery-1.6.0.tgz",
+      "integrity": "sha512-ca9pw9fomFcKPvFLXhBKUK90ZvGibiGOvRJNbjljY7s7uq/5YO4BOzcYtJqExdx99rF6aAcnRxHmcUHcz6sQsg==",
+      "dev": true,
+      "license": "BSD-3-Clause",
+      "dependencies": {
+        "estraverse": "^5.1.0"
+      },
+      "engines": {
+        "node": ">=0.10"
+      }
+    },
+    "node_modules/esrecurse": {
+      "version": "4.3.0",
+      "resolved": "https://registry.npmjs.org/esrecurse/-/esrecurse-4.3.0.tgz",
+      "integrity": "sha512-KmfKL3b6G+RXvP8N1vr3Tq1kL/oCFgn2NYXEtqP8/L3pKapUA4G8cFVaoF3SU323CD4XypR/ffioHmkti6/Tag==",
+      "dev": true,
+      "license": "BSD-2-Clause",
+      "dependencies": {
+        "estraverse": "^5.2.0"
+      },
+      "engines": {
+        "node": ">=4.0"
+      }
+    },
+    "node_modules/estraverse": {
+      "version": "5.3.0",
+      "resolved": "https://registry.npmjs.org/estraverse/-/estraverse-5.3.0.tgz",
+      "integrity": "sha512-MMdARuVEQziNTeJD8DgMqmhwR11BRQ/cBP+pLtYdSTnf3MIO8fFeiINEbX36ZdNlfU/7A9f3gUw49B3oQsvwBA==",
+      "dev": true,
+      "license": "BSD-2-Clause",
+      "engines": {
+        "node": ">=4.0"
+      }
+    },
+    "node_modules/esutils": {
+      "version": "2.0.3",
+      "resolved": "https://registry.npmjs.org/esutils/-/esutils-2.0.3.tgz",
+      "integrity": "sha512-kVscqXk4OCp68SZ0dkgEKVi6/8ij300KBWTJq32P/dYeWTSwK41WyTxalN1eRmA5Z9UU/LX9D7FWSmV9SAYx6g==",
+      "dev": true,
+      "license": "BSD-2-Clause",
+      "engines": {
+        "node": ">=0.10.0"
+      }
+    },
+    "node_modules/fast-deep-equal": {
+      "version": "3.1.3",
+      "resolved": "https://registry.npmjs.org/fast-deep-equal/-/fast-deep-equal-3.1.3.tgz",
+      "integrity": "sha512-f3qQ9oQy9j2AhBe/H9VC91wLmKBCCU/gDOnKNAYG5hswO7BLKj09Hc5HYNz9cGI++xlpDCIgDaitVs03ATR84Q==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/fast-glob": {
+      "version": "3.3.1",
+      "resolved": "https://registry.npmjs.org/fast-glob/-/fast-glob-3.3.1.tgz",
+      "integrity": "sha512-kNFPyjhh5cKjrUltxs+wFx+ZkbRaxxmZ+X0ZU31SOsxCEtP9VPgtq2teZw1DebupL5GmDaNQ6yKMMVcM41iqDg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@nodelib/fs.stat": "^2.0.2",
+        "@nodelib/fs.walk": "^1.2.3",
+        "glob-parent": "^5.1.2",
+        "merge2": "^1.3.0",
+        "micromatch": "^4.0.4"
+      },
+      "engines": {
+        "node": ">=8.6.0"
+      }
+    },
+    "node_modules/fast-glob/node_modules/glob-parent": {
+      "version": "5.1.2",
+      "resolved": "https://registry.npmjs.org/glob-parent/-/glob-parent-5.1.2.tgz",
+      "integrity": "sha512-AOIgSQCepiJYwP3ARnGx+5VnTu2HBYdzbGP45eLw1vr3zB3vZLeyed1sC9hnbcOc9/SrMyM5RPQrkGz4aS9Zow==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "is-glob": "^4.0.1"
+      },
+      "engines": {
+        "node": ">= 6"
+      }
+    },
+    "node_modules/fast-json-stable-stringify": {
+      "version": "2.1.0",
+      "resolved": "https://registry.npmjs.org/fast-json-stable-stringify/-/fast-json-stable-stringify-2.1.0.tgz",
+      "integrity": "sha512-lhd/wF+Lk98HZoTCtlVraHtfh5XYijIjalXck7saUtuanSDyLMxnHhSXEDJqHxD7msR8D0uCmqlkwjCV8xvwHw==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/fast-levenshtein": {
+      "version": "2.0.6",
+      "resolved": "https://registry.npmjs.org/fast-levenshtein/-/fast-levenshtein-2.0.6.tgz",
+      "integrity": "sha512-DCXu6Ifhqcks7TZKY3Hxp3y6qphY5SJZmrWMDrKcERSOXWQdMhU9Ig/PYrzyw/ul9jOIyh0N4M0tbC5hodg8dw==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/fastq": {
+      "version": "1.19.1",
+      "resolved": "https://registry.npmjs.org/fastq/-/fastq-1.19.1.tgz",
+      "integrity": "sha512-GwLTyxkCXjXbxqIhTsMI2Nui8huMPtnxg7krajPJAjnEG/iiOS7i+zCtWGZR9G0NBKbXKh6X9m9UIsYX/N6vvQ==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "reusify": "^1.0.4"
+      }
+    },
+    "node_modules/file-entry-cache": {
+      "version": "8.0.0",
+      "resolved": "https://registry.npmjs.org/file-entry-cache/-/file-entry-cache-8.0.0.tgz",
+      "integrity": "sha512-XXTUwCvisa5oacNGRP9SfNtYBNAMi+RPwBFmblZEF7N7swHYQS6/Zfk7SRwx4D5j3CH211YNRco1DEMNVfZCnQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "flat-cache": "^4.0.0"
+      },
+      "engines": {
+        "node": ">=16.0.0"
+      }
+    },
+    "node_modules/fill-range": {
+      "version": "7.1.1",
+      "resolved": "https://registry.npmjs.org/fill-range/-/fill-range-7.1.1.tgz",
+      "integrity": "sha512-YsGpe3WHLK8ZYi4tWDg2Jy3ebRz2rXowDxnld4bkQB00cc/1Zw9AWnC0i9ztDJitivtQvaI9KaLyKrc+hBW0yg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "to-regex-range": "^5.0.1"
+      },
+      "engines": {
+        "node": ">=8"
+      }
+    },
+    "node_modules/find-up": {
+      "version": "5.0.0",
+      "resolved": "https://registry.npmjs.org/find-up/-/find-up-5.0.0.tgz",
+      "integrity": "sha512-78/PXT1wlLLDgTzDs7sjq9hzz0vXD+zn+7wypEe4fXQxCmdmqfGsEPQxmiCSQI3ajFV91bVSsvNtrJRiW6nGng==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "locate-path": "^6.0.0",
+        "path-exists": "^4.0.0"
+      },
+      "engines": {
+        "node": ">=10"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    },
+    "node_modules/flat-cache": {
+      "version": "4.0.1",
+      "resolved": "https://registry.npmjs.org/flat-cache/-/flat-cache-4.0.1.tgz",
+      "integrity": "sha512-f7ccFPK3SXFHpx15UIGyRJ/FJQctuKZ0zVuN3frBo4HnK3cay9VEW0R6yPYFHC0AgqhukPzKjq22t5DmAyqGyw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "flatted": "^3.2.9",
+        "keyv": "^4.5.4"
+      },
+      "engines": {
+        "node": ">=16"
+      }
+    },
+    "node_modules/flatted": {
+      "version": "3.3.3",
+      "resolved": "https://registry.npmjs.org/flatted/-/flatted-3.3.3.tgz",
+      "integrity": "sha512-GX+ysw4PBCz0PzosHDepZGANEuFCMLrnRTiEy9McGjmkCQYwRq4A/X786G/fjM/+OjsWSU1ZrY5qyARZmO/uwg==",
+      "dev": true,
+      "license": "ISC"
+    },
+    "node_modules/for-each": {
+      "version": "0.3.5",
+      "resolved": "https://registry.npmjs.org/for-each/-/for-each-0.3.5.tgz",
+      "integrity": "sha512-dKx12eRCVIzqCxFGplyFKJMPvLEWgmNtUrpTiJIR5u97zEhRG8ySrtboPHZXx7daLxQVrl643cTzbab2tkQjxg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "is-callable": "^1.2.7"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/function-bind": {
+      "version": "1.1.2",
+      "resolved": "https://registry.npmjs.org/function-bind/-/function-bind-1.1.2.tgz",
+      "integrity": "sha512-7XHNxH7qX9xG5mIwxkhumTox/MIRNcOgDrxWsMt2pAr23WHp6MrRlN7FBSFpCpr+oVO0F744iUgR82nJMfG2SA==",
+      "dev": true,
+      "license": "MIT",
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/function.prototype.name": {
+      "version": "1.1.8",
+      "resolved": "https://registry.npmjs.org/function.prototype.name/-/function.prototype.name-1.1.8.tgz",
+      "integrity": "sha512-e5iwyodOHhbMr/yNrc7fDYG4qlbIvI5gajyzPnb5TCwyhjApznQh1BMFou9b30SevY43gCJKXycoCBjMbsuW0Q==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.3",
+        "define-properties": "^1.2.1",
+        "functions-have-names": "^1.2.3",
+        "hasown": "^2.0.2",
+        "is-callable": "^1.2.7"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/functions-have-names": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/functions-have-names/-/functions-have-names-1.2.3.tgz",
+      "integrity": "sha512-xckBUXyTIqT97tq2x2AMb+g163b5JFysYk0x4qxNFwbfQkmNZoiRHb6sPzI9/QV33WeuvVYBUIiD4NzNIyqaRQ==",
+      "dev": true,
+      "license": "MIT",
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/generator-function": {
+      "version": "2.0.1",
+      "resolved": "https://registry.npmjs.org/generator-function/-/generator-function-2.0.1.tgz",
+      "integrity": "sha512-SFdFmIJi+ybC0vjlHN0ZGVGHc3lgE0DxPAT0djjVg+kjOnSqclqmj0KQ7ykTOLP6YxoqOvuAODGdcHJn+43q3g==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/get-intrinsic": {
+      "version": "1.3.0",
+      "resolved": "https://registry.npmjs.org/get-intrinsic/-/get-intrinsic-1.3.0.tgz",
+      "integrity": "sha512-9fSjSaos/fRIVIp+xSJlE6lfwhES7LNtKaCBIamHsjr2na1BiABJPo0mOjjz8GJDURarmCPGqaiVg5mfjb98CQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind-apply-helpers": "^1.0.2",
+        "es-define-property": "^1.0.1",
+        "es-errors": "^1.3.0",
+        "es-object-atoms": "^1.1.1",
+        "function-bind": "^1.1.2",
+        "get-proto": "^1.0.1",
+        "gopd": "^1.2.0",
+        "has-symbols": "^1.1.0",
+        "hasown": "^2.0.2",
+        "math-intrinsics": "^1.1.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/get-proto": {
+      "version": "1.0.1",
+      "resolved": "https://registry.npmjs.org/get-proto/-/get-proto-1.0.1.tgz",
+      "integrity": "sha512-sTSfBjoXBp89JvIKIefqw7U2CCebsc74kiY6awiGogKtoSGbgjYE/G/+l9sF3MWFPNc9IcoOC4ODfKHfxFmp0g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "dunder-proto": "^1.0.1",
+        "es-object-atoms": "^1.0.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/get-symbol-description": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/get-symbol-description/-/get-symbol-description-1.1.0.tgz",
+      "integrity": "sha512-w9UMqWwJxHNOvoNzSJ2oPF5wvYcvP7jUvYzhp67yEhTi17ZDBBC1z9pTdGuzjD+EFIqLSYRweZjqfiPzQ06Ebg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "es-errors": "^1.3.0",
+        "get-intrinsic": "^1.2.6"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/get-tsconfig": {
+      "version": "4.10.1",
+      "resolved": "https://registry.npmjs.org/get-tsconfig/-/get-tsconfig-4.10.1.tgz",
+      "integrity": "sha512-auHyJ4AgMz7vgS8Hp3N6HXSmlMdUyhSUrfBF16w153rxtLIEOE+HGqaBppczZvnHLqQJfiHotCYpNhl0lUROFQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "resolve-pkg-maps": "^1.0.0"
+      },
+      "funding": {
+        "url": "https://github.com/privatenumber/get-tsconfig?sponsor=1"
+      }
+    },
+    "node_modules/glob-parent": {
+      "version": "6.0.2",
+      "resolved": "https://registry.npmjs.org/glob-parent/-/glob-parent-6.0.2.tgz",
+      "integrity": "sha512-XxwI8EOhVQgWp6iDL+3b0r86f4d6AX6zSU55HfB4ydCEuXLXc5FcYeOu+nnGftS4TEju/11rt4KJPTMgbfmv4A==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "is-glob": "^4.0.3"
+      },
+      "engines": {
+        "node": ">=10.13.0"
+      }
+    },
+    "node_modules/globals": {
+      "version": "14.0.0",
+      "resolved": "https://registry.npmjs.org/globals/-/globals-14.0.0.tgz",
+      "integrity": "sha512-oahGvuMGQlPw/ivIYBjVSrWAfWLBeku5tpPE2fOPLi+WHffIWbuh2tCjhyQhTBPMf5E9jDEH4FOmTYgYwbKwtQ==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=18"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    },
+    "node_modules/globalthis": {
+      "version": "1.0.4",
+      "resolved": "https://registry.npmjs.org/globalthis/-/globalthis-1.0.4.tgz",
+      "integrity": "sha512-DpLKbNU4WylpxJykQujfCcwYWiV/Jhm50Goo0wrVILAv5jOr9d+H+UR3PhSCD2rCCEIg0uc+G+muBTwD54JhDQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "define-properties": "^1.2.1",
+        "gopd": "^1.0.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/gopd": {
+      "version": "1.2.0",
+      "resolved": "https://registry.npmjs.org/gopd/-/gopd-1.2.0.tgz",
+      "integrity": "sha512-ZUKRh6/kUFoAiTAtTYPZJ3hw9wNxx+BIBOijnlG9PnrJsCcSjs1wyyD6vJpaYtgnzDrKYRSqf3OO6Rfa93xsRg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/graceful-fs": {
+      "version": "4.2.11",
+      "resolved": "https://registry.npmjs.org/graceful-fs/-/graceful-fs-4.2.11.tgz",
+      "integrity": "sha512-RbJ5/jmFcNNCcDV5o9eTnBLJ/HszWV0P73bc+Ff4nS/rJj+YaS6IGyiOL0VoBYX+l1Wrl3k63h/KrH+nhJ0XvQ==",
+      "dev": true,
+      "license": "ISC"
+    },
+    "node_modules/graphemer": {
+      "version": "1.4.0",
+      "resolved": "https://registry.npmjs.org/graphemer/-/graphemer-1.4.0.tgz",
+      "integrity": "sha512-EtKwoO6kxCL9WO5xipiHTZlSzBm7WLT627TqC/uVRd0HKmq8NXyebnNYxDoBi7wt8eTWrUrKXCOVaFq9x1kgag==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/has-bigints": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/has-bigints/-/has-bigints-1.1.0.tgz",
+      "integrity": "sha512-R3pbpkcIqv2Pm3dUwgjclDRVmWpTJW2DcMzcIhEXEx1oh/CEMObMm3KLmRJOdvhM7o4uQBnwr8pzRK2sJWIqfg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/has-flag": {
+      "version": "4.0.0",
+      "resolved": "https://registry.npmjs.org/has-flag/-/has-flag-4.0.0.tgz",
+      "integrity": "sha512-EykJT/Q1KjTWctppgIAgfSO0tKVuZUjhgMr17kqTumMl6Afv3EISleU7qZUzoXDFTAHTDC4NOoG/ZxU3EvlMPQ==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=8"
+      }
+    },
+    "node_modules/has-property-descriptors": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/has-property-descriptors/-/has-property-descriptors-1.0.2.tgz",
+      "integrity": "sha512-55JNKuIW+vq4Ke1BjOTjM2YctQIvCT7GFzHwmfZPGo5wnrgkid0YQtnAleFSqumZm4az3n2BS+erby5ipJdgrg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-define-property": "^1.0.0"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/has-proto": {
+      "version": "1.2.0",
+      "resolved": "https://registry.npmjs.org/has-proto/-/has-proto-1.2.0.tgz",
+      "integrity": "sha512-KIL7eQPfHQRC8+XluaIw7BHUwwqL19bQn4hzNgdr+1wXoU0KKj6rufu47lhY7KbJR2C6T6+PfyN0Ea7wkSS+qQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "dunder-proto": "^1.0.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/has-symbols": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/has-symbols/-/has-symbols-1.1.0.tgz",
+      "integrity": "sha512-1cDNdwJ2Jaohmb3sg4OmKaMBwuC48sYni5HUw2DvsC8LjGTLK9h+eb1X6RyuOHe4hT0ULCW68iomhjUoKUqlPQ==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/has-tostringtag": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/has-tostringtag/-/has-tostringtag-1.0.2.tgz",
+      "integrity": "sha512-NqADB8VjPFLM2V0VvHUewwwsw0ZWBaIdgo+ieHtK3hasLz4qeCRjYcqfB6AQrBggRKppKF8L52/VqdVsO47Dlw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "has-symbols": "^1.0.3"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/hasown": {
+      "version": "2.0.2",
+      "resolved": "https://registry.npmjs.org/hasown/-/hasown-2.0.2.tgz",
+      "integrity": "sha512-0hJU9SCPvmMzIBdZFqNPXWa6dqh7WdH0cII9y+CyS8rG3nL48Bclra9HmKhVVUHyPWNH5Y7xDwAB7bfgSjkUMQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "function-bind": "^1.1.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/ignore": {
+      "version": "5.3.2",
+      "resolved": "https://registry.npmjs.org/ignore/-/ignore-5.3.2.tgz",
+      "integrity": "sha512-hsBTNUqQTDwkWtcdYI2i06Y/nUBEsNEDJKjWdigLvegy8kDuJAS8uRlpkkcQpyEXL0Z/pjDy5HBmMjRCJ2gq+g==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 4"
+      }
+    },
+    "node_modules/import-fresh": {
+      "version": "3.3.1",
+      "resolved": "https://registry.npmjs.org/import-fresh/-/import-fresh-3.3.1.tgz",
+      "integrity": "sha512-TR3KfrTZTYLPB6jUjfx6MF9WcWrHL9su5TObK4ZkYgBdWKPOFoSoQIdEuTuR82pmtxH2spWG9h6etwfr1pLBqQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "parent-module": "^1.0.0",
+        "resolve-from": "^4.0.0"
+      },
+      "engines": {
+        "node": ">=6"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    },
+    "node_modules/imurmurhash": {
+      "version": "0.1.4",
+      "resolved": "https://registry.npmjs.org/imurmurhash/-/imurmurhash-0.1.4.tgz",
+      "integrity": "sha512-JmXMZ6wuvDmLiHEml9ykzqO6lwFbof0GG4IkcGaENdCRDDmMVnny7s5HsIgHCbaq0w2MyPhDqkhTUgS2LU2PHA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=0.8.19"
+      }
+    },
+    "node_modules/internal-slot": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/internal-slot/-/internal-slot-1.1.0.tgz",
+      "integrity": "sha512-4gd7VpWNQNB4UKKCFFVcp1AVv+FMOgs9NKzjHKusc8jTMhd5eL1NqQqOpE0KzMds804/yHlglp3uxgluOqAPLw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-errors": "^1.3.0",
+        "hasown": "^2.0.2",
+        "side-channel": "^1.1.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/is-array-buffer": {
+      "version": "3.0.5",
+      "resolved": "https://registry.npmjs.org/is-array-buffer/-/is-array-buffer-3.0.5.tgz",
+      "integrity": "sha512-DDfANUiiG2wC1qawP66qlTugJeL5HyzMpfr8lLK+jMQirGzNod0B12cFB/9q838Ru27sBwfw78/rdoU7RERz6A==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.3",
+        "get-intrinsic": "^1.2.6"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-async-function": {
+      "version": "2.1.1",
+      "resolved": "https://registry.npmjs.org/is-async-function/-/is-async-function-2.1.1.tgz",
+      "integrity": "sha512-9dgM/cZBnNvjzaMYHVoxxfPj2QXt22Ev7SuuPrs+xav0ukGB0S6d4ydZdEiM48kLx5kDV+QBPrpVnFyefL8kkQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "async-function": "^1.0.0",
+        "call-bound": "^1.0.3",
+        "get-proto": "^1.0.1",
+        "has-tostringtag": "^1.0.2",
+        "safe-regex-test": "^1.1.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-bigint": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/is-bigint/-/is-bigint-1.1.0.tgz",
+      "integrity": "sha512-n4ZT37wG78iz03xPRKJrHTdZbe3IicyucEtdRsV5yglwc3GyUfbAfpSeD0FJ41NbUNSt5wbhqfp1fS+BgnvDFQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "has-bigints": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-boolean-object": {
+      "version": "1.2.2",
+      "resolved": "https://registry.npmjs.org/is-boolean-object/-/is-boolean-object-1.2.2.tgz",
+      "integrity": "sha512-wa56o2/ElJMYqjCjGkXri7it5FbebW5usLw/nPmCMs5DeZ7eziSYZhSmPRn0txqeW4LnAmQQU7FgqLpsEFKM4A==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "has-tostringtag": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-bun-module": {
+      "version": "2.0.0",
+      "resolved": "https://registry.npmjs.org/is-bun-module/-/is-bun-module-2.0.0.tgz",
+      "integrity": "sha512-gNCGbnnnnFAUGKeZ9PdbyeGYJqewpmc2aKHUEMO5nQPWU9lOmv7jcmQIv+qHD8fXW6W7qfuCwX4rY9LNRjXrkQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "semver": "^7.7.1"
+      }
+    },
+    "node_modules/is-callable": {
+      "version": "1.2.7",
+      "resolved": "https://registry.npmjs.org/is-callable/-/is-callable-1.2.7.tgz",
+      "integrity": "sha512-1BC0BVFhS/p0qtw6enp8e+8OD0UrK0oFLztSjNzhcKA3WDuJxxAPXzPuPtKkjEY9UUoEWlX/8fgKeu2S8i9JTA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-core-module": {
+      "version": "2.16.1",
+      "resolved": "https://registry.npmjs.org/is-core-module/-/is-core-module-2.16.1.tgz",
+      "integrity": "sha512-UfoeMA6fIJ8wTYFEUjelnaGI67v6+N7qXJEvQuIGa99l4xsCruSYOVSQ0uPANn4dAzm8lkYPaKLrrijLq7x23w==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "hasown": "^2.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-data-view": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/is-data-view/-/is-data-view-1.0.2.tgz",
+      "integrity": "sha512-RKtWF8pGmS87i2D6gqQu/l7EYRlVdfzemCJN/P3UOs//x1QE7mfhvzHIApBTRf7axvT6DMGwSwBXYCT0nfB9xw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.2",
+        "get-intrinsic": "^1.2.6",
+        "is-typed-array": "^1.1.13"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-date-object": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/is-date-object/-/is-date-object-1.1.0.tgz",
+      "integrity": "sha512-PwwhEakHVKTdRNVOw+/Gyh0+MzlCl4R6qKvkhuvLtPMggI1WAHt9sOwZxQLSGpUaDnrdyDsomoRgNnCfKNSXXg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.2",
+        "has-tostringtag": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-extglob": {
+      "version": "2.1.1",
+      "resolved": "https://registry.npmjs.org/is-extglob/-/is-extglob-2.1.1.tgz",
+      "integrity": "sha512-SbKbANkN603Vi4jEZv49LeVJMn4yGwsbzZworEoyEiutsN3nJYdbO36zfhGJ6QEDpOZIFkDtnq5JRxmvl3jsoQ==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=0.10.0"
+      }
+    },
+    "node_modules/is-finalizationregistry": {
+      "version": "1.1.1",
+      "resolved": "https://registry.npmjs.org/is-finalizationregistry/-/is-finalizationregistry-1.1.1.tgz",
+      "integrity": "sha512-1pC6N8qWJbWoPtEjgcL2xyhQOP491EQjeUo3qTKcmV8YSDDJrOepfG8pcC7h/QgnQHYSv0mJ3Z/ZWxmatVrysg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-generator-function": {
+      "version": "1.1.2",
+      "resolved": "https://registry.npmjs.org/is-generator-function/-/is-generator-function-1.1.2.tgz",
+      "integrity": "sha512-upqt1SkGkODW9tsGNG5mtXTXtECizwtS2kA161M+gJPc1xdb/Ax629af6YrTwcOeQHbewrPNlE5Dx7kzvXTizA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.4",
+        "generator-function": "^2.0.0",
+        "get-proto": "^1.0.1",
+        "has-tostringtag": "^1.0.2",
+        "safe-regex-test": "^1.1.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-glob": {
+      "version": "4.0.3",
+      "resolved": "https://registry.npmjs.org/is-glob/-/is-glob-4.0.3.tgz",
+      "integrity": "sha512-xelSayHH36ZgE7ZWhli7pW34hNbNl8Ojv5KVmkJD4hBdD3th8Tfk9vYasLM+mXWOZhFkgZfxhLSnrwRr4elSSg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "is-extglob": "^2.1.1"
+      },
+      "engines": {
+        "node": ">=0.10.0"
+      }
+    },
+    "node_modules/is-map": {
+      "version": "2.0.3",
+      "resolved": "https://registry.npmjs.org/is-map/-/is-map-2.0.3.tgz",
+      "integrity": "sha512-1Qed0/Hr2m+YqxnM09CjA2d/i6YZNfF6R2oRAOj36eUdS6qIV/huPJNSEpKbupewFs+ZsJlxsjjPbc0/afW6Lw==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-negative-zero": {
+      "version": "2.0.3",
+      "resolved": "https://registry.npmjs.org/is-negative-zero/-/is-negative-zero-2.0.3.tgz",
+      "integrity": "sha512-5KoIu2Ngpyek75jXodFvnafB6DJgr3u8uuK0LEZJjrU19DrMD3EVERaR8sjz8CCGgpZvxPl9SuE1GMVPFHx1mw==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-number": {
+      "version": "7.0.0",
+      "resolved": "https://registry.npmjs.org/is-number/-/is-number-7.0.0.tgz",
+      "integrity": "sha512-41Cifkg6e8TylSpdtTpeLVMqvSBEVzTttHvERD741+pnZ8ANv0004MRL43QKPDlK9cGvNp6NZWZUBlbGXYxxng==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=0.12.0"
+      }
+    },
+    "node_modules/is-number-object": {
+      "version": "1.1.1",
+      "resolved": "https://registry.npmjs.org/is-number-object/-/is-number-object-1.1.1.tgz",
+      "integrity": "sha512-lZhclumE1G6VYD8VHe35wFaIif+CTy5SJIi5+3y4psDgWu4wPDoBhF8NxUOinEc7pHgiTsT6MaBb92rKhhD+Xw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "has-tostringtag": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-regex": {
+      "version": "1.2.1",
+      "resolved": "https://registry.npmjs.org/is-regex/-/is-regex-1.2.1.tgz",
+      "integrity": "sha512-MjYsKHO5O7mCsmRGxWcLWheFqN9DJ/2TmngvjKXihe6efViPqc274+Fx/4fYj/r03+ESvBdTXK0V6tA3rgez1g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.2",
+        "gopd": "^1.2.0",
+        "has-tostringtag": "^1.0.2",
+        "hasown": "^2.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-set": {
+      "version": "2.0.3",
+      "resolved": "https://registry.npmjs.org/is-set/-/is-set-2.0.3.tgz",
+      "integrity": "sha512-iPAjerrse27/ygGLxw+EBR9agv9Y6uLeYVJMu+QNCoouJ1/1ri0mGrcWpfCqFZuzzx3WjtwxG098X+n4OuRkPg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-shared-array-buffer": {
+      "version": "1.0.4",
+      "resolved": "https://registry.npmjs.org/is-shared-array-buffer/-/is-shared-array-buffer-1.0.4.tgz",
+      "integrity": "sha512-ISWac8drv4ZGfwKl5slpHG9OwPNty4jOWPRIhBpxOoD+hqITiwuipOQ2bNthAzwA3B4fIjO4Nln74N0S9byq8A==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-string": {
+      "version": "1.1.1",
+      "resolved": "https://registry.npmjs.org/is-string/-/is-string-1.1.1.tgz",
+      "integrity": "sha512-BtEeSsoaQjlSPBemMQIrY1MY0uM6vnS1g5fmufYOtnxLGUZM2178PKbhsk7Ffv58IX+ZtcvoGwccYsh0PglkAA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "has-tostringtag": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-symbol": {
+      "version": "1.1.1",
+      "resolved": "https://registry.npmjs.org/is-symbol/-/is-symbol-1.1.1.tgz",
+      "integrity": "sha512-9gGx6GTtCQM73BgmHQXfDmLtfjjTUDSyoxTCbp5WtoixAhfgsDirWIcVQ/IHpvI5Vgd5i/J5F7B9cN/WlVbC/w==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.2",
+        "has-symbols": "^1.1.0",
+        "safe-regex-test": "^1.1.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-typed-array": {
+      "version": "1.1.15",
+      "resolved": "https://registry.npmjs.org/is-typed-array/-/is-typed-array-1.1.15.tgz",
+      "integrity": "sha512-p3EcsicXjit7SaskXHs1hA91QxgTw46Fv6EFKKGS5DRFLD8yKnohjF3hxoju94b/OcMZoQukzpPpBE9uLVKzgQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "which-typed-array": "^1.1.16"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-weakmap": {
+      "version": "2.0.2",
+      "resolved": "https://registry.npmjs.org/is-weakmap/-/is-weakmap-2.0.2.tgz",
+      "integrity": "sha512-K5pXYOm9wqY1RgjpL3YTkF39tni1XajUIkawTLUo9EZEVUFga5gSQJF8nNS7ZwJQ02y+1YCNYcMh+HIf1ZqE+w==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-weakref": {
+      "version": "1.1.1",
+      "resolved": "https://registry.npmjs.org/is-weakref/-/is-weakref-1.1.1.tgz",
+      "integrity": "sha512-6i9mGWSlqzNMEqpCp93KwRS1uUOodk2OJ6b+sq7ZPDSy2WuI5NFIxp/254TytR8ftefexkWn5xNiHUNpPOfSew==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/is-weakset": {
+      "version": "2.0.4",
+      "resolved": "https://registry.npmjs.org/is-weakset/-/is-weakset-2.0.4.tgz",
+      "integrity": "sha512-mfcwb6IzQyOKTs84CQMrOwW4gQcaTOAWJ0zzJCl2WSPDrWk/OzDaImWFH3djXhb24g4eudZfLRozAvPGw4d9hQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "get-intrinsic": "^1.2.6"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/isarray": {
+      "version": "2.0.5",
+      "resolved": "https://registry.npmjs.org/isarray/-/isarray-2.0.5.tgz",
+      "integrity": "sha512-xHjhDr3cNBK0BzdUJSPXZntQUx/mwMS5Rw4A7lPJ90XGAO6ISP/ePDNuo0vhqOZU+UD5JoodwCAAoZQd3FeAKw==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/isexe": {
+      "version": "2.0.0",
+      "resolved": "https://registry.npmjs.org/isexe/-/isexe-2.0.0.tgz",
+      "integrity": "sha512-RHxMLp9lnKHGHRng9QFhRCMbYAcVpn69smSGcq3f36xjgVVWThj4qqLbTLlq7Ssj8B+fIQ1EuCEGI2lKsyQeIw==",
+      "dev": true,
+      "license": "ISC"
+    },
+    "node_modules/iterator.prototype": {
+      "version": "1.1.5",
+      "resolved": "https://registry.npmjs.org/iterator.prototype/-/iterator.prototype-1.1.5.tgz",
+      "integrity": "sha512-H0dkQoCa3b2VEeKQBOxFph+JAbcrQdE7KC0UkqwpLmv2EC4P41QXP+rqo9wYodACiG5/WM5s9oDApTU8utwj9g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "define-data-property": "^1.1.4",
+        "es-object-atoms": "^1.0.0",
+        "get-intrinsic": "^1.2.6",
+        "get-proto": "^1.0.0",
+        "has-symbols": "^1.1.0",
+        "set-function-name": "^2.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/jiti": {
+      "version": "2.6.0",
+      "resolved": "https://registry.npmjs.org/jiti/-/jiti-2.6.0.tgz",
+      "integrity": "sha512-VXe6RjJkBPj0ohtqaO8vSWP3ZhAKo66fKrFNCll4BTcwljPLz03pCbaNKfzGP5MbrCYcbJ7v0nOYYwUzTEIdXQ==",
+      "dev": true,
+      "license": "MIT",
+      "bin": {
+        "jiti": "lib/jiti-cli.mjs"
+      }
+    },
+    "node_modules/js-tokens": {
+      "version": "4.0.0",
+      "resolved": "https://registry.npmjs.org/js-tokens/-/js-tokens-4.0.0.tgz",
+      "integrity": "sha512-RdJUflcE3cUzKiMqQgsCu06FPu9UdIJO0beYbPhHN4k6apgJtifcoCtT9bcxOpYBtpD2kCM6Sbzg4CausW/PKQ==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/js-yaml": {
+      "version": "4.1.0",
+      "resolved": "https://registry.npmjs.org/js-yaml/-/js-yaml-4.1.0.tgz",
+      "integrity": "sha512-wpxZs9NoxZaJESJGIZTyDEaYpl0FKSA+FB9aJiyemKhMwkxQg63h4T1KJgUGHpTqPDNRcmmYLugrRjJlBtWvRA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "argparse": "^2.0.1"
+      },
+      "bin": {
+        "js-yaml": "bin/js-yaml.js"
+      }
+    },
+    "node_modules/json-buffer": {
+      "version": "3.0.1",
+      "resolved": "https://registry.npmjs.org/json-buffer/-/json-buffer-3.0.1.tgz",
+      "integrity": "sha512-4bV5BfR2mqfQTJm+V5tPPdf+ZpuhiIvTuAB5g8kcrXOZpTT/QwwVRWBywX1ozr6lEuPdbHxwaJlm9G6mI2sfSQ==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/json-schema-traverse": {
+      "version": "0.4.1",
+      "resolved": "https://registry.npmjs.org/json-schema-traverse/-/json-schema-traverse-0.4.1.tgz",
+      "integrity": "sha512-xbbCH5dCYU5T8LcEhhuh7HJ88HXuW3qsI3Y0zOZFKfZEHcpWiHU/Jxzk629Brsab/mMiHQti9wMP+845RPe3Vg==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/json-stable-stringify-without-jsonify": {
+      "version": "1.0.1",
+      "resolved": "https://registry.npmjs.org/json-stable-stringify-without-jsonify/-/json-stable-stringify-without-jsonify-1.0.1.tgz",
+      "integrity": "sha512-Bdboy+l7tA3OGW6FjyFHWkP5LuByj1Tk33Ljyq0axyzdk9//JSi2u3fP1QSmd1KNwq6VOKYGlAu87CisVir6Pw==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/json5": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/json5/-/json5-1.0.2.tgz",
+      "integrity": "sha512-g1MWMLBiz8FKi1e4w0UyVL3w+iJceWAFBAaBnnGKOpNa5f8TLktkbre1+s6oICydWAm+HRUGTmI+//xv2hvXYA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "minimist": "^1.2.0"
+      },
+      "bin": {
+        "json5": "lib/cli.js"
+      }
+    },
+    "node_modules/jsx-ast-utils": {
+      "version": "3.3.5",
+      "resolved": "https://registry.npmjs.org/jsx-ast-utils/-/jsx-ast-utils-3.3.5.tgz",
+      "integrity": "sha512-ZZow9HBI5O6EPgSJLUb8n2NKgmVWTwCvHGwFuJlMjvLFqlGG6pjirPhtdsseaLZjSibD8eegzmYpUZwoIlj2cQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "array-includes": "^3.1.6",
+        "array.prototype.flat": "^1.3.1",
+        "object.assign": "^4.1.4",
+        "object.values": "^1.1.6"
+      },
+      "engines": {
+        "node": ">=4.0"
+      }
+    },
+    "node_modules/keyv": {
+      "version": "4.5.4",
+      "resolved": "https://registry.npmjs.org/keyv/-/keyv-4.5.4.tgz",
+      "integrity": "sha512-oxVHkHR/EJf2CNXnWxRLW6mg7JyCCUcG0DtEGmL2ctUo1PNTin1PUil+r/+4r5MpVgC/fn1kjsx7mjSujKqIpw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "json-buffer": "3.0.1"
+      }
+    },
+    "node_modules/language-subtag-registry": {
+      "version": "0.3.23",
+      "resolved": "https://registry.npmjs.org/language-subtag-registry/-/language-subtag-registry-0.3.23.tgz",
+      "integrity": "sha512-0K65Lea881pHotoGEa5gDlMxt3pctLi2RplBb7Ezh4rRdLEOtgi7n4EwK9lamnUCkKBqaeKRVebTq6BAxSkpXQ==",
+      "dev": true,
+      "license": "CC0-1.0"
+    },
+    "node_modules/language-tags": {
+      "version": "1.0.9",
+      "resolved": "https://registry.npmjs.org/language-tags/-/language-tags-1.0.9.tgz",
+      "integrity": "sha512-MbjN408fEndfiQXbFQ1vnd+1NoLDsnQW41410oQBXiyXDMYH5z505juWa4KUE1LqxRC7DgOgZDbKLxHIwm27hA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "language-subtag-registry": "^0.3.20"
+      },
+      "engines": {
+        "node": ">=0.10"
+      }
+    },
+    "node_modules/levn": {
+      "version": "0.4.1",
+      "resolved": "https://registry.npmjs.org/levn/-/levn-0.4.1.tgz",
+      "integrity": "sha512-+bT2uH4E5LGE7h/n3evcS/sQlJXCpIp6ym8OWJ5eV6+67Dsql/LaaT7qJBAt2rzfoa/5QBGBhxDix1dMt2kQKQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "prelude-ls": "^1.2.1",
+        "type-check": "~0.4.0"
+      },
+      "engines": {
+        "node": ">= 0.8.0"
+      }
+    },
+    "node_modules/lightningcss": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss/-/lightningcss-1.30.1.tgz",
+      "integrity": "sha512-xi6IyHML+c9+Q3W0S4fCQJOym42pyurFiJUHEcEyHS0CeKzia4yZDEsLlqOFykxOdHpNy0NmvVO31vcSqAxJCg==",
+      "dev": true,
+      "license": "MPL-2.0",
+      "dependencies": {
+        "detect-libc": "^2.0.3"
+      },
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      },
+      "optionalDependencies": {
+        "lightningcss-darwin-arm64": "1.30.1",
+        "lightningcss-darwin-x64": "1.30.1",
+        "lightningcss-freebsd-x64": "1.30.1",
+        "lightningcss-linux-arm-gnueabihf": "1.30.1",
+        "lightningcss-linux-arm64-gnu": "1.30.1",
+        "lightningcss-linux-arm64-musl": "1.30.1",
+        "lightningcss-linux-x64-gnu": "1.30.1",
+        "lightningcss-linux-x64-musl": "1.30.1",
+        "lightningcss-win32-arm64-msvc": "1.30.1",
+        "lightningcss-win32-x64-msvc": "1.30.1"
+      }
+    },
+    "node_modules/lightningcss-darwin-arm64": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-darwin-arm64/-/lightningcss-darwin-arm64-1.30.1.tgz",
+      "integrity": "sha512-c8JK7hyE65X1MHMN+Viq9n11RRC7hgin3HhYKhrMyaXflk5GVplZ60IxyoVtzILeKr+xAJwg6zK6sjTBJ0FKYQ==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/lightningcss-darwin-x64": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-darwin-x64/-/lightningcss-darwin-x64-1.30.1.tgz",
+      "integrity": "sha512-k1EvjakfumAQoTfcXUcHQZhSpLlkAuEkdMBsI/ivWw9hL+7FtilQc0Cy3hrx0AAQrVtQAbMI7YjCgYgvn37PzA==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/lightningcss-freebsd-x64": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-freebsd-x64/-/lightningcss-freebsd-x64-1.30.1.tgz",
+      "integrity": "sha512-kmW6UGCGg2PcyUE59K5r0kWfKPAVy4SltVeut+umLCFoJ53RdCUWxcRDzO1eTaxf/7Q2H7LTquFHPL5R+Gjyig==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "freebsd"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/lightningcss-linux-arm-gnueabihf": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-linux-arm-gnueabihf/-/lightningcss-linux-arm-gnueabihf-1.30.1.tgz",
+      "integrity": "sha512-MjxUShl1v8pit+6D/zSPq9S9dQ2NPFSQwGvxBCYaBYLPlCWuPh9/t1MRS8iUaR8i+a6w7aps+B4N0S1TYP/R+Q==",
+      "cpu": [
+        "arm"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/lightningcss-linux-arm64-gnu": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-linux-arm64-gnu/-/lightningcss-linux-arm64-gnu-1.30.1.tgz",
+      "integrity": "sha512-gB72maP8rmrKsnKYy8XUuXi/4OctJiuQjcuqWNlJQ6jZiWqtPvqFziskH3hnajfvKB27ynbVCucKSm2rkQp4Bw==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/lightningcss-linux-arm64-musl": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-linux-arm64-musl/-/lightningcss-linux-arm64-musl-1.30.1.tgz",
+      "integrity": "sha512-jmUQVx4331m6LIX+0wUhBbmMX7TCfjF5FoOH6SD1CttzuYlGNVpA7QnrmLxrsub43ClTINfGSYyHe2HWeLl5CQ==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/lightningcss-linux-x64-gnu": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-linux-x64-gnu/-/lightningcss-linux-x64-gnu-1.30.1.tgz",
+      "integrity": "sha512-piWx3z4wN8J8z3+O5kO74+yr6ze/dKmPnI7vLqfSqI8bccaTGY5xiSGVIJBDd5K5BHlvVLpUB3S2YCfelyJ1bw==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/lightningcss-linux-x64-musl": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-linux-x64-musl/-/lightningcss-linux-x64-musl-1.30.1.tgz",
+      "integrity": "sha512-rRomAK7eIkL+tHY0YPxbc5Dra2gXlI63HL+v1Pdi1a3sC+tJTcFrHX+E86sulgAXeI7rSzDYhPSeHHjqFhqfeQ==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/lightningcss-win32-arm64-msvc": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-win32-arm64-msvc/-/lightningcss-win32-arm64-msvc-1.30.1.tgz",
+      "integrity": "sha512-mSL4rqPi4iXq5YVqzSsJgMVFENoa4nGTT/GjO2c0Yl9OuQfPsIfncvLrEW6RbbB24WtZ3xP/2CCmI3tNkNV4oA==",
+      "cpu": [
+        "arm64"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/lightningcss-win32-x64-msvc": {
+      "version": "1.30.1",
+      "resolved": "https://registry.npmjs.org/lightningcss-win32-x64-msvc/-/lightningcss-win32-x64-msvc-1.30.1.tgz",
+      "integrity": "sha512-PVqXh48wh4T53F/1CCu8PIPCxLzWyCnn/9T5W1Jpmdy5h9Cwd+0YQS6/LwhHXSafuc61/xg9Lv5OrCby6a++jg==",
+      "cpu": [
+        "x64"
+      ],
+      "dev": true,
+      "license": "MPL-2.0",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/parcel"
+      }
+    },
+    "node_modules/locate-path": {
+      "version": "6.0.0",
+      "resolved": "https://registry.npmjs.org/locate-path/-/locate-path-6.0.0.tgz",
+      "integrity": "sha512-iPZK6eYjbxRu3uB4/WZ3EsEIMJFMqAoopl3R+zuq0UjcAm/MO6KCweDgPfP3elTztoKP3KtnVHxTn2NHBSDVUw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "p-locate": "^5.0.0"
+      },
+      "engines": {
+        "node": ">=10"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    },
+    "node_modules/lodash.merge": {
+      "version": "4.6.2",
+      "resolved": "https://registry.npmjs.org/lodash.merge/-/lodash.merge-4.6.2.tgz",
+      "integrity": "sha512-0KpjqXRVvrYyCsX1swR/XTK0va6VQkQM6MNo7PqW77ByjAhoARA8EfrP1N4+KlKj8YS0ZUCtRT/YUuhyYDujIQ==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/loose-envify": {
+      "version": "1.4.0",
+      "resolved": "https://registry.npmjs.org/loose-envify/-/loose-envify-1.4.0.tgz",
+      "integrity": "sha512-lyuxPGr/Wfhrlem2CL/UcnUc1zcqKAImBDzukY7Y5F/yQiNdko6+fRLevlw1HgMySw7f611UIY408EtxRSoK3Q==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "js-tokens": "^3.0.0 || ^4.0.0"
+      },
+      "bin": {
+        "loose-envify": "cli.js"
+      }
+    },
+    "node_modules/magic-string": {
+      "version": "0.30.19",
+      "resolved": "https://registry.npmjs.org/magic-string/-/magic-string-0.30.19.tgz",
+      "integrity": "sha512-2N21sPY9Ws53PZvsEpVtNuSW+ScYbQdp4b9qUaL+9QkHUrGFKo56Lg9Emg5s9V/qrtNBmiR01sYhUOwu3H+VOw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@jridgewell/sourcemap-codec": "^1.5.5"
+      }
+    },
+    "node_modules/math-intrinsics": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/math-intrinsics/-/math-intrinsics-1.1.0.tgz",
+      "integrity": "sha512-/IXtbwEk5HTPyEwyKX6hGkYXxM9nbj64B+ilVJnC/R6B0pH5G4V3b0pVbL7DBj4tkhBAppbQUlf6F6Xl9LHu1g==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/merge2": {
+      "version": "1.4.1",
+      "resolved": "https://registry.npmjs.org/merge2/-/merge2-1.4.1.tgz",
+      "integrity": "sha512-8q7VEgMJW4J8tcfVPy8g09NcQwZdbwFEqhe/WZkoIzjn/3TGDwtOCYtXGxA3O8tPzpczCCDgv+P2P5y00ZJOOg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 8"
+      }
+    },
+    "node_modules/micromatch": {
+      "version": "4.0.8",
+      "resolved": "https://registry.npmjs.org/micromatch/-/micromatch-4.0.8.tgz",
+      "integrity": "sha512-PXwfBhYu0hBCPw8Dn0E+WDYb7af3dSLVWKi3HGv84IdF4TyFoC0ysxFd0Goxw7nSv4T/PzEJQxsYsEiFCKo2BA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "braces": "^3.0.3",
+        "picomatch": "^2.3.1"
+      },
+      "engines": {
+        "node": ">=8.6"
+      }
+    },
+    "node_modules/minimatch": {
+      "version": "3.1.2",
+      "resolved": "https://registry.npmjs.org/minimatch/-/minimatch-3.1.2.tgz",
+      "integrity": "sha512-J7p63hRiAjw1NDEww1W7i37+ByIrOWO5XQQAzZ3VOcL0PNybwpfmV/N05zFAzwQ9USyEcX6t3UO+K5aqBQOIHw==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "brace-expansion": "^1.1.7"
+      },
+      "engines": {
+        "node": "*"
+      }
+    },
+    "node_modules/minimist": {
+      "version": "1.2.8",
+      "resolved": "https://registry.npmjs.org/minimist/-/minimist-1.2.8.tgz",
+      "integrity": "sha512-2yyAR8qBkN3YuheJanUpWC5U3bb5osDywNB8RzDVlDwDHbocAJveqqj1u8+SVD7jkWT4yvsHCpWqqWqAxb0zCA==",
+      "dev": true,
+      "license": "MIT",
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/minipass": {
+      "version": "7.1.2",
+      "resolved": "https://registry.npmjs.org/minipass/-/minipass-7.1.2.tgz",
+      "integrity": "sha512-qOOzS1cBTWYF4BH8fVePDBOO9iptMnGUEZwNc/cMWnTV2nVLZ7VoNWEPHkYczZA0pdoA7dl6e7FL659nX9S2aw==",
+      "dev": true,
+      "license": "ISC",
+      "engines": {
+        "node": ">=16 || 14 >=14.17"
+      }
+    },
+    "node_modules/minizlib": {
+      "version": "3.1.0",
+      "resolved": "https://registry.npmjs.org/minizlib/-/minizlib-3.1.0.tgz",
+      "integrity": "sha512-KZxYo1BUkWD2TVFLr0MQoM8vUUigWD3LlD83a/75BqC+4qE0Hb1Vo5v1FgcfaNXvfXzr+5EhQ6ing/CaBijTlw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "minipass": "^7.1.2"
+      },
+      "engines": {
+        "node": ">= 18"
+      }
+    },
+    "node_modules/ms": {
+      "version": "2.1.3",
+      "resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
+      "integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/nanoid": {
+      "version": "3.3.11",
+      "resolved": "https://registry.npmjs.org/nanoid/-/nanoid-3.3.11.tgz",
+      "integrity": "sha512-N8SpfPUnUp1bK+PMYW8qSWdl9U+wwNWI4QKxOYDy9JAro3WMX7p2OeVRF9v+347pnakNevPmiHhNmZ2HbFA76w==",
+      "funding": [
+        {
+          "type": "github",
+          "url": "https://github.com/sponsors/ai"
+        }
+      ],
+      "license": "MIT",
+      "bin": {
+        "nanoid": "bin/nanoid.cjs"
+      },
+      "engines": {
+        "node": "^10 || ^12 || ^13.7 || ^14 || >=15.0.1"
+      }
+    },
+    "node_modules/napi-postinstall": {
+      "version": "0.3.3",
+      "resolved": "https://registry.npmjs.org/napi-postinstall/-/napi-postinstall-0.3.3.tgz",
+      "integrity": "sha512-uTp172LLXSxuSYHv/kou+f6KW3SMppU9ivthaVTXian9sOt3XM/zHYHpRZiLgQoxeWfYUnslNWQHF1+G71xcow==",
+      "dev": true,
+      "license": "MIT",
+      "bin": {
+        "napi-postinstall": "lib/cli.js"
+      },
+      "engines": {
+        "node": "^12.20.0 || ^14.18.0 || >=16.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/napi-postinstall"
+      }
+    },
+    "node_modules/natural-compare": {
+      "version": "1.4.0",
+      "resolved": "https://registry.npmjs.org/natural-compare/-/natural-compare-1.4.0.tgz",
+      "integrity": "sha512-OWND8ei3VtNC9h7V60qff3SVobHr996CTwgxubgyQYEpg290h9J0buyECNNJexkFm5sOajh5G116RYA1c8ZMSw==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/next": {
+      "version": "15.5.4",
+      "resolved": "https://registry.npmjs.org/next/-/next-15.5.4.tgz",
+      "integrity": "sha512-xH4Yjhb82sFYQfY3vbkJfgSDgXvBB6a8xPs9i35k6oZJRoQRihZH+4s9Yo2qsWpzBmZ3lPXaJ2KPXLfkvW4LnA==",
+      "license": "MIT",
+      "dependencies": {
+        "@next/env": "15.5.4",
+        "@swc/helpers": "0.5.15",
+        "caniuse-lite": "^1.0.30001579",
+        "postcss": "8.4.31",
+        "styled-jsx": "5.1.6"
+      },
+      "bin": {
+        "next": "dist/bin/next"
+      },
+      "engines": {
+        "node": "^18.18.0 || ^19.8.0 || >= 20.0.0"
+      },
+      "optionalDependencies": {
+        "@next/swc-darwin-arm64": "15.5.4",
+        "@next/swc-darwin-x64": "15.5.4",
+        "@next/swc-linux-arm64-gnu": "15.5.4",
+        "@next/swc-linux-arm64-musl": "15.5.4",
+        "@next/swc-linux-x64-gnu": "15.5.4",
+        "@next/swc-linux-x64-musl": "15.5.4",
+        "@next/swc-win32-arm64-msvc": "15.5.4",
+        "@next/swc-win32-x64-msvc": "15.5.4",
+        "sharp": "^0.34.3"
+      },
+      "peerDependencies": {
+        "@opentelemetry/api": "^1.1.0",
+        "@playwright/test": "^1.51.1",
+        "babel-plugin-react-compiler": "*",
+        "react": "^18.2.0 || 19.0.0-rc-de68d2f4-20241204 || ^19.0.0",
+        "react-dom": "^18.2.0 || 19.0.0-rc-de68d2f4-20241204 || ^19.0.0",
+        "sass": "^1.3.0"
+      },
+      "peerDependenciesMeta": {
+        "@opentelemetry/api": {
+          "optional": true
+        },
+        "@playwright/test": {
+          "optional": true
+        },
+        "babel-plugin-react-compiler": {
+          "optional": true
+        },
+        "sass": {
+          "optional": true
+        }
+      }
+    },
+    "node_modules/next/node_modules/postcss": {
+      "version": "8.4.31",
+      "resolved": "https://registry.npmjs.org/postcss/-/postcss-8.4.31.tgz",
+      "integrity": "sha512-PS08Iboia9mts/2ygV3eLpY5ghnUcfLV/EXTOW1E2qYxJKGGBUtNjN76FYHnMs36RmARn41bC0AZmn+rR0OVpQ==",
+      "funding": [
+        {
+          "type": "opencollective",
+          "url": "https://opencollective.com/postcss/"
+        },
+        {
+          "type": "tidelift",
+          "url": "https://tidelift.com/funding/github/npm/postcss"
+        },
+        {
+          "type": "github",
+          "url": "https://github.com/sponsors/ai"
+        }
+      ],
+      "license": "MIT",
+      "dependencies": {
+        "nanoid": "^3.3.6",
+        "picocolors": "^1.0.0",
+        "source-map-js": "^1.0.2"
+      },
+      "engines": {
+        "node": "^10 || ^12 || >=14"
+      }
+    },
+    "node_modules/object-assign": {
+      "version": "4.1.1",
+      "resolved": "https://registry.npmjs.org/object-assign/-/object-assign-4.1.1.tgz",
+      "integrity": "sha512-rJgTQnkUnH1sFw8yT6VSU3zD3sWmu6sZhIseY8VX+GRu3P6F7Fu+JNDoXfklElbLJSnc3FUQHVe4cU5hj+BcUg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=0.10.0"
+      }
+    },
+    "node_modules/object-inspect": {
+      "version": "1.13.4",
+      "resolved": "https://registry.npmjs.org/object-inspect/-/object-inspect-1.13.4.tgz",
+      "integrity": "sha512-W67iLl4J2EXEGTbfeHCffrjDfitvLANg0UlX3wFUUSTx92KXRFegMHUVgSqE+wvhAbi4WqjGg9czysTV2Epbew==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/object-keys": {
+      "version": "1.1.1",
+      "resolved": "https://registry.npmjs.org/object-keys/-/object-keys-1.1.1.tgz",
+      "integrity": "sha512-NuAESUOUMrlIXOfHKzD6bpPu3tYt3xvjNdRIQ+FeT0lNb4K8WR70CaDxhuNguS2XG+GjkyMwOzsN5ZktImfhLA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/object.assign": {
+      "version": "4.1.7",
+      "resolved": "https://registry.npmjs.org/object.assign/-/object.assign-4.1.7.tgz",
+      "integrity": "sha512-nK28WOo+QIjBkDduTINE4JkF/UJJKyf2EJxvJKfblDpyg0Q+pkOHNTL0Qwy6NP6FhE/EnzV73BxxqcJaXY9anw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.3",
+        "define-properties": "^1.2.1",
+        "es-object-atoms": "^1.0.0",
+        "has-symbols": "^1.1.0",
+        "object-keys": "^1.1.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/object.entries": {
+      "version": "1.1.9",
+      "resolved": "https://registry.npmjs.org/object.entries/-/object.entries-1.1.9.tgz",
+      "integrity": "sha512-8u/hfXFRBD1O0hPUjioLhoWFHRmt6tKA4/vZPyckBr18l1KE9uHrFaFaUi8MDRTpi4uak2goyPTSNJLXX2k2Hw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.4",
+        "define-properties": "^1.2.1",
+        "es-object-atoms": "^1.1.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/object.fromentries": {
+      "version": "2.0.8",
+      "resolved": "https://registry.npmjs.org/object.fromentries/-/object.fromentries-2.0.8.tgz",
+      "integrity": "sha512-k6E21FzySsSK5a21KRADBd/NGneRegFO5pLHfdQLpRDETUNJueLXs3WCzyQ3tFRDYgbq3KHGXfTbi2bs8WQ6rQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.7",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.2",
+        "es-object-atoms": "^1.0.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/object.groupby": {
+      "version": "1.0.3",
+      "resolved": "https://registry.npmjs.org/object.groupby/-/object.groupby-1.0.3.tgz",
+      "integrity": "sha512-+Lhy3TQTuzXI5hevh8sBGqbmurHbbIjAi0Z4S63nthVLmLxfbj4T54a4CfZrXIrt9iP4mVAPYMo/v99taj3wjQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.7",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/object.values": {
+      "version": "1.2.1",
+      "resolved": "https://registry.npmjs.org/object.values/-/object.values-1.2.1.tgz",
+      "integrity": "sha512-gXah6aZrcUxjWg2zR2MwouP2eHlCBzdV4pygudehaKXSGW4v2AsRQUK+lwwXhii6KFZcunEnmSUoYp5CXibxtA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.3",
+        "define-properties": "^1.2.1",
+        "es-object-atoms": "^1.0.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/openai": {
+      "version": "6.0.0",
+      "resolved": "https://registry.npmjs.org/openai/-/openai-6.0.0.tgz",
+      "integrity": "sha512-J7LEmTn3WLZnbyEmMYcMPyT5A0fGzhPwSvVUcNRKy6j2hJIbqSFrJERnUHYNkcoCCalRumypnj9AVoe5bVHd3Q==",
+      "license": "Apache-2.0",
+      "bin": {
+        "openai": "bin/cli"
+      },
+      "peerDependencies": {
+        "ws": "^8.18.0",
+        "zod": "^3.25 || ^4.0"
+      },
+      "peerDependenciesMeta": {
+        "ws": {
+          "optional": true
+        },
+        "zod": {
+          "optional": true
+        }
+      }
+    },
+    "node_modules/optionator": {
+      "version": "0.9.4",
+      "resolved": "https://registry.npmjs.org/optionator/-/optionator-0.9.4.tgz",
+      "integrity": "sha512-6IpQ7mKUxRcZNLIObR0hz7lxsapSSIYNZJwXPGeF0mTVqGKFIXj1DQcMoT22S3ROcLyY/rz0PWaWZ9ayWmad9g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "deep-is": "^0.1.3",
+        "fast-levenshtein": "^2.0.6",
+        "levn": "^0.4.1",
+        "prelude-ls": "^1.2.1",
+        "type-check": "^0.4.0",
+        "word-wrap": "^1.2.5"
+      },
+      "engines": {
+        "node": ">= 0.8.0"
+      }
+    },
+    "node_modules/own-keys": {
+      "version": "1.0.1",
+      "resolved": "https://registry.npmjs.org/own-keys/-/own-keys-1.0.1.tgz",
+      "integrity": "sha512-qFOyK5PjiWZd+QQIh+1jhdb9LpxTF0qs7Pm8o5QHYZ0M3vKqSqzsZaEB6oWlxZ+q2sJBMI/Ktgd2N5ZwQoRHfg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "get-intrinsic": "^1.2.6",
+        "object-keys": "^1.1.1",
+        "safe-push-apply": "^1.0.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/p-limit": {
+      "version": "3.1.0",
+      "resolved": "https://registry.npmjs.org/p-limit/-/p-limit-3.1.0.tgz",
+      "integrity": "sha512-TYOanM3wGwNGsZN2cVTYPArw454xnXj5qmWF1bEoAc4+cU/ol7GVh7odevjp1FNHduHc3KZMcFduxU5Xc6uJRQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "yocto-queue": "^0.1.0"
+      },
+      "engines": {
+        "node": ">=10"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    },
+    "node_modules/p-locate": {
+      "version": "5.0.0",
+      "resolved": "https://registry.npmjs.org/p-locate/-/p-locate-5.0.0.tgz",
+      "integrity": "sha512-LaNjtRWUBY++zB5nE/NwcaoMylSPk+S+ZHNB1TzdbMJMny6dynpAGt7X/tl/QYq3TIeE6nxHppbo2LGymrG5Pw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "p-limit": "^3.0.2"
+      },
+      "engines": {
+        "node": ">=10"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    },
+    "node_modules/parent-module": {
+      "version": "1.0.1",
+      "resolved": "https://registry.npmjs.org/parent-module/-/parent-module-1.0.1.tgz",
+      "integrity": "sha512-GQ2EWRpQV8/o+Aw8YqtfZZPfNRWZYkbidE9k5rpl/hC3vtHHBfGm2Ifi6qWV+coDGkrUKZAxE3Lot5kcsRlh+g==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "callsites": "^3.0.0"
+      },
+      "engines": {
+        "node": ">=6"
+      }
+    },
+    "node_modules/path-exists": {
+      "version": "4.0.0",
+      "resolved": "https://registry.npmjs.org/path-exists/-/path-exists-4.0.0.tgz",
+      "integrity": "sha512-ak9Qy5Q7jYb2Wwcey5Fpvg2KoAc/ZIhLSLOSBmRmygPsGwkVVt0fZa0qrtMz+m6tJTAHfZQ8FnmB4MG4LWy7/w==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=8"
+      }
+    },
+    "node_modules/path-key": {
+      "version": "3.1.1",
+      "resolved": "https://registry.npmjs.org/path-key/-/path-key-3.1.1.tgz",
+      "integrity": "sha512-ojmeN0qd+y0jszEtoY48r0Peq5dwMEkIlCOu6Q5f41lfkswXuKtYrhgoTpLnyIcHm24Uhqx+5Tqm2InSwLhE6Q==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=8"
+      }
+    },
+    "node_modules/path-parse": {
+      "version": "1.0.7",
+      "resolved": "https://registry.npmjs.org/path-parse/-/path-parse-1.0.7.tgz",
+      "integrity": "sha512-LDJzPVEEEPR+y48z93A0Ed0yXb8pAByGWo/k5YYdYgpY2/2EsOsksJrq7lOHxryrVOn1ejG6oAp8ahvOIQD8sw==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/picocolors": {
+      "version": "1.1.1",
+      "resolved": "https://registry.npmjs.org/picocolors/-/picocolors-1.1.1.tgz",
+      "integrity": "sha512-xceH2snhtb5M9liqDsmEw56le376mTZkEX/jEb/RxNFyegNul7eNslCXP9FDj/Lcu0X8KEyMceP2ntpaHrDEVA==",
+      "license": "ISC"
+    },
+    "node_modules/picomatch": {
+      "version": "2.3.1",
+      "resolved": "https://registry.npmjs.org/picomatch/-/picomatch-2.3.1.tgz",
+      "integrity": "sha512-JU3teHTNjmE2VCGFzuY8EXzCDVwEqB2a8fsIvwaStHhAWJEeVd1o1QD80CU6+ZdEXXSLbSsuLwJjkCBWqRQUVA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=8.6"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/jonschlinkert"
+      }
+    },
+    "node_modules/possible-typed-array-names": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/possible-typed-array-names/-/possible-typed-array-names-1.1.0.tgz",
+      "integrity": "sha512-/+5VFTchJDoVj3bhoqi6UeymcD00DAwb1nJwamzPvHEszJ4FpF6SNNbUbOS8yI56qHzdV8eK0qEfOSiodkTdxg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/postcss": {
+      "version": "8.5.6",
+      "resolved": "https://registry.npmjs.org/postcss/-/postcss-8.5.6.tgz",
+      "integrity": "sha512-3Ybi1tAuwAP9s0r1UQ2J4n5Y0G05bJkpUIO0/bI9MhwmD70S5aTWbXGBwxHrelT+XM1k6dM0pk+SwNkpTRN7Pg==",
+      "dev": true,
+      "funding": [
+        {
+          "type": "opencollective",
+          "url": "https://opencollective.com/postcss/"
+        },
+        {
+          "type": "tidelift",
+          "url": "https://tidelift.com/funding/github/npm/postcss"
+        },
+        {
+          "type": "github",
+          "url": "https://github.com/sponsors/ai"
+        }
+      ],
+      "license": "MIT",
+      "dependencies": {
+        "nanoid": "^3.3.11",
+        "picocolors": "^1.1.1",
+        "source-map-js": "^1.2.1"
+      },
+      "engines": {
+        "node": "^10 || ^12 || >=14"
+      }
+    },
+    "node_modules/prelude-ls": {
+      "version": "1.2.1",
+      "resolved": "https://registry.npmjs.org/prelude-ls/-/prelude-ls-1.2.1.tgz",
+      "integrity": "sha512-vkcDPrRZo1QZLbn5RLGPpg/WmIQ65qoWWhcGKf/b5eplkkarX0m9z8ppCat4mlOqUsWpyNuYgO3VRyrYHSzX5g==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.8.0"
+      }
+    },
+    "node_modules/prop-types": {
+      "version": "15.8.1",
+      "resolved": "https://registry.npmjs.org/prop-types/-/prop-types-15.8.1.tgz",
+      "integrity": "sha512-oj87CgZICdulUohogVAR7AjlC0327U4el4L6eAvOqCeudMDVU0NThNaV+b9Df4dXgSP1gXMTnPdhfe/2qDH5cg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "loose-envify": "^1.4.0",
+        "object-assign": "^4.1.1",
+        "react-is": "^16.13.1"
+      }
+    },
+    "node_modules/punycode": {
+      "version": "2.3.1",
+      "resolved": "https://registry.npmjs.org/punycode/-/punycode-2.3.1.tgz",
+      "integrity": "sha512-vYt7UD1U9Wg6138shLtLOvdAu+8DsC/ilFtEVHcH+wydcSpNE20AfSOduf6MkRFahL5FY7X1oU7nKVZFtfq8Fg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=6"
+      }
+    },
+    "node_modules/queue-microtask": {
+      "version": "1.2.3",
+      "resolved": "https://registry.npmjs.org/queue-microtask/-/queue-microtask-1.2.3.tgz",
+      "integrity": "sha512-NuaNSa6flKT5JaSYQzJok04JzTL1CA6aGhv5rfLW3PgqA+M2ChpZQnAC8h8i4ZFkBS8X5RqkDBHA7r4hej3K9A==",
+      "dev": true,
+      "funding": [
+        {
+          "type": "github",
+          "url": "https://github.com/sponsors/feross"
+        },
+        {
+          "type": "patreon",
+          "url": "https://www.patreon.com/feross"
+        },
+        {
+          "type": "consulting",
+          "url": "https://feross.org/support"
+        }
+      ],
+      "license": "MIT"
+    },
+    "node_modules/react": {
+      "version": "19.1.0",
+      "resolved": "https://registry.npmjs.org/react/-/react-19.1.0.tgz",
+      "integrity": "sha512-FS+XFBNvn3GTAWq26joslQgWNoFu08F4kl0J4CgdNKADkdSGXQyTCnKteIAJy96Br6YbpEU1LSzV5dYtjMkMDg==",
+      "license": "MIT",
+      "engines": {
+        "node": ">=0.10.0"
+      }
+    },
+    "node_modules/react-dom": {
+      "version": "19.1.0",
+      "resolved": "https://registry.npmjs.org/react-dom/-/react-dom-19.1.0.tgz",
+      "integrity": "sha512-Xs1hdnE+DyKgeHJeJznQmYMIBG3TKIHJJT95Q58nHLSrElKlGQqDTR2HQ9fx5CN/Gk6Vh/kupBTDLU11/nDk/g==",
+      "license": "MIT",
+      "dependencies": {
+        "scheduler": "^0.26.0"
+      },
+      "peerDependencies": {
+        "react": "^19.1.0"
+      }
+    },
+    "node_modules/react-is": {
+      "version": "16.13.1",
+      "resolved": "https://registry.npmjs.org/react-is/-/react-is-16.13.1.tgz",
+      "integrity": "sha512-24e6ynE2H+OKt4kqsOvNd8kBpV65zoxbA4BVsEOB3ARVWQki/DHzaUoC5KuON/BiccDaCCTZBuOcfZs70kR8bQ==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/reflect.getprototypeof": {
+      "version": "1.0.10",
+      "resolved": "https://registry.npmjs.org/reflect.getprototypeof/-/reflect.getprototypeof-1.0.10.tgz",
+      "integrity": "sha512-00o4I+DVrefhv+nX0ulyi3biSHCPDe+yLv5o/p6d/UVlirijB8E16FtfwSAi4g3tcqrQ4lRAqQSoFEZJehYEcw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.9",
+        "es-errors": "^1.3.0",
+        "es-object-atoms": "^1.0.0",
+        "get-intrinsic": "^1.2.7",
+        "get-proto": "^1.0.1",
+        "which-builtin-type": "^1.2.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/regexp.prototype.flags": {
+      "version": "1.5.4",
+      "resolved": "https://registry.npmjs.org/regexp.prototype.flags/-/regexp.prototype.flags-1.5.4.tgz",
+      "integrity": "sha512-dYqgNSZbDwkaJ2ceRd9ojCGjBq+mOm9LmtXnAnEGyHhN/5R7iDW2TRw3h+o/jCFxus3P2LfWIIiwowAjANm7IA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "define-properties": "^1.2.1",
+        "es-errors": "^1.3.0",
+        "get-proto": "^1.0.1",
+        "gopd": "^1.2.0",
+        "set-function-name": "^2.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/resolve": {
+      "version": "1.22.10",
+      "resolved": "https://registry.npmjs.org/resolve/-/resolve-1.22.10.tgz",
+      "integrity": "sha512-NPRy+/ncIMeDlTAsuqwKIiferiawhefFJtkNSW0qZJEqMEb+qBt/77B/jGeeek+F0uOeN05CDa6HXbbIgtVX4w==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "is-core-module": "^2.16.0",
+        "path-parse": "^1.0.7",
+        "supports-preserve-symlinks-flag": "^1.0.0"
+      },
+      "bin": {
+        "resolve": "bin/resolve"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/resolve-from": {
+      "version": "4.0.0",
+      "resolved": "https://registry.npmjs.org/resolve-from/-/resolve-from-4.0.0.tgz",
+      "integrity": "sha512-pb/MYmXstAkysRFx8piNI1tGFNQIFA3vkE3Gq4EuA1dF6gHp/+vgZqsCGJapvy8N3Q+4o7FwvquPJcnZ7RYy4g==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=4"
+      }
+    },
+    "node_modules/resolve-pkg-maps": {
+      "version": "1.0.0",
+      "resolved": "https://registry.npmjs.org/resolve-pkg-maps/-/resolve-pkg-maps-1.0.0.tgz",
+      "integrity": "sha512-seS2Tj26TBVOC2NIc2rOe2y2ZO7efxITtLZcGSOnHHNOQ7CkiUBfw0Iw2ck6xkIhPwLhKNLS8BO+hEpngQlqzw==",
+      "dev": true,
+      "license": "MIT",
+      "funding": {
+        "url": "https://github.com/privatenumber/resolve-pkg-maps?sponsor=1"
+      }
+    },
+    "node_modules/reusify": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/reusify/-/reusify-1.1.0.tgz",
+      "integrity": "sha512-g6QUff04oZpHs0eG5p83rFLhHeV00ug/Yf9nZM6fLeUrPguBTkTQOdpAWWspMh55TZfVQDPaN3NQJfbVRAxdIw==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "iojs": ">=1.0.0",
+        "node": ">=0.10.0"
+      }
+    },
+    "node_modules/run-parallel": {
+      "version": "1.2.0",
+      "resolved": "https://registry.npmjs.org/run-parallel/-/run-parallel-1.2.0.tgz",
+      "integrity": "sha512-5l4VyZR86LZ/lDxZTR6jqL8AFE2S0IFLMP26AbjsLVADxHdhB/c0GUsH+y39UfCi3dzz8OlQuPmnaJOMoDHQBA==",
+      "dev": true,
+      "funding": [
+        {
+          "type": "github",
+          "url": "https://github.com/sponsors/feross"
+        },
+        {
+          "type": "patreon",
+          "url": "https://www.patreon.com/feross"
+        },
+        {
+          "type": "consulting",
+          "url": "https://feross.org/support"
+        }
+      ],
+      "license": "MIT",
+      "dependencies": {
+        "queue-microtask": "^1.2.2"
+      }
+    },
+    "node_modules/safe-array-concat": {
+      "version": "1.1.3",
+      "resolved": "https://registry.npmjs.org/safe-array-concat/-/safe-array-concat-1.1.3.tgz",
+      "integrity": "sha512-AURm5f0jYEOydBj7VQlVvDrjeFgthDdEF5H1dP+6mNpoXOMo1quQqJ4wvJDyRZ9+pO3kGWoOdmV08cSv2aJV6Q==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.2",
+        "get-intrinsic": "^1.2.6",
+        "has-symbols": "^1.1.0",
+        "isarray": "^2.0.5"
+      },
+      "engines": {
+        "node": ">=0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/safe-push-apply": {
+      "version": "1.0.0",
+      "resolved": "https://registry.npmjs.org/safe-push-apply/-/safe-push-apply-1.0.0.tgz",
+      "integrity": "sha512-iKE9w/Z7xCzUMIZqdBsp6pEQvwuEebH4vdpjcDWnyzaI6yl6O9FHvVpmGelvEHNsoY6wGblkxR6Zty/h00WiSA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-errors": "^1.3.0",
+        "isarray": "^2.0.5"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/safe-regex-test": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/safe-regex-test/-/safe-regex-test-1.1.0.tgz",
+      "integrity": "sha512-x/+Cz4YrimQxQccJf5mKEbIa1NzeCRNI5Ecl/ekmlYaampdNLPalVyIcCZNNH3MvmqBugV5TMYZXv0ljslUlaw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.2",
+        "es-errors": "^1.3.0",
+        "is-regex": "^1.2.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/scheduler": {
+      "version": "0.26.0",
+      "resolved": "https://registry.npmjs.org/scheduler/-/scheduler-0.26.0.tgz",
+      "integrity": "sha512-NlHwttCI/l5gCPR3D1nNXtWABUmBwvZpEQiD4IXSbIDq8BzLIK/7Ir5gTFSGZDUu37K5cMNp0hFtzO38sC7gWA==",
+      "license": "MIT"
+    },
+    "node_modules/semver": {
+      "version": "7.7.2",
+      "resolved": "https://registry.npmjs.org/semver/-/semver-7.7.2.tgz",
+      "integrity": "sha512-RF0Fw+rO5AMf9MAyaRXI4AV0Ulj5lMHqVxxdSgiVbixSCXoEmmX/jk0CuJw4+3SqroYO9VoUh+HcuJivvtJemA==",
+      "devOptional": true,
+      "license": "ISC",
+      "bin": {
+        "semver": "bin/semver.js"
+      },
+      "engines": {
+        "node": ">=10"
+      }
+    },
+    "node_modules/set-function-length": {
+      "version": "1.2.2",
+      "resolved": "https://registry.npmjs.org/set-function-length/-/set-function-length-1.2.2.tgz",
+      "integrity": "sha512-pgRc4hJ4/sNjWCSS9AmnS40x3bNMDTknHgL5UaMBTMyJnU90EgWh1Rz+MC9eFu4BuN/UwZjKQuY/1v3rM7HMfg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "define-data-property": "^1.1.4",
+        "es-errors": "^1.3.0",
+        "function-bind": "^1.1.2",
+        "get-intrinsic": "^1.2.4",
+        "gopd": "^1.0.1",
+        "has-property-descriptors": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/set-function-name": {
+      "version": "2.0.2",
+      "resolved": "https://registry.npmjs.org/set-function-name/-/set-function-name-2.0.2.tgz",
+      "integrity": "sha512-7PGFlmtwsEADb0WYyvCMa1t+yke6daIG4Wirafur5kcf+MhUnPms1UeR0CKQdTZD81yESwMHbtn+TR+dMviakQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "define-data-property": "^1.1.4",
+        "es-errors": "^1.3.0",
+        "functions-have-names": "^1.2.3",
+        "has-property-descriptors": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/set-proto": {
+      "version": "1.0.0",
+      "resolved": "https://registry.npmjs.org/set-proto/-/set-proto-1.0.0.tgz",
+      "integrity": "sha512-RJRdvCo6IAnPdsvP/7m6bsQqNnn1FCBX5ZNtFL98MmFF/4xAIJTIg1YbHW5DC2W5SKZanrC6i4HsJqlajw/dZw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "dunder-proto": "^1.0.1",
+        "es-errors": "^1.3.0",
+        "es-object-atoms": "^1.0.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/sharp": {
+      "version": "0.34.4",
+      "resolved": "https://registry.npmjs.org/sharp/-/sharp-0.34.4.tgz",
+      "integrity": "sha512-FUH39xp3SBPnxWvd5iib1X8XY7J0K0X7d93sie9CJg2PO8/7gmg89Nve6OjItK53/MlAushNNxteBYfM6DEuoA==",
+      "hasInstallScript": true,
+      "license": "Apache-2.0",
+      "optional": true,
+      "dependencies": {
+        "@img/colour": "^1.0.0",
+        "detect-libc": "^2.1.0",
+        "semver": "^7.7.2"
+      },
+      "engines": {
+        "node": "^18.17.0 || ^20.3.0 || >=21.0.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-darwin-arm64": "0.34.4",
+        "@img/sharp-darwin-x64": "0.34.4",
+        "@img/sharp-libvips-darwin-arm64": "1.2.3",
+        "@img/sharp-libvips-darwin-x64": "1.2.3",
+        "@img/sharp-libvips-linux-arm": "1.2.3",
+        "@img/sharp-libvips-linux-arm64": "1.2.3",
+        "@img/sharp-libvips-linux-ppc64": "1.2.3",
+        "@img/sharp-libvips-linux-s390x": "1.2.3",
+        "@img/sharp-libvips-linux-x64": "1.2.3",
+        "@img/sharp-libvips-linuxmusl-arm64": "1.2.3",
+        "@img/sharp-libvips-linuxmusl-x64": "1.2.3",
+        "@img/sharp-linux-arm": "0.34.4",
+        "@img/sharp-linux-arm64": "0.34.4",
+        "@img/sharp-linux-ppc64": "0.34.4",
+        "@img/sharp-linux-s390x": "0.34.4",
+        "@img/sharp-linux-x64": "0.34.4",
+        "@img/sharp-linuxmusl-arm64": "0.34.4",
+        "@img/sharp-linuxmusl-x64": "0.34.4",
+        "@img/sharp-wasm32": "0.34.4",
+        "@img/sharp-win32-arm64": "0.34.4",
+        "@img/sharp-win32-ia32": "0.34.4",
+        "@img/sharp-win32-x64": "0.34.4"
+      }
+    },
+    "node_modules/shebang-command": {
+      "version": "2.0.0",
+      "resolved": "https://registry.npmjs.org/shebang-command/-/shebang-command-2.0.0.tgz",
+      "integrity": "sha512-kHxr2zZpYtdmrN1qDjrrX/Z1rR1kG8Dx+gkpK1G4eXmvXswmcE1hTWBWYUzlraYw1/yZp6YuDY77YtvbN0dmDA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "shebang-regex": "^3.0.0"
+      },
+      "engines": {
+        "node": ">=8"
+      }
+    },
+    "node_modules/shebang-regex": {
+      "version": "3.0.0",
+      "resolved": "https://registry.npmjs.org/shebang-regex/-/shebang-regex-3.0.0.tgz",
+      "integrity": "sha512-7++dFhtcx3353uBaq8DDR4NuxBetBzC7ZQOhmTQInHEd6bSrXdiEyzCvG07Z44UYdLShWUyXt5M/yhz8ekcb1A==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=8"
+      }
+    },
+    "node_modules/side-channel": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/side-channel/-/side-channel-1.1.0.tgz",
+      "integrity": "sha512-ZX99e6tRweoUXqR+VBrslhda51Nh5MTQwou5tnUDgbtyM0dBgmhEDtWGP/xbKn6hqfPRHujUNwz5fy/wbbhnpw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-errors": "^1.3.0",
+        "object-inspect": "^1.13.3",
+        "side-channel-list": "^1.0.0",
+        "side-channel-map": "^1.0.1",
+        "side-channel-weakmap": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/side-channel-list": {
+      "version": "1.0.0",
+      "resolved": "https://registry.npmjs.org/side-channel-list/-/side-channel-list-1.0.0.tgz",
+      "integrity": "sha512-FCLHtRD/gnpCiCHEiJLOwdmFP+wzCmDEkc9y7NsYxeF4u7Btsn1ZuwgwJGxImImHicJArLP4R0yX4c2KCrMrTA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-errors": "^1.3.0",
+        "object-inspect": "^1.13.3"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/side-channel-map": {
+      "version": "1.0.1",
+      "resolved": "https://registry.npmjs.org/side-channel-map/-/side-channel-map-1.0.1.tgz",
+      "integrity": "sha512-VCjCNfgMsby3tTdo02nbjtM/ewra6jPHmpThenkTYh8pG9ucZ/1P8So4u4FGBek/BjpOVsDCMoLA/iuBKIFXRA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.2",
+        "es-errors": "^1.3.0",
+        "get-intrinsic": "^1.2.5",
+        "object-inspect": "^1.13.3"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/side-channel-weakmap": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/side-channel-weakmap/-/side-channel-weakmap-1.0.2.tgz",
+      "integrity": "sha512-WPS/HvHQTYnHisLo9McqBHOJk2FkHO/tlpvldyrnem4aeQp4hai3gythswg6p01oSoTl58rcpiFAjF2br2Ak2A==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.2",
+        "es-errors": "^1.3.0",
+        "get-intrinsic": "^1.2.5",
+        "object-inspect": "^1.13.3",
+        "side-channel-map": "^1.0.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/source-map-js": {
+      "version": "1.2.1",
+      "resolved": "https://registry.npmjs.org/source-map-js/-/source-map-js-1.2.1.tgz",
+      "integrity": "sha512-UXWMKhLOwVKb728IUtQPXxfYU+usdybtUrK/8uGE8CQMvrhOpwvzDBwj0QhSL7MQc7vIsISBG8VQ8+IDQxpfQA==",
+      "license": "BSD-3-Clause",
+      "engines": {
+        "node": ">=0.10.0"
+      }
+    },
+    "node_modules/stable-hash": {
+      "version": "0.0.5",
+      "resolved": "https://registry.npmjs.org/stable-hash/-/stable-hash-0.0.5.tgz",
+      "integrity": "sha512-+L3ccpzibovGXFK+Ap/f8LOS0ahMrHTf3xu7mMLSpEGU0EO9ucaysSylKo9eRDFNhWve/y275iPmIZ4z39a9iA==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/stop-iteration-iterator": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/stop-iteration-iterator/-/stop-iteration-iterator-1.1.0.tgz",
+      "integrity": "sha512-eLoXW/DHyl62zxY4SCaIgnRhuMr6ri4juEYARS8E6sCEqzKpOiE521Ucofdx+KnDZl5xmvGYaaKCk5FEOxJCoQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "es-errors": "^1.3.0",
+        "internal-slot": "^1.1.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/string.prototype.includes": {
+      "version": "2.0.1",
+      "resolved": "https://registry.npmjs.org/string.prototype.includes/-/string.prototype.includes-2.0.1.tgz",
+      "integrity": "sha512-o7+c9bW6zpAdJHTtujeePODAhkuicdAryFsfVKwA+wGw89wJ4GTY484WTucM9hLtDEOpOvI+aHnzqnC5lHp4Rg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.7",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.3"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/string.prototype.matchall": {
+      "version": "4.0.12",
+      "resolved": "https://registry.npmjs.org/string.prototype.matchall/-/string.prototype.matchall-4.0.12.tgz",
+      "integrity": "sha512-6CC9uyBL+/48dYizRf7H7VAYCMCNTBeM78x/VTUe9bFEaxBepPJDa1Ow99LqI/1yF7kuy7Q3cQsYMrcjGUcskA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.3",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.6",
+        "es-errors": "^1.3.0",
+        "es-object-atoms": "^1.0.0",
+        "get-intrinsic": "^1.2.6",
+        "gopd": "^1.2.0",
+        "has-symbols": "^1.1.0",
+        "internal-slot": "^1.1.0",
+        "regexp.prototype.flags": "^1.5.3",
+        "set-function-name": "^2.0.2",
+        "side-channel": "^1.1.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/string.prototype.repeat": {
+      "version": "1.0.0",
+      "resolved": "https://registry.npmjs.org/string.prototype.repeat/-/string.prototype.repeat-1.0.0.tgz",
+      "integrity": "sha512-0u/TldDbKD8bFCQ/4f5+mNRrXwZ8hg2w7ZR8wa16e8z9XpePWl3eGEcUD0OXpEH/VJH/2G3gjUtR3ZOiBe2S/w==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "define-properties": "^1.1.3",
+        "es-abstract": "^1.17.5"
+      }
+    },
+    "node_modules/string.prototype.trim": {
+      "version": "1.2.10",
+      "resolved": "https://registry.npmjs.org/string.prototype.trim/-/string.prototype.trim-1.2.10.tgz",
+      "integrity": "sha512-Rs66F0P/1kedk5lyYyH9uBzuiI/kNRmwJAR9quK6VOtIpZ2G+hMZd+HQbbv25MgCA6gEffoMZYxlTod4WcdrKA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.2",
+        "define-data-property": "^1.1.4",
+        "define-properties": "^1.2.1",
+        "es-abstract": "^1.23.5",
+        "es-object-atoms": "^1.0.0",
+        "has-property-descriptors": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/string.prototype.trimend": {
+      "version": "1.0.9",
+      "resolved": "https://registry.npmjs.org/string.prototype.trimend/-/string.prototype.trimend-1.0.9.tgz",
+      "integrity": "sha512-G7Ok5C6E/j4SGfyLCloXTrngQIQU3PWtXGst3yM7Bea9FRURf1S42ZHlZZtsNque2FN2PoUhfZXYLNWwEr4dLQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.2",
+        "define-properties": "^1.2.1",
+        "es-object-atoms": "^1.0.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/string.prototype.trimstart": {
+      "version": "1.0.8",
+      "resolved": "https://registry.npmjs.org/string.prototype.trimstart/-/string.prototype.trimstart-1.0.8.tgz",
+      "integrity": "sha512-UXSH262CSZY1tfu3G3Secr6uGLCFVPMhIqHjlgCUtCCcgihYc/xKs9djMTMUOb2j1mVSeU8EU6NWc/iQKU6Gfg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.7",
+        "define-properties": "^1.2.1",
+        "es-object-atoms": "^1.0.0"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/strip-bom": {
+      "version": "3.0.0",
+      "resolved": "https://registry.npmjs.org/strip-bom/-/strip-bom-3.0.0.tgz",
+      "integrity": "sha512-vavAMRXOgBVNF6nyEEmL3DBK19iRpDcoIwW+swQ+CbGiu7lju6t+JklA1MHweoWtadgt4ISVUsXLyDq34ddcwA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=4"
+      }
+    },
+    "node_modules/strip-json-comments": {
+      "version": "3.1.1",
+      "resolved": "https://registry.npmjs.org/strip-json-comments/-/strip-json-comments-3.1.1.tgz",
+      "integrity": "sha512-6fPc+R4ihwqP6N/aIv2f1gMH8lOVtWQHoqC4yK6oSDVVocumAsfCqjkXnqiYMhmMwS/mEHLp7Vehlt3ql6lEig==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=8"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    },
+    "node_modules/styled-jsx": {
+      "version": "5.1.6",
+      "resolved": "https://registry.npmjs.org/styled-jsx/-/styled-jsx-5.1.6.tgz",
+      "integrity": "sha512-qSVyDTeMotdvQYoHWLNGwRFJHC+i+ZvdBRYosOFgC+Wg1vx4frN2/RG/NA7SYqqvKNLf39P2LSRA2pu6n0XYZA==",
+      "license": "MIT",
+      "dependencies": {
+        "client-only": "0.0.1"
+      },
+      "engines": {
+        "node": ">= 12.0.0"
+      },
+      "peerDependencies": {
+        "react": ">= 16.8.0 || 17.x.x || ^18.0.0-0 || ^19.0.0-0"
+      },
+      "peerDependenciesMeta": {
+        "@babel/core": {
+          "optional": true
+        },
+        "babel-plugin-macros": {
+          "optional": true
+        }
+      }
+    },
+    "node_modules/supports-color": {
+      "version": "7.2.0",
+      "resolved": "https://registry.npmjs.org/supports-color/-/supports-color-7.2.0.tgz",
+      "integrity": "sha512-qpCAvRl9stuOHveKsn7HncJRvv501qIacKzQlO/+Lwxc9+0q2wLyv4Dfvt80/DPn2pqOBsJdDiogXGR9+OvwRw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "has-flag": "^4.0.0"
+      },
+      "engines": {
+        "node": ">=8"
+      }
+    },
+    "node_modules/supports-preserve-symlinks-flag": {
+      "version": "1.0.0",
+      "resolved": "https://registry.npmjs.org/supports-preserve-symlinks-flag/-/supports-preserve-symlinks-flag-1.0.0.tgz",
+      "integrity": "sha512-ot0WnXS9fgdkgIcePe6RHNk1WA8+muPa6cSjeR3V8K27q9BB1rTE3R1p7Hv0z1ZyAc8s6Vvv8DIyWf681MAt0w==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/tailwindcss": {
+      "version": "4.1.13",
+      "resolved": "https://registry.npmjs.org/tailwindcss/-/tailwindcss-4.1.13.tgz",
+      "integrity": "sha512-i+zidfmTqtwquj4hMEwdjshYYgMbOrPzb9a0M3ZgNa0JMoZeFC6bxZvO8yr8ozS6ix2SDz0+mvryPeBs2TFE+w==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/tapable": {
+      "version": "2.2.3",
+      "resolved": "https://registry.npmjs.org/tapable/-/tapable-2.2.3.tgz",
+      "integrity": "sha512-ZL6DDuAlRlLGghwcfmSn9sK3Hr6ArtyudlSAiCqQ6IfE+b+HHbydbYDIG15IfS5do+7XQQBdBiubF/cV2dnDzg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=6"
+      },
+      "funding": {
+        "type": "opencollective",
+        "url": "https://opencollective.com/webpack"
+      }
+    },
+    "node_modules/tar": {
+      "version": "7.5.1",
+      "resolved": "https://registry.npmjs.org/tar/-/tar-7.5.1.tgz",
+      "integrity": "sha512-nlGpxf+hv0v7GkWBK2V9spgactGOp0qvfWRxUMjqHyzrt3SgwE48DIv/FhqPHJYLHpgW1opq3nERbz5Anq7n1g==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "@isaacs/fs-minipass": "^4.0.0",
+        "chownr": "^3.0.0",
+        "minipass": "^7.1.2",
+        "minizlib": "^3.1.0",
+        "yallist": "^5.0.0"
+      },
+      "engines": {
+        "node": ">=18"
+      }
+    },
+    "node_modules/tinyglobby": {
+      "version": "0.2.15",
+      "resolved": "https://registry.npmjs.org/tinyglobby/-/tinyglobby-0.2.15.tgz",
+      "integrity": "sha512-j2Zq4NyQYG5XMST4cbs02Ak8iJUdxRM0XI5QyxXuZOzKOINmWurp3smXu3y5wDcJrptwpSjgXHzIQxR0omXljQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "fdir": "^6.5.0",
+        "picomatch": "^4.0.3"
+      },
+      "engines": {
+        "node": ">=12.0.0"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/SuperchupuDev"
+      }
+    },
+    "node_modules/tinyglobby/node_modules/fdir": {
+      "version": "6.5.0",
+      "resolved": "https://registry.npmjs.org/fdir/-/fdir-6.5.0.tgz",
+      "integrity": "sha512-tIbYtZbucOs0BRGqPJkshJUYdL+SDH7dVM8gjy+ERp3WAUjLEFJE+02kanyHtwjWOnwrKYBiwAmM0p4kLJAnXg==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=12.0.0"
+      },
+      "peerDependencies": {
+        "picomatch": "^3 || ^4"
+      },
+      "peerDependenciesMeta": {
+        "picomatch": {
+          "optional": true
+        }
+      }
+    },
+    "node_modules/tinyglobby/node_modules/picomatch": {
+      "version": "4.0.3",
+      "resolved": "https://registry.npmjs.org/picomatch/-/picomatch-4.0.3.tgz",
+      "integrity": "sha512-5gTmgEY/sqK6gFXLIsQNH19lWb4ebPDLA4SdLP7dsWkIXHWlG66oPuVvXSGFPppYZz8ZDZq0dYYrbHfBCVUb1Q==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=12"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/jonschlinkert"
+      }
+    },
+    "node_modules/to-regex-range": {
+      "version": "5.0.1",
+      "resolved": "https://registry.npmjs.org/to-regex-range/-/to-regex-range-5.0.1.tgz",
+      "integrity": "sha512-65P7iz6X5yEr1cwcgvQxbbIw7Uk3gOy5dIdtZ4rDveLqhrdJP+Li/Hx6tyK0NEb+2GCyneCMJiGqrADCSNk8sQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "is-number": "^7.0.0"
+      },
+      "engines": {
+        "node": ">=8.0"
+      }
+    },
+    "node_modules/ts-api-utils": {
+      "version": "2.1.0",
+      "resolved": "https://registry.npmjs.org/ts-api-utils/-/ts-api-utils-2.1.0.tgz",
+      "integrity": "sha512-CUgTZL1irw8u29bzrOD/nH85jqyc74D6SshFgujOIA7osm2Rz7dYH77agkx7H4FBNxDq7Cjf+IjaX/8zwFW+ZQ==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=18.12"
+      },
+      "peerDependencies": {
+        "typescript": ">=4.8.4"
+      }
+    },
+    "node_modules/tsconfig-paths": {
+      "version": "3.15.0",
+      "resolved": "https://registry.npmjs.org/tsconfig-paths/-/tsconfig-paths-3.15.0.tgz",
+      "integrity": "sha512-2Ac2RgzDe/cn48GvOe3M+o82pEFewD3UPbyoUHHdKasHwJKjds4fLXWf/Ux5kATBKN20oaFGu+jbElp1pos0mg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@types/json5": "^0.0.29",
+        "json5": "^1.0.2",
+        "minimist": "^1.2.6",
+        "strip-bom": "^3.0.0"
+      }
+    },
+    "node_modules/tslib": {
+      "version": "2.8.1",
+      "resolved": "https://registry.npmjs.org/tslib/-/tslib-2.8.1.tgz",
+      "integrity": "sha512-oJFu94HQb+KVduSUQL7wnpmqnfmLsOA/nAh6b6EH0wCEoK0/mPeXU6c3wKDV83MkOuHPRHtSXKKU99IBazS/2w==",
+      "license": "0BSD"
+    },
+    "node_modules/type-check": {
+      "version": "0.4.0",
+      "resolved": "https://registry.npmjs.org/type-check/-/type-check-0.4.0.tgz",
+      "integrity": "sha512-XleUoc9uwGXqjWwXaUTZAmzMcFZ5858QA2vvx1Ur5xIcixXIP+8LnFDgRplU30us6teqdlskFfu+ae4K79Ooew==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "prelude-ls": "^1.2.1"
+      },
+      "engines": {
+        "node": ">= 0.8.0"
+      }
+    },
+    "node_modules/typed-array-buffer": {
+      "version": "1.0.3",
+      "resolved": "https://registry.npmjs.org/typed-array-buffer/-/typed-array-buffer-1.0.3.tgz",
+      "integrity": "sha512-nAYYwfY3qnzX30IkA6AQZjVbtK6duGontcQm1WSG1MD94YLqK0515GNApXkoxKOWMusVssAHWLh9SeaoefYFGw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "es-errors": "^1.3.0",
+        "is-typed-array": "^1.1.14"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      }
+    },
+    "node_modules/typed-array-byte-length": {
+      "version": "1.0.3",
+      "resolved": "https://registry.npmjs.org/typed-array-byte-length/-/typed-array-byte-length-1.0.3.tgz",
+      "integrity": "sha512-BaXgOuIxz8n8pIq3e7Atg/7s+DpiYrxn4vdot3w9KbnBhcRQq6o3xemQdIfynqSeXeDrF32x+WvfzmOjPiY9lg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.8",
+        "for-each": "^0.3.3",
+        "gopd": "^1.2.0",
+        "has-proto": "^1.2.0",
+        "is-typed-array": "^1.1.14"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/typed-array-byte-offset": {
+      "version": "1.0.4",
+      "resolved": "https://registry.npmjs.org/typed-array-byte-offset/-/typed-array-byte-offset-1.0.4.tgz",
+      "integrity": "sha512-bTlAFB/FBYMcuX81gbL4OcpH5PmlFHqlCCpAl8AlEzMz5k53oNDvN8p1PNOWLEmI2x4orp3raOFB51tv9X+MFQ==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "available-typed-arrays": "^1.0.7",
+        "call-bind": "^1.0.8",
+        "for-each": "^0.3.3",
+        "gopd": "^1.2.0",
+        "has-proto": "^1.2.0",
+        "is-typed-array": "^1.1.15",
+        "reflect.getprototypeof": "^1.0.9"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/typed-array-length": {
+      "version": "1.0.7",
+      "resolved": "https://registry.npmjs.org/typed-array-length/-/typed-array-length-1.0.7.tgz",
+      "integrity": "sha512-3KS2b+kL7fsuk/eJZ7EQdnEmQoaho/r6KUef7hxvltNA5DR8NAUM+8wJMbJyZ4G9/7i3v5zPBIMN5aybAh2/Jg==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bind": "^1.0.7",
+        "for-each": "^0.3.3",
+        "gopd": "^1.0.1",
+        "is-typed-array": "^1.1.13",
+        "possible-typed-array-names": "^1.0.0",
+        "reflect.getprototypeof": "^1.0.6"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/typescript": {
+      "version": "5.9.3",
+      "resolved": "https://registry.npmjs.org/typescript/-/typescript-5.9.3.tgz",
+      "integrity": "sha512-jl1vZzPDinLr9eUt3J/t7V6FgNEw9QjvBPdysz9KfQDD41fQrC2Y4vKQdiaUpFT4bXlb1RHhLpp8wtm6M5TgSw==",
+      "dev": true,
+      "license": "Apache-2.0",
+      "bin": {
+        "tsc": "bin/tsc",
+        "tsserver": "bin/tsserver"
+      },
+      "engines": {
+        "node": ">=14.17"
+      }
+    },
+    "node_modules/unbox-primitive": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/unbox-primitive/-/unbox-primitive-1.1.0.tgz",
+      "integrity": "sha512-nWJ91DjeOkej/TA8pXQ3myruKpKEYgqvpw9lz4OPHj/NWFNluYrjbz9j01CJ8yKQd2g4jFoOkINCTW2I5LEEyw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.3",
+        "has-bigints": "^1.0.2",
+        "has-symbols": "^1.1.0",
+        "which-boxed-primitive": "^1.1.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/undici-types": {
+      "version": "6.21.0",
+      "resolved": "https://registry.npmjs.org/undici-types/-/undici-types-6.21.0.tgz",
+      "integrity": "sha512-iwDZqg0QAGrg9Rav5H4n0M64c3mkR59cJ6wQp+7C4nI0gsmExaedaYLNO44eT4AtBBwjbTiGPMlt2Md0T9H9JQ==",
+      "dev": true,
+      "license": "MIT"
+    },
+    "node_modules/unrs-resolver": {
+      "version": "1.11.1",
+      "resolved": "https://registry.npmjs.org/unrs-resolver/-/unrs-resolver-1.11.1.tgz",
+      "integrity": "sha512-bSjt9pjaEBnNiGgc9rUiHGKv5l4/TGzDmYw3RhnkJGtLhbnnA/5qJj7x3dNDCRx/PJxu774LlH8lCOlB4hEfKg==",
+      "dev": true,
+      "hasInstallScript": true,
+      "license": "MIT",
+      "dependencies": {
+        "napi-postinstall": "^0.3.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/unrs-resolver"
+      },
+      "optionalDependencies": {
+        "@unrs/resolver-binding-android-arm-eabi": "1.11.1",
+        "@unrs/resolver-binding-android-arm64": "1.11.1",
+        "@unrs/resolver-binding-darwin-arm64": "1.11.1",
+        "@unrs/resolver-binding-darwin-x64": "1.11.1",
+        "@unrs/resolver-binding-freebsd-x64": "1.11.1",
+        "@unrs/resolver-binding-linux-arm-gnueabihf": "1.11.1",
+        "@unrs/resolver-binding-linux-arm-musleabihf": "1.11.1",
+        "@unrs/resolver-binding-linux-arm64-gnu": "1.11.1",
+        "@unrs/resolver-binding-linux-arm64-musl": "1.11.1",
+        "@unrs/resolver-binding-linux-ppc64-gnu": "1.11.1",
+        "@unrs/resolver-binding-linux-riscv64-gnu": "1.11.1",
+        "@unrs/resolver-binding-linux-riscv64-musl": "1.11.1",
+        "@unrs/resolver-binding-linux-s390x-gnu": "1.11.1",
+        "@unrs/resolver-binding-linux-x64-gnu": "1.11.1",
+        "@unrs/resolver-binding-linux-x64-musl": "1.11.1",
+        "@unrs/resolver-binding-wasm32-wasi": "1.11.1",
+        "@unrs/resolver-binding-win32-arm64-msvc": "1.11.1",
+        "@unrs/resolver-binding-win32-ia32-msvc": "1.11.1",
+        "@unrs/resolver-binding-win32-x64-msvc": "1.11.1"
+      }
+    },
+    "node_modules/uri-js": {
+      "version": "4.4.1",
+      "resolved": "https://registry.npmjs.org/uri-js/-/uri-js-4.4.1.tgz",
+      "integrity": "sha512-7rKUyy33Q1yc98pQ1DAmLtwX109F7TIfWlW1Ydo8Wl1ii1SeHieeh0HHfPeL2fMXK6z0s8ecKs9frCuLJvndBg==",
+      "dev": true,
+      "license": "BSD-2-Clause",
+      "dependencies": {
+        "punycode": "^2.1.0"
+      }
+    },
+    "node_modules/which": {
+      "version": "2.0.2",
+      "resolved": "https://registry.npmjs.org/which/-/which-2.0.2.tgz",
+      "integrity": "sha512-BLI3Tl1TW3Pvl70l3yq3Y64i+awpwXqsGBYWkkqMtnbXgrMD+yj7rhW0kuEDxzJaYXGjEW5ogapKNMEKNMjibA==",
+      "dev": true,
+      "license": "ISC",
+      "dependencies": {
+        "isexe": "^2.0.0"
+      },
+      "bin": {
+        "node-which": "bin/node-which"
+      },
+      "engines": {
+        "node": ">= 8"
+      }
+    },
+    "node_modules/which-boxed-primitive": {
+      "version": "1.1.1",
+      "resolved": "https://registry.npmjs.org/which-boxed-primitive/-/which-boxed-primitive-1.1.1.tgz",
+      "integrity": "sha512-TbX3mj8n0odCBFVlY8AxkqcHASw3L60jIuF8jFP78az3C2YhmGvqbHBpAjTRH2/xqYunrJ9g1jSyjCjpoWzIAA==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "is-bigint": "^1.1.0",
+        "is-boolean-object": "^1.2.1",
+        "is-number-object": "^1.1.1",
+        "is-string": "^1.1.1",
+        "is-symbol": "^1.1.1"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/which-builtin-type": {
+      "version": "1.2.1",
+      "resolved": "https://registry.npmjs.org/which-builtin-type/-/which-builtin-type-1.2.1.tgz",
+      "integrity": "sha512-6iBczoX+kDQ7a3+YJBnh3T+KZRxM/iYNPXicqk66/Qfm1b93iu+yOImkg0zHbj5LNOcNv1TEADiZ0xa34B4q6Q==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "call-bound": "^1.0.2",
+        "function.prototype.name": "^1.1.6",
+        "has-tostringtag": "^1.0.2",
+        "is-async-function": "^2.0.0",
+        "is-date-object": "^1.1.0",
+        "is-finalizationregistry": "^1.1.0",
+        "is-generator-function": "^1.0.10",
+        "is-regex": "^1.2.1",
+        "is-weakref": "^1.0.2",
+        "isarray": "^2.0.5",
+        "which-boxed-primitive": "^1.1.0",
+        "which-collection": "^1.0.2",
+        "which-typed-array": "^1.1.16"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/which-collection": {
+      "version": "1.0.2",
+      "resolved": "https://registry.npmjs.org/which-collection/-/which-collection-1.0.2.tgz",
+      "integrity": "sha512-K4jVyjnBdgvc86Y6BkaLZEN933SwYOuBFkdmBu9ZfkcAbdVbpITnDmjvZ/aQjRXQrv5EPkTnD1s39GiiqbngCw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "is-map": "^2.0.3",
+        "is-set": "^2.0.3",
+        "is-weakmap": "^2.0.2",
+        "is-weakset": "^2.0.3"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/which-typed-array": {
+      "version": "1.1.19",
+      "resolved": "https://registry.npmjs.org/which-typed-array/-/which-typed-array-1.1.19.tgz",
+      "integrity": "sha512-rEvr90Bck4WZt9HHFC4DJMsjvu7x+r6bImz0/BrbWb7A2djJ8hnZMrWnHo9F8ssv0OMErasDhftrfROTyqSDrw==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "available-typed-arrays": "^1.0.7",
+        "call-bind": "^1.0.8",
+        "call-bound": "^1.0.4",
+        "for-each": "^0.3.5",
+        "get-proto": "^1.0.1",
+        "gopd": "^1.2.0",
+        "has-tostringtag": "^1.0.2"
+      },
+      "engines": {
+        "node": ">= 0.4"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/ljharb"
+      }
+    },
+    "node_modules/word-wrap": {
+      "version": "1.2.5",
+      "resolved": "https://registry.npmjs.org/word-wrap/-/word-wrap-1.2.5.tgz",
+      "integrity": "sha512-BN22B5eaMMI9UMtjrGd5g5eCYPpCPDUy0FJXbYsaT5zYxjFOckS53SQDE3pWkVoWpHXVb3BrYcEN4Twa55B5cA==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=0.10.0"
+      }
+    },
+    "node_modules/yallist": {
+      "version": "5.0.0",
+      "resolved": "https://registry.npmjs.org/yallist/-/yallist-5.0.0.tgz",
+      "integrity": "sha512-YgvUTfwqyc7UXVMrB+SImsVYSmTS8X/tSrtdNZMImM+n7+QTriRXyXim0mBrTXNeqzVF0KWGgHPeiyViFFrNDw==",
+      "dev": true,
+      "license": "BlueOak-1.0.0",
+      "engines": {
+        "node": ">=18"
+      }
+    },
+    "node_modules/yocto-queue": {
+      "version": "0.1.0",
+      "resolved": "https://registry.npmjs.org/yocto-queue/-/yocto-queue-0.1.0.tgz",
+      "integrity": "sha512-rVksvsnNCdJ/ohGc6xgPwyN8eheCxsiLM8mxuE/t/mOVqJewPuO1miLpTHQiRgTKCLexL4MeAFVagts7HmNZ2Q==",
+      "dev": true,
+      "license": "MIT",
+      "engines": {
+        "node": ">=10"
+      },
+      "funding": {
+        "url": "https://github.com/sponsors/sindresorhus"
+      }
+    }
+  }
+}
diff --git a/package.json b/package.json
new file mode 100644
index 0000000000000000000000000000000000000000..cff6120cc7c585ccb641d27622d8d3c39ab804ba
--- /dev/null
+++ b/package.json
@@ -0,0 +1,28 @@
+{
+  "name": "ratemyportfolio",
+  "version": "0.1.0",
+  "private": true,
+  "scripts": {
+    "dev": "next dev --turbopack",
+    "build": "next build --turbopack",
+    "start": "next start",
+    "lint": "eslint"
+  },
+  "dependencies": {
+    "next": "15.5.4",
+    "openai": "^6.0.0",
+    "react": "19.1.0",
+    "react-dom": "19.1.0"
+  },
+  "devDependencies": {
+    "@eslint/eslintrc": "^3",
+    "@tailwindcss/postcss": "^4",
+    "@types/node": "^20",
+    "@types/react": "^19",
+    "@types/react-dom": "^19",
+    "eslint": "^9",
+    "eslint-config-next": "15.5.4",
+    "tailwindcss": "^4",
+    "typescript": "^5"
+  }
+}
diff --git a/postcss.config.mjs b/postcss.config.mjs
new file mode 100644
index 0000000000000000000000000000000000000000..c7bcb4b1ee14cd5e25078c2c934529afdd2a7df9
--- /dev/null
+++ b/postcss.config.mjs
@@ -0,0 +1,5 @@
+const config = {
+  plugins: ["@tailwindcss/postcss"],
+};
+
+export default config;
diff --git a/public/file.svg b/public/file.svg
new file mode 100644
index 0000000000000000000000000000000000000000..004145cddf3f9db91b57b9cb596683c8eb420862
--- /dev/null
+++ b/public/file.svg
@@ -0,0 +1 @@
+<svg fill="none" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><path d="M14.5 13.5V5.41a1 1 0 0 0-.3-.7L9.8.29A1 1 0 0 0 9.08 0H1.5v13.5A2.5 2.5 0 0 0 4 16h8a2.5 2.5 0 0 0 2.5-2.5m-1.5 0v-7H8v-5H3v12a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1M9.5 5V2.12L12.38 5zM5.13 5h-.62v1.25h2.12V5zm-.62 3h7.12v1.25H4.5zm.62 3h-.62v1.25h7.12V11z" clip-rule="evenodd" fill="#666" fill-rule="evenodd"/></svg>
\ No newline at end of file
diff --git a/public/globe.svg b/public/globe.svg
new file mode 100644
index 0000000000000000000000000000000000000000..567f17b0d7c7fb662c16d4357dd74830caf2dccb
--- /dev/null
+++ b/public/globe.svg
@@ -0,0 +1 @@
+<svg fill="none" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><g clip-path="url(#a)"><path fill-rule="evenodd" clip-rule="evenodd" d="M10.27 14.1a6.5 6.5 0 0 0 3.67-3.45q-1.24.21-2.7.34-.31 1.83-.97 3.1M8 16A8 8 0 1 0 8 0a8 8 0 0 0 0 16m.48-1.52a7 7 0 0 1-.96 0H7.5a4 4 0 0 1-.84-1.32q-.38-.89-.63-2.08a40 40 0 0 0 3.92 0q-.25 1.2-.63 2.08a4 4 0 0 1-.84 1.31zm2.94-4.76q1.66-.15 2.95-.43a7 7 0 0 0 0-2.58q-1.3-.27-2.95-.43a18 18 0 0 1 0 3.44m-1.27-3.54a17 17 0 0 1 0 3.64 39 39 0 0 1-4.3 0 17 17 0 0 1 0-3.64 39 39 0 0 1 4.3 0m1.1-1.17q1.45.13 2.69.34a6.5 6.5 0 0 0-3.67-3.44q.65 1.26.98 3.1M8.48 1.5l.01.02q.41.37.84 1.31.38.89.63 2.08a40 40 0 0 0-3.92 0q.25-1.2.63-2.08a4 4 0 0 1 .85-1.32 7 7 0 0 1 .96 0m-2.75.4a6.5 6.5 0 0 0-3.67 3.44 29 29 0 0 1 2.7-.34q.31-1.83.97-3.1M4.58 6.28q-1.66.16-2.95.43a7 7 0 0 0 0 2.58q1.3.27 2.95.43a18 18 0 0 1 0-3.44m.17 4.71q-1.45-.12-2.69-.34a6.5 6.5 0 0 0 3.67 3.44q-.65-1.27-.98-3.1" fill="#666"/></g><defs><clipPath id="a"><path fill="#fff" d="M0 0h16v16H0z"/></clipPath></defs></svg>
\ No newline at end of file
diff --git a/public/next.svg b/public/next.svg
new file mode 100644
index 0000000000000000000000000000000000000000..5174b28c565c285e3e312ec5178be64fbeca8398
--- /dev/null
+++ b/public/next.svg
@@ -0,0 +1 @@
+<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 394 80"><path fill="#000" d="M262 0h68.5v12.7h-27.2v66.6h-13.6V12.7H262V0ZM149 0v12.7H94v20.4h44.3v12.6H94v21h55v12.6H80.5V0h68.7zm34.3 0h-17.8l63.8 79.4h17.9l-32-39.7 32-39.6h-17.9l-23 28.6-23-28.6zm18.3 56.7-9-11-27.1 33.7h17.8l18.3-22.7z"/><path fill="#000" d="M81 79.3 17 0H0v79.3h13.6V17l50.2 62.3H81Zm252.6-.4c-1 0-1.8-.4-2.5-1s-1.1-1.6-1.1-2.6.3-1.8 1-2.5 1.6-1 2.6-1 1.8.3 2.5 1a3.4 3.4 0 0 1 .6 4.3 3.7 3.7 0 0 1-3 1.8zm23.2-33.5h6v23.3c0 2.1-.4 4-1.3 5.5a9.1 9.1 0 0 1-3.8 3.5c-1.6.8-3.5 1.3-5.7 1.3-2 0-3.7-.4-5.3-1s-2.8-1.8-3.7-3.2c-.9-1.3-1.4-3-1.4-5h6c.1.8.3 1.6.7 2.2s1 1.2 1.6 1.5c.7.4 1.5.5 2.4.5 1 0 1.8-.2 2.4-.6a4 4 0 0 0 1.6-1.8c.3-.8.5-1.8.5-3V45.5zm30.9 9.1a4.4 4.4 0 0 0-2-3.3 7.5 7.5 0 0 0-4.3-1.1c-1.3 0-2.4.2-3.3.5-.9.4-1.6 1-2 1.6a3.5 3.5 0 0 0-.3 4c.3.5.7.9 1.3 1.2l1.8 1 2 .5 3.2.8c1.3.3 2.5.7 3.7 1.2a13 13 0 0 1 3.2 1.8 8.1 8.1 0 0 1 3 6.5c0 2-.5 3.7-1.5 5.1a10 10 0 0 1-4.4 3.5c-1.8.8-4.1 1.2-6.8 1.2-2.6 0-4.9-.4-6.8-1.2-2-.8-3.4-2-4.5-3.5a10 10 0 0 1-1.7-5.6h6a5 5 0 0 0 3.5 4.6c1 .4 2.2.6 3.4.6 1.3 0 2.5-.2 3.5-.6 1-.4 1.8-1 2.4-1.7a4 4 0 0 0 .8-2.4c0-.9-.2-1.6-.7-2.2a11 11 0 0 0-2.1-1.4l-3.2-1-3.8-1c-2.8-.7-5-1.7-6.6-3.2a7.2 7.2 0 0 1-2.4-5.7 8 8 0 0 1 1.7-5 10 10 0 0 1 4.3-3.5c2-.8 4-1.2 6.4-1.2 2.3 0 4.4.4 6.2 1.2 1.8.8 3.2 2 4.3 3.4 1 1.4 1.5 3 1.5 5h-5.8z"/></svg>
\ No newline at end of file
diff --git a/public/vercel.svg b/public/vercel.svg
new file mode 100644
index 0000000000000000000000000000000000000000..77053960334e2e34dc584dea8019925c3b4ccca9
--- /dev/null
+++ b/public/vercel.svg
@@ -0,0 +1 @@
+<svg fill="none" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1155 1000"><path d="m577.3 0 577.4 1000H0z" fill="#fff"/></svg>
\ No newline at end of file
diff --git a/public/window.svg b/public/window.svg
new file mode 100644
index 0000000000000000000000000000000000000000..b2b2a44f6ebc70c450043c05a002e7a93ba5d651
--- /dev/null
+++ b/public/window.svg
@@ -0,0 +1 @@
+<svg fill="none" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path fill-rule="evenodd" clip-rule="evenodd" d="M1.5 2.5h13v10a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1zM0 1h16v11.5a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 0 12.5zm3.75 4.5a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5M7 4.75a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0m1.75.75a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5" fill="#666"/></svg>
\ No newline at end of file
diff --git a/tsconfig.json b/tsconfig.json
new file mode 100644
index 0000000000000000000000000000000000000000..d8b93235f205efbea6e8fceb1c9ddb57ddddf28d
--- /dev/null
+++ b/tsconfig.json
@@ -0,0 +1,27 @@
+{
+  "compilerOptions": {
+    "target": "ES2017",
+    "lib": ["dom", "dom.iterable", "esnext"],
+    "allowJs": true,
+    "skipLibCheck": true,
+    "strict": true,
+    "noEmit": true,
+    "esModuleInterop": true,
+    "module": "esnext",
+    "moduleResolution": "bundler",
+    "resolveJsonModule": true,
+    "isolatedModules": true,
+    "jsx": "preserve",
+    "incremental": true,
+    "plugins": [
+      {
+        "name": "next"
+      }
+    ],
+    "paths": {
+      "@/*": ["./*"]
+    }
+  },
+  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
+  "exclude": ["node_modules"]
+}
diff --git a/types/analysis.ts b/types/analysis.ts
new file mode 100644
index 0000000000000000000000000000000000000000..931c9aed8c92d422b43bbdd084c0108ba07a4c4a
--- /dev/null
+++ b/types/analysis.ts
@@ -0,0 +1,11 @@
+export type Rating = {
+  axis: string;
+  score: string;
+  explanation: string;
+};
+
+export type AnalysisResult = {
+  summary: string;
+  ratings: Rating[];
+  suggestions: string[];
+};
 
EOF
)
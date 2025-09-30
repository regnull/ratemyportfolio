import { NextResponse } from "next/server";
import OpenAI from "openai";

import { MAX_FILE_CHARACTERS, buildPrompt } from "@/lib/prompt";
import type { RiskLevel } from "@/components/RiskToleranceSelector";
import type { AnalysisResult } from "@/types/analysis";

const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;

function truncateContent(content: string) {
  if (content.length <= MAX_FILE_CHARACTERS) {
    return content;
  }
  return `${content.slice(0, MAX_FILE_CHARACTERS)}...`;
}

async function readFileContent(file: File) {
  const text = await file.text();
  return truncateContent(text.replace(/\u0000/g, " "));
}

function buildFallbackResponse(): AnalysisResult {
  return {
    summary:
      "We created a mock analysis because the OpenAI API key is not configured. Add your key to receive an AI generated review.",
    ratings: [
      {
        axis: "Risk Alignment",
        score: "Review Needed",
        explanation:
          "The current mix of holdings may not fully match the stated objectives. Review allocations to ensure they reflect your tolerance.",
      },
      {
        axis: "Growth Potential",
        score: "Moderate",
        explanation:
          "Several positions can compound over time, but diversifying across asset classes could improve resilience and upside.",
      },
      {
        axis: "Diversification",
        score: "Needs Attention",
        explanation:
          "Consider broadening exposure to avoid concentration risk and smooth performance across market cycles.",
      },
      {
        axis: "Liquidity",
        score: "Adequate",
        explanation:
          "Cash and short-term assets seem available for near-term needs, but revisit this as your objectives evolve.",
      },
    ],
    suggestions: [
      "Clarify your primary objective (income, growth, preservation) and align position sizes accordingly.",
      "Stress-test the portfolio against different market scenarios to understand drawdown expectations.",
      "Introduce complementary asset classes or funds to reduce concentration in any single sector or theme.",
      "Create an ongoing rebalancing schedule so allocations stay within your target ranges.",
    ],
  };
}

export async function POST(request: Request) {
  const formData = await request.formData();
  const riskTolerance = formData.get("riskTolerance");
  const files = formData.getAll("files") as File[];

  if (!riskTolerance || typeof riskTolerance !== "string") {
    return NextResponse.json(
      { error: "Risk tolerance is required." },
      { status: 400 },
    );
  }

  const normalizedRisk = riskTolerance as RiskLevel;
  const supportedRiskLevels = new Set<RiskLevel>([
    "conservative",
    "moderate",
    "aggressive",
    "extremely-aggressive",
  ]);

  if (!supportedRiskLevels.has(normalizedRisk)) {
    return NextResponse.json(
      { error: "Unsupported risk tolerance option." },
      { status: 400 },
    );
  }

  if (files.length === 0) {
    return NextResponse.json(
      { error: "Please upload at least one document describing the portfolio." },
      { status: 400 },
    );
  }

  for (const file of files) {
    if (file.size > MAX_FILE_SIZE_BYTES) {
      return NextResponse.json(
        { error: `${file.name} exceeds the 5MB size limit.` },
        { status: 400 },
      );
    }
  }

  const documents = await Promise.all(
    files.map(async (file) => ({
      name: file.name,
      content: await readFileContent(file),
    })),
  );

  const prompt = buildPrompt({ riskTolerance: normalizedRisk, documents });

  if (!process.env.OPENAI_API_KEY) {
    return NextResponse.json(buildFallbackResponse());
  }

  try {
    const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

    const response = await client.responses.create({
      model: "gpt-4o-mini",
      input: prompt,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "portfolio_review",
          schema: {
            type: "object",
            required: ["summary", "ratings", "suggestions"],
            properties: {
              summary: { type: "string" },
              ratings: {
                type: "array",
                minItems: 3,
                items: {
                  type: "object",
                  required: ["axis", "score", "explanation"],
                  properties: {
                    axis: { type: "string" },
                    score: { type: "string" },
                    explanation: { type: "string" },
                  },
                },
              },
              suggestions: {
                type: "array",
                minItems: 3,
                items: { type: "string" },
              },
            },
          },
        },
      },
    });

    const outputText = response.output_text;
    try {
      const payload = JSON.parse(outputText) as AnalysisResult;
      return NextResponse.json(payload);
    } catch (parseError) {
      console.error("Failed to parse OpenAI response", parseError, outputText);
      return NextResponse.json(buildFallbackResponse());
    }
  } catch (error) {
    console.error("Portfolio analysis failed", error);
    return NextResponse.json(
      {
        error:
          "We couldn't analyze the portfolio right now. Please retry in a moment or verify the server configuration.",
      },
      { status: 500 },
    );
  }
}

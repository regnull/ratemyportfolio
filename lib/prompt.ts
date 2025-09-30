import type { RiskLevel } from "@/components/RiskToleranceSelector";

export const MAX_FILE_CHARACTERS = 2000;

const RISK_DESCRIPTIONS: Record<RiskLevel, string> = {
  conservative:
    "The client prefers stability and capital preservation. They accept lower returns in exchange for lower volatility.",
  moderate:
    "The client is comfortable with a balance of growth and protection. They can tolerate moderate fluctuations to pursue growth.",
  aggressive:
    "The client is willing to embrace meaningful volatility in pursuit of higher long-term appreciation.",
  "extremely-aggressive":
    "The client is focused on maximum growth and is comfortable with substantial drawdowns and concentrated exposures.",
};

export function buildPrompt({
  riskTolerance,
  documents,
}: {
  riskTolerance: RiskLevel;
  documents: Array<{ name: string; content: string }>;
}) {
  const documentSummaries = documents
    .map((doc, index) => {
      const trimmed = doc.content.trim().replace(/\s+/g, " ");
      return `Document ${index + 1} (${doc.name}): ${trimmed}`;
    })
    .join("\n\n");

  return `You are a fiduciary financial advisor evaluating a client's investment portfolio.
The client identifies their risk tolerance as "${riskTolerance}" which means: ${RISK_DESCRIPTIONS[riskTolerance]}.

You are provided with notes from the client about their holdings, allocation, or objectives:
${documentSummaries || "No documents were supplied. Ask for more detail."}

Respond with a JSON object that follows this schema:
{
  "summary": string // A concise assessment (4-5 sentences) of how well the portfolio aligns with the stated risk tolerance.
  "ratings": Array<{
    "axis": string // e.g. "Risk Alignment", "Growth Potential", "Diversification", "Liquidity"
    "score": string // A short label like "Strong", "Moderate", or "Needs Attention"
    "explanation": string // 2-3 sentences explaining the score with references to the provided holdings
  }>
  "suggestions": string[] // 3-5 actionable steps that the client can take to close gaps or improve the portfolio alignment
}

Always recommend improvements or adjustments, even if the portfolio is generally aligned. Avoid markdown in the JSON.`;
}

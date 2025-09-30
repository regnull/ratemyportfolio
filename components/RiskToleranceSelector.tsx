"use client";

const RISK_LEVELS = [
  { id: "conservative", label: "Conservative", description: "Capital preservation with steady returns." },
  { id: "moderate", label: "Moderate", description: "Balanced growth with measured risk." },
  { id: "aggressive", label: "Aggressive", description: "Higher growth potential with volatility." },
  { id: "extremely-aggressive", label: "Extremely Aggressive", description: "Maximum growth with significant risk." },
] as const;

type RiskToleranceSelectorProps = {
  value: (typeof RISK_LEVELS)[number]["id"];
  onChange: (value: (typeof RISK_LEVELS)[number]["id"]) => void;
};

export function RiskToleranceSelector({ value, onChange }: RiskToleranceSelectorProps) {
  return (
    <div className="space-y-4">
      <label className="block text-sm font-medium text-white/80">Risk tolerance</label>
      <div className="grid gap-3 sm:grid-cols-2">
        {RISK_LEVELS.map((risk) => {
          const isActive = value === risk.id;
          return (
            <button
              key={risk.id}
              type="button"
              onClick={() => onChange(risk.id)}
              className={`rounded-2xl border px-5 py-4 text-left transition ${
                isActive
                  ? "border-white/80 bg-white/15 shadow-lg shadow-emerald-500/20"
                  : "border-white/10 bg-white/5 hover:border-white/30 hover:bg-white/10"
              }`}
            >
              <span className="block text-base font-semibold text-white">
                {risk.label}
              </span>
              <span className="mt-2 block text-sm text-white/70">{risk.description}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export type RiskLevel = (typeof RISK_LEVELS)[number]["id"];
export const riskLevels = RISK_LEVELS;

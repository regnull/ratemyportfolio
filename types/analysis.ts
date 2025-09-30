export type Rating = {
  axis: string;
  score: string;
  explanation: string;
};

export type AnalysisResult = {
  summary: string;
  ratings: Rating[];
  suggestions: string[];
};

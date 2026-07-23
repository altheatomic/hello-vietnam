export type FoodCatalogEntry = {
  id: string;
  name: string;
  aliases: string[];
  imagePath?: string | null;
};

export type FoodDatabaseMatch = {
  status: "matched";
  category: "food";
  id: string;
  name: string;
  match_score: number;
  image_path: string | null;
};

type FoodMatchInput = {
  detectedName: string;
  alternativeNames: string | string[];
  recognitionConfidence: number;
  catalog: FoodCatalogEntry[];
};

type RankedFood = {
  entry: FoodCatalogEntry;
  score: number;
  exact: boolean;
};

const MIN_RECOGNITION_CONFIDENCE = 0.65;
const MIN_MATCH_SCORE = 0.82;
const AMBIGUITY_MARGIN = 0.06;

export function normalizeFoodName(value: string): string {
  return value
    .trim()
    .toLocaleLowerCase("vi")
    .replaceAll("đ", "d")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

export function findBestFoodMatch(
  input: FoodMatchInput,
): FoodDatabaseMatch | null {
  if (
    input.recognitionConfidence < MIN_RECOGNITION_CONFIDENCE ||
    input.catalog.length === 0
  ) {
    return null;
  }

  const recognizedNames = [
    input.detectedName,
    ...parseAlternativeNames(input.alternativeNames),
  ]
    .map(normalizeFoodName)
    .filter((name) => name.length >= 3);

  if (recognizedNames.length === 0) {
    return null;
  }

  const ranked = input.catalog
    .map((entry): RankedFood => {
      const catalogNames = [entry.name, ...entry.aliases]
        .map(normalizeFoodName)
        .filter(Boolean);
      let score = 0;
      let exact = false;

      for (const recognizedName of recognizedNames) {
        for (const catalogName of catalogNames) {
          const candidateExact = recognizedName === catalogName;
          const candidateScore = scoreNames(recognizedName, catalogName);
          if (candidateScore > score) {
            score = candidateScore;
            exact = candidateExact;
          } else if (candidateScore === score && candidateExact) {
            exact = true;
          }
        }
      }

      return { entry, score, exact };
    })
    .filter((candidate) => candidate.score >= MIN_MATCH_SCORE)
    .sort((left, right) => right.score - left.score);

  const best = ranked[0];
  if (!best) {
    return null;
  }

  const second = ranked[1];
  if (
    !best.exact &&
    second &&
    best.score - second.score < AMBIGUITY_MARGIN
  ) {
    return null;
  }

  return {
    status: "matched",
    category: "food",
    id: best.entry.id,
    name: best.entry.name,
    match_score: roundScore(best.score),
    image_path: best.entry.imagePath ?? null,
  };
}

function parseAlternativeNames(value: string | string[]): string[] {
  if (Array.isArray(value)) {
    return value;
  }

  return value
    .split(/[,;/|]+/)
    .map((name) => name.trim())
    .filter(Boolean);
}

function scoreNames(left: string, right: string): number {
  if (!left || !right) {
    return 0;
  }
  if (left === right) {
    return 1;
  }

  const leftTokens = left.split(" ");
  const rightTokens = right.split(" ");
  const shorterTokenCount = Math.min(leftTokens.length, rightTokens.length);
  if (
    shorterTokenCount >= 2 &&
    (left.includes(right) || right.includes(left))
  ) {
    return 0.88;
  }

  const tokenScore = jaccardSimilarity(leftTokens, rightTokens);
  const characterScore = diceCoefficient(left, right);
  return Math.max(tokenScore, characterScore * 0.92);
}

function jaccardSimilarity(left: string[], right: string[]): number {
  const leftSet = new Set(left);
  const rightSet = new Set(right);
  const intersection = [...leftSet].filter((token) => rightSet.has(token));
  const union = new Set([...leftSet, ...rightSet]);
  return union.size === 0 ? 0 : intersection.length / union.size;
}

function diceCoefficient(left: string, right: string): number {
  if (left.length < 2 || right.length < 2) {
    return 0;
  }

  const leftBigrams = bigramCounts(left);
  const rightBigrams = bigramCounts(right);
  let overlap = 0;
  for (const [bigram, count] of leftBigrams) {
    overlap += Math.min(count, rightBigrams.get(bigram) ?? 0);
  }

  const leftCount = [...leftBigrams.values()].reduce(
    (total, count) => total + count,
    0,
  );
  const rightCount = [...rightBigrams.values()].reduce(
    (total, count) => total + count,
    0,
  );
  return (2 * overlap) / (leftCount + rightCount);
}

function bigramCounts(value: string): Map<string, number> {
  const counts = new Map<string, number>();
  for (let index = 0; index < value.length - 1; index += 1) {
    const bigram = value.slice(index, index + 2);
    counts.set(bigram, (counts.get(bigram) ?? 0) + 1);
  }
  return counts;
}

function roundScore(value: number): number {
  return Math.round(value * 1000) / 1000;
}

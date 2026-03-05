import * as fs from "fs";
import * as path from "path";

const CHECKPOINT_FILE = path.resolve(__dirname, "../data/checkpoints.json");

export interface Checkpoints {
  sepolia: number;
  hoodi: number;
}

export function loadCheckpoints(): Checkpoints {
  try {
    if (!fs.existsSync(CHECKPOINT_FILE)) {
      return { sepolia: 0, hoodi: 0 };
    }
    const data = fs.readFileSync(CHECKPOINT_FILE, "utf-8");
    return JSON.parse(data) as Checkpoints;
  } catch {
    return { sepolia: 0, hoodi: 0 };
  }
}

export function saveCheckpoints(checkpoints: Checkpoints): void {
  fs.mkdirSync(path.dirname(CHECKPOINT_FILE), { recursive: true });
  fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify(checkpoints, null, 2));
}

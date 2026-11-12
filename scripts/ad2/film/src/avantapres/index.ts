// Point d'entrée séparé (n'a pas besoin du Root principal) : npx remotion render src/avantapres/index.ts AvantApres out.mp4
import { registerRoot } from "remotion";
import { AvantApresRoot } from "./Root";

registerRoot(AvantApresRoot);

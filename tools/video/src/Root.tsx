import React from "react";
import { Composition } from "remotion";
import { Edit4, totalFrames } from "./Edit4";

export const Root: React.FC = () => (
  <Composition id="Edit4" component={Edit4} durationInFrames={totalFrames} fps={30} width={1080} height={1920} />
);

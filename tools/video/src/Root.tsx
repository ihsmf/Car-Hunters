import React from "react";
import { Composition } from "remotion";
import { Edit4, totalFrames } from "./Edit4";
import { Edit5, totalFrames5 } from "./Edit5";
import { Edit6, totalFrames6 } from "./Edit6";

export const Root: React.FC = () => (
  <>
    <Composition id="Edit4" component={Edit4} durationInFrames={totalFrames} fps={30} width={1080} height={1920} />
    <Composition id="Edit5" component={Edit5} durationInFrames={totalFrames5} fps={30} width={1080} height={1920} />
    <Composition id="Edit6" component={Edit6} durationInFrames={totalFrames6} fps={30} width={1080} height={1920} />
  </>
);

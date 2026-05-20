/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** Bridge URL - Base URL of draw-bridge. */
  "bridgeUrl": string,
  /** Draw URL - Base URL of the draw.lab Excalidraw instance. */
  "drawUrl": string
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `present` command */
  export type Present = ExtensionPreferences & {}
  /** Preferences accessible in the `import-ai` command */
  export type ImportAi = ExtensionPreferences & {}
  /** Preferences accessible in the `full-pipeline` command */
  export type FullPipeline = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `present` command */
  export type Present = {}
  /** Arguments passed to the `import-ai` command */
  export type ImportAi = {}
  /** Arguments passed to the `full-pipeline` command */
  export type FullPipeline = {}
}


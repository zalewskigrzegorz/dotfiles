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
  /** Preferences accessible in the `browse` command */
  export type Browse = ExtensionPreferences & {}
  /** Preferences accessible in the `save` command */
  export type Save = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `browse` command */
  export type Browse = {}
  /** Arguments passed to the `save` command */
  export type Save = {}
}


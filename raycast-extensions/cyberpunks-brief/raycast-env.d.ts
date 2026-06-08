/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** Claude Code binary - Path to the `claude` CLI used to run the briefing prompt in headless mode. */
  "claudeBin": string,
  /** Claude model - Model id passed to `claude -p --model`. Sonnet 4.6 is the sweet spot for summarisation. */
  "claudeModel": string,
  /** ElevenLabs API key - Used by the TTS action (currently disabled). Stored locally in Raycast preferences. */
  "elevenlabsApiKey": string,
  /** ElevenLabs voice id - Voice used for TTS (currently disabled). Default = Joniu (Polish radio host). */
  "voiceId": string,
  /** ElevenLabs model id - Model used for TTS (currently disabled). `eleven_v3` supports inline audio tags like [thoughtful]. */
  "voiceModel": string
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `brief` command */
  export type Brief = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `brief` command */
  export type Brief = {}
}


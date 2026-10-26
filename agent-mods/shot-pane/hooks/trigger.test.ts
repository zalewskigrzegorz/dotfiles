import { expect, test } from 'claude-code/testing'

import { TRIGGER } from './register'

test('matches the screenshot words the shell hook matches', () => {
  for (const t of ['zobacz screen', 'na ss widać', 'zrzuty ekranu', 'screenshot pls', 'screeny', 'scr', 'zobacz scr'])
    expect(TRIGGER.test(t)).toBe(true)
  for (const t of ['class', 'fullscreen tui'])
    expect(TRIGGER.test(t)).toBe(false)
})

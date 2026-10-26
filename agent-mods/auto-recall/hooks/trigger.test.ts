import { expect, test } from 'claude-code/testing'

import { TRIGGER } from './register'

test('fires on references to earlier work', () => {
  for (const t of ['wróćmy do pr-band', 'kontynuuj', 'co ustaliliśmy z guardem?', 'mówiłeś, że to działa', 'resume', 'wracamy'])
    expect(TRIGGER.test(t)).toBe(true)
})

test('stays quiet on ordinary prompts', () => {
  for (const t of ['zrób commit', 'dodaj test', 'continue the loop in foo.ts later', 'ok zaladujesz'])
    expect(TRIGGER.test(t)).toBe(false)
})

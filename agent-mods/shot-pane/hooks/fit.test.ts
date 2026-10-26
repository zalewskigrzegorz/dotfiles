import { expect, test } from 'claude-code/testing'

import { fit, pngSize } from './register'

test('reads width and height from the PNG header', () => {
  const onePx = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
  expect(pngSize(onePx)).toEqual({ width: 1, height: 1 })
  expect(pngSize('aGVsbG8gd29ybGQ=')).toBeUndefined()
})

test('keeps the aspect ratio inside the box', () => {
  // 1600x1039 at 2:1 cells: 100 columns → 32 rows.
  expect(fit({ width: 1600, height: 1039 }, 100, 40)).toEqual({ columns: 100, rows: 32 })
  // Too tall for the rows: narrow the columns instead of stretching.
  expect(fit({ width: 1600, height: 1039 }, 100, 20)).toEqual({ columns: 62, rows: 20 })
})

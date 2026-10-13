# Write

Write new tests that protect meaningful behavior in the selected scope. Work through one test at a time: predict its result and execution path, write it, inspect execution evidence, and resolve discrepancies before continuing. Passing assertions and aggregate coverage alone do not establish that a new test protects its intended behavior.

## Interpret the request

Use the user's explicit target. Without one, use the feature, files, or changes already identified in the current task. If neither supplies a target, ask what to test before editing. An omitted target does not mean repository-wide discovery.

Scope may name source files, test files, directories, or a Git change set:

- For a source scope, include the source files and the tests that cover or should cover them.
- For a test scope, include the named tests and the source behavior they exercise.
- For a change set, resolve the affected paths from repository metadata and report any comparison-base assumption. Apply the source-scope and test-scope rules to those paths.

Keep discovery, edits, and verification tied to that relationship. Follow an explicit coverage target when supplied; this workflow has no default coverage percentage. Add distinct behavioral protection even when aggregate coverage does not increase, and leave adequately protected cases alone.

## Establish the baseline and scenarios

Read relevant requirements, product documentation, source logic, and neighboring tests. Use explicit requirements and documented contracts when available. Otherwise infer intended behavior from consistent repository evidence, such as public interfaces, call sites, invariants, tests, and implementation. Neither an existing test nor the implementation is the source of truth by itself.

If the evidence conflicts or leaves a material externally observable behavior ambiguous, defer that scenario without changing the ambiguous behavior. Record the conflicting evidence and decision needed, then continue with independent scenarios.

Record baseline failures, related tests, and source coverage for the selected scope. Keep clear which tests contributed to that coverage. Missing coverage is an evidence gap to investigate, not proof that the file has no testable behavior.

Build a bounded scenario list before editing:

1. Identify the meaningful normal outcomes, boundaries, rejection paths, and state transitions in scope.
2. Identify which scenarios existing tests already protect and which need new tests.
3. Review fully covered behavior for weak assertions as well as uncovered or partially covered regions.
4. Record ambiguous scenarios separately with their concrete blockers.

## Write and verify one test

Before editing, give a brief prediction naming the behavior, fixture, expected observable result, and a plausible defect the assertions should catch. Identify the relevant source regions by path and line or expression, including regions expected to execute and remain untouched. State the expected pass or fail result separately. A test of correct behavior may pass immediately; a known defect should fail for the predicted behavioral reason.

Write one test using the repository's conventions and an appropriate interface to the real behavior. Reuse existing test structure when it remains clear; create a new file when no suitable home exists. Process parameterized cases individually until each case's execution and assertions are understood. Preserve independently identifiable names when combining verified cases.

You can use `analyze --target=test` to obtain the selected test's result and coverage across all files it covers.

After each edit, verify the test's result and inspect its coverage for the predicted regions, including paths expected to remain untouched. Keep this evidence separate from aggregate coverage: existing tests can conceal a new test that misses its intended path. An unresolved test identity or unavailable per-test coverage leaves verification incomplete. Reconcile the evidence and apply the quality gate before another test or corrective edit.

## Reconcile predictions and results

Compare the observed result, executed regions, untouched regions, and uncovered expressions with the prediction. State the outcome briefly and link the relevant evidence. Preserve the original prediction and explain revisions before the next edit or run. A passing test that misses its intended path remains incomplete. Partial coverage can be correct when the test intentionally exercises one outcome; explain that relationship rather than treating every partial line as a defect.

Investigate unexplained runtime values or execution order. Distinguish code reached by imports, setup, or helpers from code reached by the scenario's action.

Correct mistaken fixtures or assertions against the established contract. Prefer test-only changes. Change source code only when a regression test demonstrates a defect against requirements or strong repository evidence. Confirm that the failure is behavioral, make the smallest justified fix, retain the regression test, and repeat the affected verification. Report the evidence supporting the source change; ambiguous behavior remains deferred.

## Test-quality review

Before accepting a test and moving to the next scenario, confirm all of the following:

- its name, fixture, action, executed path, and assertions describe the same behavior;
- its assertions protect a meaningful public result, error, or state change, with expectations derived from the contract or independent reasoning rather than observed output or a copy of the implementation;
- a named plausible defect would violate those assertions, and any state-transition fixture makes the asserted transition meaningful;
- it exercises the intended implementation, with mocks isolating dependencies rather than replacing the behavior under test;
- asynchronous outcomes are awaited and asserted, and shared state, time, randomness, and cleanup are controlled where they affect correctness;
- it adds distinct behavioral protection without depending on another test's execution order;
- it passes, its per-test coverage has been inspected, and every relevant execution discrepancy has an explanation supported by evidence.

Use manual mutation testing as an optional check when assertion review and execution evidence leave doubt about a valuable test's sensitivity. Start from a green baseline, apply one small reversible source defect, and verify that the new test fails for the intended reason. Restore the exact pre-mutation source, preserving unrelated changes, and confirm green results again. If a meaningful mutation survives, strengthen the test and repeat the check. Equivalent or invalid mutations do not establish a weak test. Keep only one mutation active and restore it before further work. Report empirical checks separately from reasoned defect-detection claims. Do not install mutation tooling for this workflow.

A failed quality criterion blocks acceptance. Resolve it or explicitly defer the test with a concrete blocker before proceeding to an independent scenario. Skipping or focusing a test does not satisfy verification. When execution evidence is unavailable, report verification as blocked; static review cannot replace the runtime check.

## Completion

Account for every scenario in the bounded list as protected by existing tests, protected by verified new tests, or deferred with a concrete reason. Review current coverage across the selected scope for missed behavior, including uncovered lines and partially covered expressions. Add tests for meaningful omissions and explain gaps with no useful observable test. Avoid duplicate cases and hollow assertions added only to move a percentage.

Obtain final results for all new tests and related regressions. Expand verification to affected callers when a source fix warrants it, keeping coverage comparisons explicit about which tests contributed. Run additional checks required by the user or applicable repository instructions. Resolve introduced failures and distinguish pre-existing failures from regressions. Deferred scenarios or blocked checks mean the requested scope is only partially complete.

Finish with a compact summary of added protection, prediction outcomes and evidence, source fixes and their justification, verification scope and results, and unresolved gaps. Show predictions and observations as brief updates during the work. Create a persistent narrative report only when requested.

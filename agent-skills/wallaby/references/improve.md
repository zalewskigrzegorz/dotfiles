# Improve

Use Wallaby evidence to find source files whose tests need work. Raise useful coverage and strengthen the tests around the selected logic. The requested scope and signals determine where to investigate; observable behavior decides what to test. Here, a source file is a non-test file whose behavior tests exercise or should exercise.

## Interpret the request

Treat the user's scope and signal instructions as independent filters.

Scope may name a source file, source directory, test file, test directory, or another explicit repository subset:

- For a source scope, consider source files inside it and the tests that cover or should cover them.
- For a test scope, consider the named tests and the source files they exercise. Keep edits within that relationship unless a shared dependency must change for correctness.
- Without an explicit scope, use the whole repository. Enumerate signal-matching files across the repository before selecting the first target.

In a Git repository, scope may also describe a change set:

- For a pull request or branch diff, use the files changed between its base and head revisions.
- For a commit, a set of commits, or a commit range, use the union of files changed by those commits.
- For a period such as the last three days, use the files changed by commits in that interval.

Resolve the change set from available Git and pull-request metadata. For a pull request, use its actual base and head when available; otherwise infer the comparison base from branch and upstream metadata and report the assumption. Apply the source-scope and test-scope rules above to the resulting paths: include related tests for changed source files and the exercised source files for changed tests. Exclude unrelated working-tree changes unless the user includes them in the scope.

Use signals stated by the user. They may filter or rank by coverage, cyclomatic complexity, CRAP, failures, or a combination. Preserve comparison operators and combinations from the request. Apply the default coverage cutoff of 95% or less only when the request has neither an explicit scope nor an explicit signal. With an explicit scope and no signal, consider every meaningful source file in that scope regardless of coverage; use CRAP and other evidence to prioritize the review. Treat relevant source files missing from Wallaby's coverage report as uncovered candidates rather than silently excluding them; omit generated, vendored, declaration-only, and configuration files that are not meaningful test targets.

A failing test is also a signal. Include failures inside the requested scope and failures that prevent trustworthy analysis or verification of that scope. With repository-wide scope, include every current failure. Diagnose the promised behavior before deciding whether the test or source code is wrong. A product defect may require a source change, but do not alter behavior merely to make coverage easier to reach.

Test duration is an optional signal for unit tests. Compare timings with nearby tests and investigate clear outliers when the likely payoff justifies it. Remove real timers, repeated setup, oversized fixtures, or unnecessary work when the contract stays intact. Split a test when that produces clearer independent behaviors; splitting alone is not a speed improvement. Slow tests do not block completion unless the user asks for a timing goal.

Only enter signal-free mode when the user explicitly says not to use coverage, cyclomatic complexity, or CRAP as discovery signals. In that mode, skip the signal-based candidate workflow and use the test-quality discovery workflow below across the requested scope. This exclusion applies only while discovering and selecting candidates. Do not infer signal-free mode from an omitted threshold or a request to improve test quality.

## Establish the candidate set

Use this section in signal-driven mode. In signal-free mode, continue at Test-quality discovery and review.

Start or query Wallaby in a mode that can produce truthful evidence for the requested scope. Repository-wide and source-directory discovery normally require project mode. A test-file scope may use an exclusive session containing that test file. Do not interpret coverage from an unrelated or incomplete exclusive session as coverage for the requested scope.

Read the `run` report and its linked coverage and all-tests reports as needed. Build the candidate set before editing:

1. Apply the requested scope to source files and test failures.
2. Apply the explicit signal expression, if any. With no explicit signal or scope, apply the default coverage cutoff of 95% or less. With an explicit scope and no signal, keep every meaningful in-scope source file.
3. Account for meaningful in-scope source files absent from the coverage report.
4. Rank candidates by the user's stated priority. Otherwise prefer higher CRAP, failures, lower coverage, important behavior, and clear test-quality defects. Use slow unit tests only as a secondary ranking signal.

Record the baseline coverage, complexity, CRAP, covering tests, failures, and useful timing data available for each candidate. A top-five ranking in a Wallaby report is only a summary; inspect the complete in-scope candidate set.

## Test-quality discovery and review

Find important behavior that the current tests do not protect.

Look for and, when accessible, read the Software Requirements Specification (SRS) and other product documentation relevant to the scope and each candidate. This may include product specifications, API contracts, acceptance criteria, architecture decisions, and user-facing documentation. Missing or inaccessible documentation does not block the task. Use explicit user requirements and authoritative product documentation when available. Otherwise infer the intended behavior from the strongest available repository evidence, such as public interfaces, call sites, invariants, existing tests, and source code. No existing test or implementation is the source of truth by itself.

Before changing source code instead of a test, identify the strongest available basis for the change. Prefer an explicit requirement or documented contract when one is accessible; otherwise use consistent repository evidence. If the evidence conflicts or leaves a material externally observable behavior ambiguous, defer the affected test or source file without changing the ambiguous behavior. Record the file, conflicting evidence, and decision needed in the final report so the user can resolve it, then continue with the other candidates. Keep a regression test with every source change and report the requirement, document, or repository evidence that justified it. State when no relevant documentation was available.

In signal-driven mode, apply this review to every selected source file and its related tests. Scope and any explicit signals choose candidates; coverage alone does not define the assertions or the completion criterion. A prominent coverage or change-risk result is one candidate, not the scope.

In signal-free mode, inspect every relevant source and test file within the requested scope without using coverage, cyclomatic complexity, or CRAP to select or rank candidates. Consider every problem category below from the source and tests, then compare plausible candidates from distinct categories before selecting targets. After discovery, use all Wallaby runtime evidence, including coverage, cyclomatic complexity, and CRAP, to confirm or reject candidates, understand their tests, and choose assertions that protect observable behavior. Address the high-confidence candidates that remain. Completing one improvement does not complete a repository-wide request while other distinct candidates are still supported by the code and tests.

Problems to look for:

- Critical expression-level coverage gaps. A line may execute while a meaningful outcome of a compound condition or guard remains untested. Inspect both allowed and rejected outcomes, especially when a guard protects financial or other high-impact behavior.
- Covered transformations with weak behavioral oracles. A test may execute important behavior while asserting only a broad invariant, linkage, shape, or other property that would also hold for a materially wrong result. Compare the result promised by the implementation with the concrete behavior its tests actually assert.
- Circular test oracles. Derive expectations independently of the code under test. Check whether mocks implement the asserted behavior or fixtures supply effects that production code should create.
- Vacuous absence assertions. A negative assertion may pass because the output is empty, the excluded input is missing, or the operation never runs.
  - For every selected source file, review absence-based assertions in its related tests within the requested scope, including unchanged tests. Look for negative containment or matching such as `.not.toContain` and `.not.toMatch`, `includes(...) === false`, missing-artifact checks, and equivalent assertions.
  - Judge the fixture, operation, and assertions together. Ask whether the test would still pass if the output were empty, the operation did nothing, or the supposedly excluded data was never supplied. Strengthen tests that permit those unintended outcomes; keep useful negative assertions when the test already rules them out.
  - For filtering or suppression, supply retained and excluded data and assert both outcomes. When all data should be excluded, supply excluded data and assert the expected empty result or explanatory output. Use a companion case that retains data when needed to distinguish filtering from unconditional emptiness.
  - For truncation, assert the complete expected visible sequence. When a linked artifact promises the full result, read it and assert the complete expected sequence there too. Checking only endpoints and one excluded entry misses dropped middle entries.
  - For omitted optional data, assert the surrounding result that must remain. Distinguish absent input from supplied-but-suppressed input in the fixture.
  - For artifact absence, exercise the writer responsible for that artifact and verify expected sibling artifacts or directory contents. A filesystem absence check proves nothing when a stub bypasses writing. At a mocked boundary, assert the expected calls and omissions there instead; use an enabled companion case when no writes are expected.
  - For preservation after updates, capture the original artifact, perform an update with different data, then reread and compare the original artifact. An earlier captured string cannot detect later corruption.
  - Match the output's actual structure and wording, including singular and plural forms. Use section boundaries or anchored lines when substrings would confuse headings or entries.
  - Ensure loops over extracted results execute when results are expected. Establish that both entries exist before comparing their positions.
  - Prefer exact assertions on bounded results or relevant sections. When extracting entries for comparison, include unexpected entries of the same kind so the extraction cannot hide a defect. Choose assertions that detect plausible wrong results without coupling the test to unrelated output formatting.

- Vacuous state-transition assertions. A state-changing operation may run while the fixture already satisfies the expected postcondition. Compare the state before the operation, its input, and the asserted result to make sure the test proves a meaningful transition.
- Uncovered rejection paths and failure atomicity. Happy-path tests may cover valid inputs while a meaningful rejection branch remains untested. Check that invalid inputs produce the promised error or rejected result and that stateful operations preserve existing state when they fail. Confirm the intended guard executes; an earlier rejection can make the test pass for the wrong reason.
- Unchecked boundary semantics. Interior valid inputs and out-of-range rejection tests may exercise the surrounding logic while leaving the exact limit unprotected. For important numeric, time, size, quota, or pagination comparisons, determine whether each boundary is inclusive or exclusive and assert the complete observable result exactly at that boundary.
- State and identity isolation. A cache or other shared state may work for one identity while using an incomplete partitioning key. Exercise distinct owners that share another attribute and assert that their results, state, and reuse behavior remain isolated.
- Asynchronous outcome masking. A test may await an operation, catch or discard its rejection, and then assert unrelated state. Assert the public promise outcome and any required side effects after the operation settles.
- Scenario mismatch. A test's name, fixture, call arguments, executed behavior, and assertion may describe different cases. Align them, and preserve each distinct behavior by splitting the test when one correction would otherwise replace another useful scenario.
- Missing cross-module contracts. Well-tested units do not prove that adapters and orchestrators preserve invariants across their boundary. Find important module seams with no direct test and assert their combined externally visible result.
- Incidental test latency. A real timer, retry, oversized fixture, or repeated setup may slow a test without affecting its claimed behavior. Remove unnecessary work only after identifying the contract, then confirm that the faster test remains deterministic and protects the same result.

Read the source logic and its related tests, identify the missing observable behavior, and add a test whose assertions protect that behavior directly. Prefer test-only changes. Change source code only when a failing or new regression test demonstrates a product defect against the intended behavior established from the best available evidence. Keep the full test suite green.

## Batch discovery and focused improvements

Use `analyze --target=files` to collect coverage gaps for several candidates in one `coverage-gaps.md` report. For repository-wide work without a narrow file list, the target with no paths is a useful first pass because it automatically analyzes up to 20 source files with the lowest current coverage. It is only a shortlist: it does not replace the complete candidate set from `coverage.md`, and it may omit higher-coverage files with high CRAP, failures, critical behavior, or weak tests.

When the candidate set is already known, pass it as an explicit `paths` array. After the automatic pass, analyze remaining candidates in explicit batches, ordered by priority.

Read `coverage-gaps.md`, check `Files Analysis Errors`, and confirm that every requested file has a section headed by its path, such as `## src/accounts.ts`. For each selected source file, review every fully uncovered line and partially covered expression listed in its section. Read the corresponding source ranges and related tests before choosing an improvement. Follow the `Covering Tests` link when test identities are needed. Open the full `.wcov` artifact only when the consolidated gap entry and source file do not provide enough context.

Classify every uncovered or partially covered region in the selected source file before moving on. Add tests for gaps that expose meaningful public results, errors, state changes, or invariants. Leave a gap only when it has no valuable observable test, and record the concrete reason. Also review fully covered logic for weak assertions and the other test-quality problems above. Coverage state alone does not prove that behavior is protected.

Use single-file analysis for a source location or one test's coverage contribution to a specific file; files analysis does not accept locations or test filters. Use `analyze --target=test` to review one test's result and coverage gaps across every source file it covers. Add `--trace` when execution order or cross-file control flow matters. Use `inspect` when static code, coverage, failures, and existing logs do not explain the runtime state. Clear inspections after the investigation.

For each gap, identify the missing observable behavior before writing a test. Apply the test-quality review above to the selected source logic and its tests, including lines that already show full coverage.

Before writing or changing a test, identify its observable contract, a plausible defect it detects, and why existing tests would miss that defect. Assert public results, errors, and durable side effects rather than implementation details. Reuse existing test structure when it remains clear; create a new test file when no suitable home exists. Prefer an existing production entry point over adding exports or hooks solely for testing. Avoid duplicate cases added only to move a percentage. Work on one candidate or a small coherent group at a time so each assertion and coverage change remains attributable.

Before consolidating or deleting tests, identify the surviving protection for each contract. Preserve independent compatibility and architecture checks, including useful static assertions.

Use manual mutation testing as an optional quality check when coverage, execution traces, and assertion review leave doubt about whether a high-value test would detect plausible implementation defects. Start from a green baseline for the affected tests, make one small reversible mutation in the source file, and let Wallaby rerun those tests automatically. Query the live result without forcing a rerun, record whether the tests killed the mutation, then restore the exact pre-mutation source before doing other work. Keep only one mutation active at a time and preserve unrelated user changes. If a meaningful mutation survives, strengthen the test, apply the same mutation again to confirm that the improved test kills it, restore the source, and confirm the affected tests are green. Equivalent or invalid mutations do not require another test. `analyze --target=test --trace` can explain the execution behind a mutation result, but it does not replace this empirical check. Do not install mutation-testing dependencies unless the user requests it.

After each coherent edit or group of edits, query the affected tests without forcing a rerun unless Wallaby evidence is stale. Run one explicit files analysis for all source files changed or investigated in that group, then inspect their updated sections in `coverage-gaps.md`. Confirm that each intended branch or expression now executes and that the assertions protect its behavior. Compare each candidate's baseline and current coverage. If coverage did not increase, explain what protection improved and why the remaining gaps do not warrant tests. An unexplained unchanged result means the candidate is not complete.

Before leaving a candidate, confirm all of the following:

- its affected tests are green;
- the absence-assertion review above is complete, with identified weaknesses strengthened or deferred with a concrete reason;
- every uncovered or partially covered region was reviewed for observable behavior;
- every valuable gap found in that review has a test, or the candidate is explicitly deferred;
- every remaining gap has a concrete reason to stay uncovered;
- baseline and current file coverage were compared;
- when a threshold applies, coverage below it is fully explained by the recorded non-actionable regions.

If a test exposes an implementation defect against the intended behavior, make the smallest source change consistent with the best available evidence and keep the regression test. Verify that it fails for the intended reason before the fix and passes afterward; report when the failing baseline cannot be reproduced.

After a candidate's affected Wallaby tests are green, and before moving to another candidate, run every additional verification command specified by the user or an applicable `AGENTS.md`, such as linting or TypeScript type checking. Apply each command to the changed files or the broader scope required by that command. A failing check means the candidate is not complete. Fix the issue, including reorganizing or splitting test files and choosing suitable names when repository rules require it, then repeat the affected Wallaby tests and all specified checks. Continue until the candidate passes or must be deferred with a concrete reason. This per-candidate gate is optional: when neither the user's request nor `AGENTS.md` specifies additional commands, do not discover or run them on your own.

## Completion

Treat an applicable coverage threshold as a review bar, not an unconditional numeric deliverable. Use the user's coverage threshold when supplied; use 95% only when the request has neither an explicit scope nor an explicit signal. A scoped request without a user-supplied coverage threshold has no coverage cutoff or percentage target. A selected file remains actionable while its `coverage-gaps.md` section, or an individual `.wcov` artifact opened for deeper review, contains valuable, testable gaps. Keep protecting those gaps. A green test or a coverage increase alone is not enough to complete the candidate.

Complete a candidate only after every remaining uncovered or partially covered region has a recorded reason to remain uncovered, such as unreachable or generated code, defensive code without a testable contract, environment-specific behavior, or code with no meaningful observable effect. If a remaining region protects product behavior, add a test. Do not add hollow assertions or duplicate cases merely to reach a number. Continue through the in-scope candidate set while actionable candidates remain, and document why any selected file needs no valuable test change.

Finish with Wallaby verification proportional to the scope. For repository-wide work, obtain project-mode final results. Report baseline and final coverage and CRAP for every investigated or changed source file. When a threshold applies, report whether each file reached it and the concrete reasons for finishing below it. For each file, also report any valuable gap left unresolved and its concrete reason. In signal-free mode, keep coverage and CRAP as post-discovery evidence rather than retroactively using them to define the candidate set. When manual mutation testing was used, report the mutations tried, whether the tests killed them, and how surviving mutations changed the tests. Report the result of every specified per-candidate verification command. Confirm which relevant failures were resolved and identify any deferred failures that remain. One improved file does not complete a repository-wide request when other actionable candidates remain.

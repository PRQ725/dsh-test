# RC3-CONTEXT - where the contract-verification bypass came from

Closure memo for the v0.2-rc.3 revision. The formal record is `RC3-CHANGE-REPORT.md`; this note
keeps the worked example, because the defect is easier to recognize than to describe.

## The two runs a reader would see

Same project, same directory, two invocations that differ by one parameter.

**Without the contract (rc.2 behaviour):**

```
check-v0.2.ps1 - Long-running Toolkit v0.2 evaluator
mode: Adoption
instance root (declared): <project>\planning
instance-root consistency: UNCHECKED

PASS
  all V1-V12 and R1-R3 checks satisfied.
```

**With the contract:**

```
check-v0.2.ps1 - Long-running Toolkit v0.2 evaluator
mode: Adoption
instance root (declared): <project>\planning
declared instance root (the Instance root: field of <project>\planning\GOAL.md): planning/
instance-root consistency: PASS

ADOPTION PASS (contract-verified)
```

Every statement in the first output was true. The directory *was* sound, and the consistency check
*was* genuinely unchecked. The problem is what the word `PASS` does in a reader's head: it becomes
"adoption passed", and the line saying the decisive check did not run is one line among six. A
reader skimming a log, or a model summarising one, keeps the verdict and loses the caveat.

## Why "just document it" was not enough

The rc.2 documents already said that hygiene is not readiness and that a declaration should be
supplied. Guidance did not fail; the **default** failed. An optional parameter whose omission
silently produces a weaker-but-green result will be omitted, because omitting it is easier and the
output still looks successful. The fix therefore changed what the tool does when it is not given
the contract, rather than adding another paragraph asking for it.

## The three-part repair

1. **Refuse, do not downgrade.** `-Mode Adoption` and `-Mode Readiness` exit with `ERROR` (2) when
   no contract is supplied. There is no quiet path from a contract-verified mode to an unverified
   result.
2. **Give the weak check its own name and its own words.** `-Mode Hygiene` runs the
   directory-level check, prints `HYGIENE PASS` together with `CONTRACT NOT CHECKED`, and is
   refused if a contract is passed to it (which would blur the two). `ADOPTION PASS` is reserved
   for the contract-verified run.
3. **Make each verdict state its own limits.** Candidate validation, hygiene, adoption and
   readiness each print what they proved and what they did not, so the claim and the caveat travel
   together and cannot be separated by skimming.

## The transferable rule

When one check can be run at more than one strength, the strength is part of the **verdict**, not
of the reader's assumption - and the default is the strongest variant that can fail closed.

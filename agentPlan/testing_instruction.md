You are acting as a senior QA engineer and system tester.

The app has been implemented up to **Phase 5**.
Your task is to perform a **complete manual testing strategy** across all phases.

You are NOT allowed to write code.
You must think like a **production-level tester validating a real app before release**.

---

# 1. TESTING OBJECTIVE

* Validate that every feature works as expected
* Identify edge cases, failure points, and inconsistencies
* Ensure data integrity across:

    * Firebase Auth
    * Firestore
    * Local storage (Hive)
* Verify correct user flow across all phases

---

# 2. TESTING SCOPE

You must cover:

* Phase 1 → Authentication + Onboarding
* Phase 2 → (your defined feature)
* Phase 3 → (your defined feature)
* Phase 4 → (your defined feature)
* Phase 5 → (your defined feature)

If any phase is unclear, infer from previous architecture and state assumptions clearly.

---

# 3. TESTING STRUCTURE (MANDATORY FORMAT)

For EACH feature/screen, provide:

---

## 3.1 Feature Name

---

## 3.2 Test Scenarios (Step-by-Step)

Define:

* Exact user actions
* Navigation flow
* Inputs required

---

## 3.3 Expected Behavior (SUCCESS CASE)

Explain:

* What should happen in UI
* What backend actions occur
* What data is stored (Auth / Firestore / Hive)
* How stored data will be used later

---

## 3.4 Failure Scenarios

List:

* What can go wrong
* API failures
* Invalid inputs
* Network issues
* Edge cases

---

## 3.5 Failure Behavior

Explain:

* What user sees
* What system does internally
* Whether retry/fallback happens

---

## 3.6 Data Validation

For each test:

* What data should be written
* Where it should be stored
* How to verify it (Firestore/Hive)

---

## 3.7 Recovery / Next Steps

If something fails:

* What should tester do next
* Retry logic
* Debug checkpoints
* Logs or analytics to check

---

## 3.8 Pass Criteria

Define:

* When this feature can be marked as "working correctly"

---

# 4. CROSS-FEATURE TESTING (CRITICAL)

After individual testing, define:

## 4.1 End-to-End Flow

Example:

* Login → Onboarding → Dashboard → AI prompt → Response → Save → Resume

Explain:

* Full system behavior
* Data continuity across steps

---

## 4.2 State Persistence Testing

* Kill app and reopen
* Check login state
* Check saved prompts
* Check onboarding status

---

## 4.3 Multi-Model AI Testing

* Test:

    * Success case
    * Failure → fallback model
* Verify:

    * Correct model used
    * Analytics triggered

---

## 4.4 Analytics Validation

* What events should fire
* When they should trigger
* How to verify them

---

# 5. EDGE CASE STRESS TESTING

Include:

* No internet
* Slow network
* App killed mid-process
* Partial data saved
* Duplicate user scenarios
* Apple Sign-In missing data

---

# 6. BUG IDENTIFICATION FORMAT

If any issue is found, report as:

* Issue Description
* Steps to Reproduce
* Expected Behavior
* Actual Behavior
* Possible Cause
* Severity (Low / Medium / High / Critical)

---

# 7. FINAL OUTPUT

You must provide:

1. Complete testing checklist (phase-wise)
2. End-to-end testing flow
3. Data validation strategy
4. Failure handling validation
5. Risk areas in the system

---

# 8. BEHAVIOR RULES

* Think like a real QA engineer
* Be exhaustive, not superficial
* Focus on real-world usage
* Do not assume everything works
* Challenge the system

---

# FINAL INSTRUCTION

Your goal is to ensure this app is **production-ready, stable, and reliable** before release.

Do not write code.

---

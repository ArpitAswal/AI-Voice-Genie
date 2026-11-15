---
name: api-design
description: Step-by-step execution checklist for building robust API integrations, DTOs, and repository contracts.
---

# API Design & Integration Workflow

When instructed to build or update an API integration, execute these steps sequentially:

## Step 1: Define the Domain & Contract
1. Define the immutable Domain Model first (what the UI will actually use).
2. Define the Repository Interface (e.g., `Future<Result<User, Failure>> getUser()`).
3. Define the explicit typed failures (`Offline`, `Unauthorized`, `ServerError`). Do not rely on generic exceptions.

## Step 2: Build the Data Transfer Objects (DTOs)
1. Create the DTO classes to model the exact raw JSON response from the server.
2. Write the `toDomain()` mapper methods inside the DTO to convert it to the Domain Model.

## Step 3: Implement the Repository
1. Write the API client call (handling headers, timeouts, and tokens).
2. Catch HTTP errors and map them to your typed domain failures.
3. If offline support is required, implement the local caching logic (read from local DB first, sync from network in the background).

## Step 4: Verification
1. Verify cursor-based pagination is used for lists (no duplicate page fetches).
2. Run `dart format` and platform analyzers before handing over the code.
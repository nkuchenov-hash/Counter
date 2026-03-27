# LIFE OS: MASTER SPECIFICATION v8.0.0 (NocoDB-STRICT)

## 1. FILE HIERARCHY (The Sovereign Vaults)
| Vault | Responsibility | Rule |
| :--- | :--- | :--- |
| `lib/data/models.dart` | **Data DNA** | Pure Classes. Fields MUST match @DATA_MAP.md exactly. No logic or UI imports. |
| `lib/data/database_service.dart`| **The Brain** | [REST ONLY] All NocoDB HTTP logic. Only file allowed to import `http`. |
| `lib/data/auth_bridge.dart` | **The Gate** | Session Persistence via `user_id` + `xc-token`. |
| `lib/app_shell.dart` | **The Navigator**| BottomNavBar & Global FAB. The UI Orchestrator. |
| `lib/main.dart` | **The Ignition** | Boot sequence: Verify `user_id` and load Global Profile before Home. |

## 2. THE UUID & PK LAW (Anti-404 Protocol)
- **PRIMARY_KEY_STRICTNESS**: Every object MUST use its specific UUID field as the primary identifier: `record_id`, `category_id`, `plan_id`, or `user_id`. 
- **NO_ROW_INDICES**: Using bogus integer row indices for API endpoints is **STRICTLY PROHIBITED**. Use @DATA_MAP.md PK columns only.
- **ID_ALIASING**: Timeline/record REST id = Noco `record_id` (String). Planning REST id = `plan_id` (String).
- **ENDPOINT_CONSISTENCY (Noco v3)**: PATCH/DELETE use `.../{table}/records/{pk}` where `{pk}` is the **business PK** (`record_id`, `plan_id`), per @DATA_MAP.md. Payloads still use the `{"fields":{}}` wrapper.

## 3. CORE LOGIC CONTRACTS
- **ACTIVE_STATUS_LAW**: An "Active" record is defined ONLY as a row where `end_time` is NULL and `status == 'running'`.
- **SINGLETON_STOP**: Starting a new record MUST automatically PATCH the `end_time` of any currently 'running' record for that user before starting the new one.
- **OWNERSHIP_FILTER**: Every single API request MUST include the query: `?where=(user_id,eq,{{current_user_id}})`.
- **INSTANT_PURGE_PROTOCOL**: UI updates state (Optimistic Update) BEFORE the HTTP `await` completes.
- **STATE_RECONCILIATION**: If a server request fails (404/422), the UI MUST revert the local change or purge the ghost record.

## 4. NOCODB v3 API WRAPPING
- **FIELDS_WRAPPER**: ALL outbound POST/PATCH payloads MUST wrap data in a `{"fields": {...}}` object per NocoDB v3 specifications.
- **FLATTENING_LAW**: Upon receiving data, the Brain MUST flatten the `fields` object so the Model only sees the direct properties.
- **UPSERT_PROTOCOL**: Prefer sending updates as a Bulk Array `[]` to the base endpoint to ensure NocoDB handles the transaction correctly.

## 5. PLANETARY TIME PROTOCOL (The God Offset)
- **STORAGE_FORMAT**: All timestamps stored as UTC ISO8601 strings in the database.
- **THE_GOD_OFFSET**: `timezone_offset` from the `profiles` table is the ONLY source of truth for time.
- **BANNED_FUNCTIONS**: `DateTime.now().toLocal()` and automatic hardware timezone detection are STRICTLY BANNED.
- **WALL_CLOCK_LOGIC**: UI display = `UTC_Time + Profile_Offset`. User input = `Input_Time - Profile_Offset` (converted to UTC before POST).

## 6. GEO-SOVEREIGNTY & MIRRORS
- **VPN_SOVEREIGNTY**: Shell MUST detect location/origin at runtime to choose between Global VDS or Local Mirror.
- **SOVEREIGN_ENDPOINT**: Production Noco v3 Data API (HTTPS): `https://217-114-0-201.sslip.io/api/v3/data/pfew89z7fxv42ek/mjchwhned7zsvj0/records`.
- **AUTH_REST_CONTRACT**: Authentication uses the `xc-token`: `Zi1tRdLEWLq4f8kQU4aJYILY255BV43PJ3fgVoAs`.
- **UUID_ANCHOR**: Identity is anchored to the `user_id` stored in `SecureStorage`. Consistent across all mirrors.

## 7. CATEGORY MATCHING & MATCHING LAW
- **WORD_MATCH_LAW**: Auto-categorization (from voice/text) MUST use Whole Word Matching via `title.split(' ')`. 
- **STRICT_BAN**: Substring matching and fuzzy character matching are STRICTLY PROHIBITED.

## 8. HIERARCHICAL STATS CONTRACT
- **RECURSIVE_TREE**: `getAggregatedStats` MUST build a nested `StatsNode` tree where Parents mathematically sum the durations of all nested children.

## 9. WEB_PLATFORM_SOVEREIGNTY
- **HARDWARE_GUARDS**: Speech-to-Text and Biometrics MUST check `kIsWeb` and use browser-native APIs (HTML5 SpeechRecognition) where available.
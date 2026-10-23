'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');

const source = fs.readFileSync(
  'lib/data/ai/viktor_conversation_store.dart', 'utf8');
const ui = fs.readFileSync(
  'lib/features/viktor/viktor_chat_page.dart', 'utf8') + '\n' +
  fs.readFileSync(
    'lib/features/viktor/viktor_dialogue_ui_state.dart', 'utf8');
const migration = fs.readFileSync(
  'pb_migrations/1792710000_viktor_turns.js', 'utf8');

assert.match(source, /flutter_secure_storage/,
  'Offline dialogue must use encrypted, not plaintext, local storage');
assert.match(source, /_outboxKey\(String owner\)/);
assert.match(source, /_restoreOutbox\(String owner\)/);
assert.match(source, /_saveOutbox\(\)/);
assert.match(source, /client_turn_id/);
assert.match(source, /existing\.items\.single\.data\['body'\] != item\.body/,
  'A retrieved server row must match the pending turn exactly');
assert.match(source, /existing\.items\.isEmpty[\s\S]*?rethrow/,
  'Unverified sends must stay pending');
assert.match(source, /_pending\.removeAt\(0\)/,
  'An acknowledged server turn must leave the live pending queue');
assert.doesNotMatch(source, /_pending\.insert\(0, item\)/,
  'A failed browser-cache rewrite must not undo a confirmed server receipt');
assert.match(source, /_secureStorageUnavailable/,
  'Browser secure-storage errors must be distinguished from server failures');
assert.match(source, /_outboxUnreadable/,
  'Unreadable encrypted pending turns must never be silently discarded');
assert.match(source, /if \(_outboxUnreadable\)/,
  'A new local write must not overwrite an unreadable old outbox');
assert.match(ui, /_dialogueStore\.localOutboxUnreadable/,
  'Keep visible warning and retry restoring existing unreadable encrypted history');
assert.match(source, /await _flush\(ownerAtSubmission\)/,
  'Online saves must still run if browser encrypted storage fails');

const append = source.slice(source.indexOf('Future<void> append('));
assert.ok(append.indexOf('await _restoreOutbox(ownerAtSubmission)') <
  append.indexOf('_pending.add('));
assert.ok(append.indexOf('_pending.add(') <
  append.indexOf('await _saveOutbox()'));
assert.ok(append.indexOf('await _saveOutbox()') <
  append.indexOf('await _flush(ownerAtSubmission)'),
  'Persist encrypted queue before attempting a remote mutation');

const load = source.slice(source.indexOf('Future<List<ViktorDialogueTurn>> load()'));
assert.match(load, /await _restoreOutbox\(owner\)/);
assert.match(load, /serverIds\.contains\(item\.id\)/,
  'Local pending messages must not duplicate server history');
assert.match(ui, /_dialogueStore\.pendingCount == 0/);
assert.match(ui, /_dialogueStore\.load\(\)/,
  'Recovery must re-fetch history even when the pending queue is empty');
assert.match(ui, /ViktorDialogueTurn\.lastRepeatableUserRequest/,
  'The retry affordance must resolve an actual earlier user command');
assert.match(ui, /ViktorDialogueTurn\.isRepeatCommand/,
  'A typed repeat request must not be sent literally to the provider');
assert.match(ui, /pendingInMemoryOnly/,
  'Unprotected in-memory turns require an explicit durability warning');
assert.match(ui, /unawaited\(_persistTurn\(turn\)\)/,
  'A transient error must not disable subsequent writes');

assert.match(source, /Future<void> retryPending\(\)/);
assert.match(ui, /_dialogueStore\.retryPending\(\)/,
  'An explicit retry must use the same serialized outbox as appends');
assert.match(ui, /label: 'Повторить'/,
  'Unsynced dialogue must offer a manual retry control');
assert.match(ui, /String\? _historyNotice/,
  'Sync warnings must not pollute model conversation turns');

assert.match(ui, /_completeRepeatedRead/, 'Repeated reads should be corrected via conversation context');
assert.match(ui, /time zone over/, 'Explicit user clock preferences must take precedence');

const chatPage = fs.readFileSync(
  'lib/features/viktor/viktor_chat_page.dart', 'utf8');
const dialoguePart = fs.readFileSync(
  'lib/features/viktor/viktor_dialogue_ui_state.dart', 'utf8');
assert.match(chatPage, /part 'viktor_dialogue_ui_state\.dart';/,
  'The extracted dialogue state must be part of the UI library');
assert.match(dialoguePart, /part of 'viktor_chat_page\.dart';/);
assert.ok(chatPage.split(/\r?\n/).length <= 1000,
  'Viktor UI page must remain below the architecture size threshold');

assert.match(ui, /Timer\.periodic\(const Duration\(seconds: 20\)/,
  'Pending turns should retry without waiting for another user message');
assert.match(ui, /_stopHistoryRetry\(\)/,
  'A completed dialogue sync must stop the retry timer');
assert.match(ui, /_historyRetryInFlight/,
  'Overlapping timer sync attempts must be prevented');

const max = Number(append.match(/substring\(0,\s*(\d+)\)/)?.[1]);
const footer = '\n[Сообщение обрезано при сохранении]';
assert.ok(Number.isInteger(max) && max + footer.length <= 6000,
  'Truncated content must fit the PocketBase 6000-character text field');
assert.match(migration, /UNIQUE INDEX idx_viktor_turns_owner_client/,
  'Server must enforce a unique owner-scoped client_turn_id');
process.stdout.write('Viktor encrypted outbox contract: PASS\n');

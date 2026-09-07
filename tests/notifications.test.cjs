// Test the actual QML handlers, including synchronous Notification.closed
// callbacks, without sending notifications or changing desktop focus.
// Run: node --test tests/notifications.test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const qml = fs.readFileSync(path.join(__dirname, '../quickshell/plugins/Notifications.qml'), 'utf8');
const handlers = [...qml.matchAll(/^  function \w+\([^\n]*\) \{\n[\s\S]*?^  \}/gm)]
  .map(match => match[0]).join('\n');

function listModel() {
  const rows = [];
  return {
    get count() { return rows.length; },
    get: i => rows[i],
    insert: (i, row) => rows.splice(i, 0, { ...row }),
    set: (i, row) => { rows[i] = { ...row }; },
    remove(i) {
      assert.ok(i >= 0 && i < rows.length, 'no duplicate/re-entrant model removal');
      rows.splice(i, 1);
    },
    clear: () => { rows.length = 0; },
  };
}

function setup() {
  const context = vm.createContext({
    popupModel: listModel(), historyModel: listModel(),
    liveNotifications: {}, notificationIds: {}, historyLimit: 50,
    doNotDisturb: false, centerOpen: false,
  });
  context.root = context;
  vm.runInContext(handlers, context);
  return context;
}

function notification(id, actions = []) {
  const closed = [];
  return {
    id, appName: 'Ghostty', summary: 'Done', body: 'Same text in both terminals',
    urgency: 1, actions, dismissals: 0, tracked: false,
    closed: { connect: callback => closed.push(callback) },
    dismiss() {
      this.dismissals++;
      assert.equal(this.dismissals, 1, 'notification must be closed only once');
      closed.forEach(callback => callback());
    },
  };
}

test('identical Ghostty notifications invoke their own sender action and disappear', () => {
  const root = setup();
  let focused = 'window-A';
  const a = notification(1);
  const b = notification(2);
  for (const [ref, window] of [[a, 'window-A'], [b, 'window-B']]) {
    ref.actions = [{ identifier: 'default', invoke() {
      assert.equal(root.centerOpen, false, 'history must release keyboard focus first');
      focused = window;
      ref.dismiss(); // Quickshell closes non-resident notifications on invoke.
    } }];
    root.addNotification(ref);
  }
  const uidA = root.notificationIds['1'];
  root.centerOpen = true;
  root.invokeDefault(root.notificationIds['2']);
  assert.equal(focused, 'window-B');
  assert.equal(root.historyModel.count, 1);
  assert.equal(root.popupModel.count, 1);
  assert.equal(root.liveNotifications[uidA], a);
  root.invokeDefault(uidA);
  assert.equal(focused, 'window-A');
  assert.equal(root.historyModel.count, 0);
  assert.equal(root.popupModel.count, 0);
  assert.equal(Object.keys(root.liveNotifications).length, 0);
});

test('resident default actions run once and are explicitly dismissed', () => {
  const root = setup();
  let invocations = 0;
  const ref = notification(3, [{ identifier: 'default', invoke() { invocations++; } }]);
  root.addNotification(ref);
  const uid = root.notificationIds['3'];
  root.invokeDefault(uid);
  root.invokeDefault(uid);
  assert.equal(invocations, 1);
  assert.equal(ref.dismissals, 1);
  assert.equal(root.historyModel.count, 0);
});

test('no-default notifications dismiss without invoking another action or guessing a window', () => {
  const root = setup();
  const ref = notification(4, [{ identifier: 'delete', invoke() { assert.fail('not a default action'); } }]);
  root.addNotification(ref);
  root.invokeDefault(root.notificationIds['4']);
  assert.equal(ref.dismissals, 1);
  assert.equal(root.historyModel.count, 0);
});

test('replacement, eviction and clear preserve model/map consistency', () => {
  const root = setup();
  root.historyLimit = 2;
  const refs = [notification(5), notification(6), notification(7)];
  root.addNotification(refs[0]);
  refs[0].summary = 'Updated';
  root.addNotification(refs[0]);
  assert.equal(root.historyModel.count, 1);
  assert.equal(root.historyModel.get(0).summary, 'Updated');
  root.addNotification(refs[1]);
  root.addNotification(refs[2]);
  assert.equal(refs[0].dismissals, 1);
  assert.equal(root.historyModel.count, 2);
  root.clearHistory();
  assert.deepEqual(refs.map(ref => ref.dismissals), [1, 1, 1]);
  assert.equal(root.historyModel.count, 0);
  assert.equal(root.popupModel.count, 0);
  assert.equal(Object.keys(root.notificationIds).length, 0);
  assert.equal(Object.keys(root.liveNotifications).length, 0);
});

test('sender close only forgets the notification, without closing it again', () => {
  const root = setup();
  const ref = notification(8);
  root.addNotification(ref);
  ref.dismiss();
  assert.equal(root.historyModel.count, 0);
  assert.equal(root.popupModel.count, 0);
  assert.equal(ref.dismissals, 1);
});

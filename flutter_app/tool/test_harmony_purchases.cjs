// Runs the real ArkTS bridge after TypeScript transpilation, with fake platform
// APIs only. Cryptographic receipt verification has its own separate real test.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.OHOS_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript/lib/typescript.js');

const source = fs.readFileSync(path.join(__dirname,
  '../ohos/entry/src/main/ets/plugins/StorePurchases.ets'), 'utf8');
const compiled = ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const errors = {
  USER_CANCELED: 1001860000, SYSTEM_ERROR: 1001860001, APP_NOT_AUTHORIZED: 1001860002,
  INVALID_PRODUCT: 1001860003, FREQUENT_CALLS: 1001860004, NETWORK_ERROR: 1001860005,
  PRODUCT_TERRITORY_NOT_SUPPORTED: 1001860007, ACCOUNT_NOT_LOGGED_IN: 1001860050,
  PRODUCT_OWNED: 1001860051, PURCHASE_NOT_PAID: 1001860052, PURCHASE_FINISHED: 1001860053,
  ACCOUNT_TERRITORY_NOT_SUPPORTED: 1001860054, APP_NOT_DEBUG: 1001860057,
  ACCOUNT_NOT_TEST: 1001860058, PURCHASE_ALREADY_REFUNDED: 1001860061
};
const pending = () => {
  let resolve;
  let reject;
  const promise = new Promise((done, fail) => { resolve = done; reject = fail; });
  return { promise, resolve, reject };
};
const tick = () => new Promise(resolve => setImmediate(resolve));
const envelope = name => JSON.stringify({ jwsPurchaseOrder: name });
const signedOrder = overrides => ({
  applicationId: '6917619319382055664', productId: 'com.bookmovie.revisit.app.pro.lifetime',
  productType: '1', purchaseOrderId: 'order-1', purchaseToken: 'token-1',
  purchaseTime: 100, finishStatus: '2', needFinish: true,
  environment: 'SANDBOX', signedTime: 200, price: 2800, currency: 'CNY',
  revoked: false, ...overrides
});

function fixture(overrides = {}, configuration = {}) {
  const calls = [];
  const events = [];
  const responses = [];
  const receipts = new Map([['valid', signedOrder()]]);
  const iap = {
    ProductType: { NONCONSUMABLE: 1 },
    PurchaseQueryType: { ALL: 0, UNFINISHED: 1, CURRENT_ENTITLEMENT: 2 },
    IAPErrorCode: errors,
    queryEnvironmentStatus: async () => { calls.push('environment'); },
    isSandboxActivated: async () => true,
    queryProducts: async () => [{ id: 'com.bookmovie.revisit.app.pro.lifetime', type: 1, localPrice: '¥28.00' }],
    createPurchase: async () => ({ purchaseData: envelope('valid') }),
    queryPurchases: async (_context, parameter) => {
      calls.push({ query: parameter.queryType, token: parameter.continuationToken });
      return responses.shift() ?? { purchaseDataList: [] };
    },
    finishPurchase: async (_context, parameter) => {
      assert.equal(events.at(-1)?.value, true, 'grant must precede acknowledgement');
      calls.push({ finish: parameter });
    },
    ...overrides
  };
  const config = {
    HUAWEI_APP_ID: '6917619319382055664', HUAWEI_CLIENT_ID: 'test-client-id',
    HUAWEI_PRODUCT_ID: 'com.bookmovie.revisit.app.pro.lifetime', SANDBOX_ONLY: true,
    ...configuration
  };
  class MethodChannel {
    setMethodCallHandler(handler) { this.handler = handler; }
    invokeMethod(method, value) { events.push({ method, value }); }
  }
  const modules = {
    '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel': { default: MethodChannel },
    '@kit.IAPKit': { iap },
    './HuaweiIapConfig': config,
    './PurchaseVerification': {
      verifyPurchaseOrder: async (jws, applicationId, sandbox) => {
        calls.push({ verify: jws });
        assert.equal(applicationId, config.HUAWEI_APP_ID);
        assert.equal(sandbox, true);
        const value = receipts.get(jws);
        if (!value) throw new Error('Invalid receipt');
        return await value;
      }
    }
  };
  const module = { exports: {} };
  new Function('require', 'module', 'exports', compiled)(name => {
    if (!modules[name]) throw new Error(`Unexpected native dependency ${name}`);
    return modules[name];
  }, module, module.exports);
  const store = new module.exports.default({});
  store.attach({ getBinaryMessenger: () => null });
  function call(method) {
    const wait = pending();
    let replies = 0;
    const result = {
      success: value => { assert.equal(++replies, 1); wait.resolve({ value }); },
      error: (code, message) => { assert.equal(++replies, 1); wait.resolve({ error: { code, message } }); },
      notImplemented: () => { assert.equal(++replies, 1); wait.resolve({ notImplemented: true }); }
    };
    store.onMethodCall({ method }, result);
    return wait.promise;
  }
  return { store, call, calls, events, responses, receipts, iap };
}

const tests = [];
const test = (name, run) => tests.push({ name, run });

test('product uses the store price and is explicitly sandbox', async () => {
  const f = fixture();
  assert.deepEqual((await f.call('product')).value, {
    purchasesEnabled: true, sandbox: true,
    productId: 'com.bookmovie.revisit.app.pro.lifetime', price: '¥28.00'
  });
});

test('missing Client ID prevents all platform calls and buying', async () => {
  const f = fixture({}, { HUAWEI_CLIENT_ID: '' });
  assert.equal((await f.call('status')).value, false);
  assert.equal((await f.call('product')).value.purchasesEnabled, false);
  assert.equal((await f.call('buy')).error.code, 'configuration');
  assert.equal(f.calls.length, 0);
});

test('production is disabled and a non-sandbox account cannot buy', async () => {
  const production = fixture({}, { SANDBOX_ONLY: false });
  assert.equal((await production.call('buy')).error.code, 'configuration');
  const f = fixture({ isSandboxActivated: async () => false });
  assert.equal((await f.call('product')).value.purchasesEnabled, false);
  assert.equal((await f.call('buy')).error.code, 'sandbox');
  assert.equal(f.events.some(event => event.value === true), false);
});

test('a successful purchase is verified, delivered, then acknowledged', async () => {
  const f = fixture();
  assert.equal((await f.call('buy')).value, 'purchased');
  assert.deepEqual(f.events, [{ method: 'changed', value: true }]);
  assert.deepEqual(f.calls.find(call => call.finish)?.finish, {
    productType: 1, purchaseToken: 'token-1', purchaseOrderId: 'order-1'
  });
  assert(f.calls.findIndex(call => call.verify) < f.calls.findIndex(call => call.finish));
  // An acknowledged sandbox order disappears from the SDK, but not from this
  // verified foreground session. It cannot survive the next background event.
  assert.equal((await f.call('status')).value, true);
  f.store.onBackground();
  f.store.onForeground();
  assert.equal((await f.call('status')).value, false);
});

test('an unverified or malformed receipt never grants or finishes', async () => {
  for (const purchaseData of [envelope('forged'), '{}', 'null']) {
    const f = fixture({ createPurchase: async () => ({ purchaseData }) });
    assert.equal((await f.call('buy')).error.code, 'receipt');
    assert.equal(f.events.length, 0);
    assert.equal(f.calls.some(call => call.finish), false);
  }
});

test('revoked and unpaid signed orders are not granted', async () => {
  const revoked = fixture();
  revoked.receipts.set('valid', signedOrder({ revoked: true }));
  assert.equal((await revoked.call('buy')).error.code, 'revoked');
  assert.equal(revoked.events.length, 0);
  const unpaid = fixture();
  unpaid.receipts.set('valid', signedOrder({ purchaseTime: 0 }));
  assert.equal((await unpaid.call('buy')).value, 'pending');
  assert.equal(unpaid.events.length, 0);
  assert.equal(unpaid.calls.some(call => call.finish), false);
});

test('cancellation is a normal result without entitlement', async () => {
  const f = fixture({ createPurchase: async () => { throw { code: errors.USER_CANCELED }; } });
  assert.equal((await f.call('buy')).value, 'cancelled');
  assert.equal(f.events.length, 0);
});

test('already owned must be verified through current-account recovery', async () => {
  const f = fixture({ createPurchase: async () => { throw { code: errors.PRODUCT_OWNED }; } });
  f.responses.push({ purchaseDataList: [envelope('valid')] }, { purchaseDataList: [] });
  assert.equal((await f.call('buy')).value, 'purchased');
  const unverified = fixture({ createPurchase: async () => { throw { code: errors.PRODUCT_OWNED }; } });
  assert.equal((await unverified.call('buy')).error.code, `iap_${errors.PRODUCT_OWNED}`);
  assert.equal(unverified.events.length, 0);
});

test('recovery follows pagination and explicitly checks unfinished purchases', async () => {
  const f = fixture();
  f.responses.push(
    { purchaseDataList: [], continuationToken: 'next-page' },
    { purchaseDataList: [envelope('valid')] },
    { purchaseDataList: [envelope('valid')] }
  );
  assert.equal((await f.call('restore')).value, true);
  assert.deepEqual(f.calls.filter(call => call.query !== undefined), [
    { query: 2, token: undefined }, { query: 2, token: 'next-page' }, { query: 1, token: undefined }
  ]);
  assert.equal(f.calls.filter(call => call.finish).length, 1);
});

test('a newer signed revocation overrides an older positive record', async () => {
  const f = fixture();
  f.receipts.set('revoked', signedOrder({ revoked: true, signedTime: 300 }));
  f.responses.push(
    { purchaseDataList: [envelope('valid')], continuationToken: 'next' },
    { purchaseDataList: [envelope('revoked')] },
    { purchaseDataList: [envelope('valid')] }
  );
  assert.equal((await f.call('status')).value, false);
  assert.equal(f.calls.some(call => call.finish), false);
  assert.equal(f.events.length, 0);
});

test('partial or looping queries never grant a partially verified result', async () => {
  const invalid = fixture();
  invalid.responses.push({ purchaseDataList: [envelope('valid')], continuationToken: 'next' },
    { purchaseDataList: [envelope('forged')] });
  assert.equal((await invalid.call('status')).error.code, 'receipt');
  assert.equal(invalid.events.length, 0);
  const loop = fixture();
  loop.responses.push({ purchaseDataList: [], continuationToken: 'same' },
    { purchaseDataList: [envelope('valid')], continuationToken: 'same' });
  assert.equal((await loop.call('status')).error.code, 'pagination');
  assert.equal(loop.events.length, 0);
});

test('empty sandbox restore is explicit and cannot fake a restored license', async () => {
  const f = fixture();
  assert.equal((await f.call('restore')).error.code, 'sandbox_restore_unavailable');
  assert.equal(f.events.length, 0);
});

test('empty restore preserves only the verified current foreground session', async () => {
  const f = fixture();
  await f.call('buy');
  assert.equal((await f.call('restore')).value, true);
  assert.deepEqual(f.events, [{ method: 'changed', value: true }]);
  f.store.onBackground();
  f.store.onForeground();
  assert.equal((await f.call('restore')).error.code, 'sandbox_restore_unavailable');
  assert.deepEqual(f.events.at(-1), { method: 'changed', value: false });
});

test('a signed revocation still overrides current sandbox session during restore', async () => {
  const f = fixture();
  await f.call('buy');
  f.receipts.set('revoked', signedOrder({ revoked: true, signedTime: 300 }));
  f.responses.push({ purchaseDataList: [envelope('revoked')] }, { purchaseDataList: [] });
  assert.equal((await f.call('restore')).error.code, 'sandbox_restore_unavailable');
  assert.deepEqual(f.events.at(-1), { method: 'changed', value: false });
});

test('unfinished delivery retries without duplicating entitlement', async () => {
  let attempts = 0;
  const f = fixture({ finishPurchase: async () => {
    if (++attempts === 1) throw { code: errors.NETWORK_ERROR };
  } });
  assert.equal((await f.call('buy')).error.code, `iap_${errors.NETWORK_ERROR}`);
  f.responses.push({ purchaseDataList: [envelope('valid')] }, { purchaseDataList: [envelope('valid')] });
  assert.equal((await f.call('status')).value, true);
  assert.equal(attempts, 2);
  assert.deepEqual(f.events, [{ method: 'changed', value: true }]);
});

test('backgrounded old queries cannot grant after a new session starts', async () => {
  const old = pending();
  let reads = 0;
  const f = fixture({ queryPurchases: async () => ++reads === 1 ? old.promise : { purchaseDataList: [] } });
  const first = f.call('status');
  await tick();
  f.store.onBackground();
  assert.equal((await first).error.code, 'interrupted');
  f.store.onForeground();
  assert.equal((await f.call('status')).value, false);
  old.resolve({ purchaseDataList: [envelope('valid')] });
  await tick();
  assert.equal(f.events.length, 0);
});

test('new checkout results may cross the cashier background boundary', async () => {
  const checkout = pending();
  const f = fixture({ createPurchase: async () => checkout.promise });
  const result = f.call('buy');
  await tick();
  assert.equal((await f.call('buy')).error.code, 'busy');
  f.store.onBackground();
  f.store.onForeground();
  checkout.resolve({ purchaseData: envelope('valid') });
  assert.equal((await result).value, 'purchased');
  assert.equal(f.events.at(-1).value, true);
});

test('background during verification blocks the old checkout grant', async () => {
  const verification = pending();
  const f = fixture();
  f.receipts.set('valid', verification.promise);
  const result = f.call('buy');
  await tick();
  f.store.onBackground();
  f.store.onForeground();
  verification.resolve(signedOrder());
  assert.equal((await result).error.code, 'interrupted');
  assert.equal(f.events.length, 0);
  assert.equal(f.calls.some(call => call.finish), false);
});

test('detach replies once and ignores the late checkout result', async () => {
  const checkout = pending();
  const f = fixture({ createPurchase: async () => checkout.promise });
  const result = f.call('buy');
  await tick();
  f.store.detach();
  assert.equal((await result).error.code, 'interrupted');
  checkout.resolve({ purchaseData: envelope('valid') });
  await tick();
  assert.equal(f.events.length, 0);
  assert.equal(f.calls.some(call => call.finish), false);
});

test('a stale finish failure cannot revoke a newer verified session', async () => {
  const oldFinish = pending();
  let finishes = 0;
  const f = fixture({ finishPurchase: async () => ++finishes === 1 ? oldFinish.promise : undefined });
  f.responses.push({ purchaseDataList: [envelope('valid')] }, { purchaseDataList: [] });
  const oldStatus = f.call('status');
  await tick();
  f.store.onBackground();
  assert.equal((await oldStatus).error.code, 'interrupted');
  f.store.onForeground();
  assert.equal((await f.call('buy')).value, 'purchased');
  oldFinish.reject({ code: errors.PURCHASE_ALREADY_REFUNDED });
  await tick();
  assert.deepEqual(f.events.map(event => event.value), [true, false, true]);
  assert.equal((await f.call('status')).value, true);
});

(async () => {
  for (const { name, run } of tests) {
    await run();
    console.log(`PASS ${name}`);
  }
  console.log(`${tests.length} native purchase bridge checks passed`);
})().catch(error => { console.error(error); process.exitCode = 1; });

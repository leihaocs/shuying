// Executes the real ArkTS verifier after transpiling it. Node crypto/OpenSSL
// substitute for native certificate/crypto APIs, never for the validation logic.
// The generated test CA is substituted only in this test process; production has
// no injectable trust anchor. Online OCSP/CRL transport still needs device tests.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const ts = require(process.env.OHOS_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript/lib/typescript.js');
const sourcePath = path.join(__dirname, '../ohos/entry/src/main/ets/plugins/PurchaseVerification.ets');
const source = fs.readFileSync(sourcePath, 'utf8');
const rootExpression = /const HUAWEI_ROOT_DER_BASE64: string =[\s\S]*?;/;
const officialRoot = [...source.match(rootExpression)[0].matchAll(/'([^']+)'/g)].map(m => m[1]).join('');
assert.equal(crypto.createHash('sha256').update(Buffer.from(officialRoot, 'base64')).digest('hex'),
  'df21a3c09f7954579305f85c64f80cad86f79853ee3a887c1dec95d218df3a37');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'shuying-iap-verify-'));
let checks = 1;
let rejectRevocation = false;
let chainChecks = 0;

function run(...args) {
  return execFileSync('openssl', args, { cwd: tmp, stdio: ['ignore', 'pipe', 'pipe'] }).toString();
}
function pem(name) { return fs.readFileSync(path.join(tmp, name), 'utf8'); }
function der(name) { return new crypto.X509Certificate(pem(name)).raw.toString('base64'); }
function key(name) { return crypto.createPrivateKey(pem(name)); }
function write(name, data) { fs.writeFileSync(path.join(tmp, name), data); }

function makeChain() {
  run('req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:P-256', '-nodes',
    '-keyout', 'root.key', '-out', 'root.pem', '-days', '2', '-subj', '/CN=Test-only IAP Root',
    '-addext', 'basicConstraints=critical,CA:TRUE,pathlen:1', '-addext', 'keyUsage=critical,keyCertSign,cRLSign');
  run('req', '-new', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:P-256', '-nodes',
    '-keyout', 'middle.key', '-out', 'middle.csr', '-subj', '/CN=Test-only IAP Intermediate');
  write('middle.ext', 'basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n');
  run('x509', '-req', '-in', 'middle.csr', '-CA', 'root.pem', '-CAkey', 'root.key',
    '-CAcreateserial', '-out', 'middle.pem', '-days', '2', '-extfile', 'middle.ext');
  run('req', '-new', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:P-256', '-nodes',
    '-keyout', 'leaf.key', '-out', 'leaf.csr', '-subj', '/CN=Test-only IAP Leaf');
  write('leaf.ext', 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n1.3.6.1.4.1.2011.2.415.1.1=ASN1:UTF8String:IAP\n');
  run('x509', '-req', '-in', 'leaf.csr', '-CA', 'middle.pem', '-CAkey', 'middle.key',
    '-CAcreateserial', '-out', 'leaf.pem', '-days', '2', '-extfile', 'leaf.ext');
  write('no-oid.ext', 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n');
  run('x509', '-req', '-in', 'leaf.csr', '-CA', 'middle.pem', '-CAkey', 'middle.key',
    '-CAserial', 'middle.srl', '-out', 'no-oid.pem', '-days', '2', '-extfile', 'no-oid.ext');
}

class NativeCert {
  constructor(data) {
    this.value = new crypto.X509Certificate(Buffer.from(data));
  }
  getPublicKey() {
    return { getEncoded: () => ({ data: this.value.publicKey.export({ type: 'spki', format: 'der' }) }) };
  }
  getExtensionsObject() {
    write('inspect.pem', this.value.toString());
    const text = run('x509', '-in', 'inspect.pem', '-noout', '-text');
    return { getOidList: () => ({ data: text.includes('1.3.6.1.4.1.2011.2.415.1.1:')
      ? [new TextEncoder().encode('1.3.6.1.4.1.2011.2.415.1.1\0')] : [] }) };
  }
}
const nativeCert = {
  EncodingFormat: { FORMAT_DER: 0 },
  ExtensionOidType: { EXTENSION_OID_TYPE_ALL: 0 },
  KeyUsageType: { KEYUSAGE_DIGITAL_SIGNATURE: 0 },
  RevocationCheckOptions: {
    REVOCATION_CHECK_OPTION_ACCESS_NETWORK: 1,
    REVOCATION_CHECK_OPTION_PREFER_OCSP: 0,
    REVOCATION_CHECK_OPTION_FALLBACK_NO_PREFER: 2,
  },
  createX509Cert: async blob => new NativeCert(blob.data),
  createX509CertChain: certs => ({ validate: async params => {
    assert.match(params.date, /^\d{14}Z$/);
    const d = params.date;
    const epoch = Date.UTC(+d.slice(0, 4), +d.slice(4, 6) - 1, +d.slice(6, 8),
      +d.slice(8, 10), +d.slice(10, 12), +d.slice(12, 14));
    assert.ok(Math.abs(Date.now() - epoch) < 2000);
    assert.equal(params.trustSystemCa, false);
    assert.equal(params.trustAnchors.length, 1);
    assert.deepEqual(Array.from(params.keyUsage), [0]);
    assert.deepEqual(Array.from(params.revocationCheckParam.options), [1, 0, 2]);
    if (rejectRevocation) throw new Error('test certificate revocation check failed');
    write('verify-anchor.pem', params.trustAnchors[0].CACert.value.toString());
    write('verify-middle.pem', certs[1].value.toString());
    write('verify-leaf.pem', certs[0].value.toString());
    run('verify', '-attime', String(Math.floor(epoch / 1000)), '-CAfile', 'verify-anchor.pem',
      '-untrusted', 'verify-middle.pem', 'verify-leaf.pem');
    assert.ok(certs[0].value.verify(certs[1].value.publicKey));
    assert.ok(certs[1].value.verify(params.trustAnchors[0].CACert.value.publicKey));
    chainChecks++;
  } }),
};
function integerDer(value) {
  let hex = value.toString(16);
  if (hex.length % 2) hex = '0' + hex;
  let data = Buffer.from(hex, 'hex');
  if (data[0] & 128) data = Buffer.concat([Buffer.from([0]), data]);
  return Buffer.concat([Buffer.from([2, data.length]), data]);
}
const nativeCrypto = {
  SignatureUtils: { genEccSignature: spec => {
    const data = Buffer.concat([integerDer(spec.r), integerDer(spec.s)]);
    return Buffer.concat([Buffer.from([0x30, data.length]), data]);
  } },
  createAsyKeyGenerator: algorithm => {
    assert.equal(algorithm, 'ECC256');
    return { convertKey: async (blob, privateKey) => {
      assert.equal(privateKey, null);
      const pubKey = crypto.createPublicKey({ key: Buffer.from(blob.data), format: 'der', type: 'spki' });
      assert.equal(pubKey.asymmetricKeyType, 'ec');
      assert.equal(pubKey.asymmetricKeyDetails.namedCurve, 'prime256v1');
      return { pubKey };
    } };
  },
  createVerify: algorithm => {
    assert.equal(algorithm, 'ECC256|SHA256');
    let pubKey;
    return {
      init: async value => { pubKey = value; },
      verify: async (input, signature) => crypto.verify('sha256', input.data, pubKey, signature.data),
    };
  },
};
const nativeUtil = {
  Base64Helper: class {
    decodeSync(value) { return new Uint8Array(Buffer.from(value, 'base64')); }
    encodeToStringSync(value) { return Buffer.from(value).toString('base64'); }
  },
  TextDecoder: { create: (encoding, options) => ({ decodeToString: value => new TextDecoder(encoding, options).decode(value) }) },
  TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } },
};
function load(anchor) {
  const text = anchor ? source.replace(rootExpression, `const HUAWEI_ROOT_DER_BASE64: string = '${anchor}';`) : source;
  const code = ts.transpileModule(text, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText;
  const exports = {};
  vm.runInNewContext(`(function(require,exports){${code}\n})`, { Uint8Array, console })((name) => {
    if (name === '@ohos.security.cert') return { default: nativeCert };
    if (name === '@ohos.security.cryptoFramework') return { default: nativeCrypto };
    if (name === '@ohos.util') return { default: nativeUtil };
    throw new Error(`Unexpected native module ${name}`);
  }, exports);
  return exports.verifyPurchaseOrder;
}
function encode(value) { return Buffer.from(JSON.stringify(value)).toString('base64url'); }
function receipt(order, header = {}, signingKey = key('leaf.key')) {
  const protectedHeader = { alg: 'ES256', typ: 'JWT', x5c: [der('leaf.pem'), der('middle.pem'), der('root.pem')], ...header };
  const data = `${encode(protectedHeader)}.${encode(order)}`;
  return `${data}.${crypto.sign('sha256', Buffer.from(data), { key: signingKey, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}
async function main() {
  makeChain();
  const verify = load(der('root.pem'));
  const valid = {
    applicationId: '123456', productId: 'com.bookmovie.revisit.app.pro.lifetime', productType: '1',
    purchaseOrderId: 'test-order', purchaseToken: 'test-token', purchaseTime: Date.now() - 1000,
    signedTime: Date.now(), finishStatus: '2', needFinish: true, environment: 'SANDBOX',
    price: 2800, currency: 'CNY', countryCode: 'CN',
  };
  const checkValid = async (order, sandbox = true) => {
    const result = await verify(receipt(order), '123456', sandbox);
    assert.equal(result.productId, valid.productId);
    assert.equal(result.revoked, order.purchaseOrderRevocationReasonCode !== undefined || order.revocationTime !== undefined);
    checks++;
  };
  const denied = async (jws, appId = '123456', sandbox = true) => {
    await assert.rejects(() => verify(jws, appId, sandbox));
    checks++;
  };
  await checkValid(valid);
  await checkValid({ ...valid, finishStatus: '1', needFinish: false });
  await checkValid({ ...valid, environment: 'NORMAL' }, false);
  await checkValid({ ...valid, purchaseOrderRevocationReasonCode: '0' });
  await checkValid({ ...valid, revocationTime: Date.now() });
  await assert.rejects(() => load()(receipt(valid), '123456', true)); checks++;
  const parts = receipt(valid).split('.');
  await denied(`${parts[0]}.${encode({ ...valid, price: 1 })}.${parts[2]}`);
  await denied(receipt(valid, {}, key('middle.key')));
  await denied(receipt(valid, { alg: 'HS256' }));
  await denied(receipt(valid, { typ: 'JWS' }));
  await denied(receipt(valid, { crit: ['b64'], b64: false }));
  await denied(receipt(valid, { x5c: [der('leaf.pem'), der('leaf.pem'), der('root.pem')] }));
  await denied(receipt(valid, { x5c: [der('no-oid.pem'), der('middle.pem'), der('root.pem')] }));
  await denied(receipt(valid, { x5c: [der('leaf.pem'), der('middle.pem')] }));
  await denied(receipt(valid), 'other-app');
  await denied(receipt(valid), '', true);
  await denied(receipt(valid), '123456', false);
  await denied(receipt({ ...valid, environment: 'NORMAL' }));
  for (const patch of [
    { applicationId: 123456 }, { productId: 'another-product' }, { productType: 1 }, { productType: '0' },
    { purchaseTime: undefined }, { purchaseTime: 0 }, { signedTime: Date.now() + 3600000 },
    { purchaseTime: Date.now() + 3600000 }, { purchaseToken: '' }, { purchaseOrderId: '' },
    { price: -1 }, { price: 28.5 }, { currency: 'cny' }, { countryCode: 'CHINA' },
    { finishStatus: '0' }, { needFinish: 'true' }, { purchaseOrderRevocationReasonCode: 0 },
    { revocationTime: '2026-11-09' },
  ]) await denied(receipt({ ...valid, ...patch }));
  for (const malformed of ['', 'a.b', 'a.b.c.d', 'a.b.c', '[]', '.a.b', `${parts[0]}=.${parts[1]}.${parts[2]}`]) {
    await denied(malformed);
  }
  rejectRevocation = true;
  await denied(receipt(valid));
  rejectRevocation = false;
  assert.ok(chainChecks > 20, 'real OpenSSL chain validation exercised');
  console.log(`Harmony IAP verification: ${checks} behavior checks passed (real ES256/OpenSSL chains; native OCSP transport requires device validation).`);
}
main().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => fs.rmSync(tmp, { recursive: true, force: true }));

// udisks2 → rail devices (SURFACES.md §2a). The fixture follows busctl --json=short output.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {load} = require('./visual/load.cjs');
const L = load('quickshell/services/MediaLogic.js');
const v = (type, data) => ({type, data});
const bytes = s => [...Buffer.from(s + '\0')];
const U = 'org.freedesktop.UDisks2.';
function drive(extra) { return {[U + 'Drive']: Object.fromEntries(Object.entries({Vendor: v('s', 'Generic'), Model: v('s', 'Flash Disk'), Removable: v('b', true),
  MediaRemovable: v('b', true), Ejectable: v('b', true), CanPowerOff: v('b', true), ConnectionBus: v('s', 'usb'), MediaCompatibility: v('as', []), Media: v('s', ''),
  MediaAvailable: v('b', true), RotationRate: v('i', 0), ...extra}))}; }
function block(drivePath, dev, extra, ifaces = {}) {
  return {[U + 'Block']: {Drive: v('o', drivePath), Device: v('ay', bytes(dev)), PreferredDevice: v('ay', bytes(dev)), Size: v('t', 64e9), IdUsage: v('s', 'filesystem'),
    IdType: v('s', 'vfat'), IdLabel: v('s', 'BACKUP'), HintIgnore: v('b', false), HintSystem: v('b', false), CryptoBackingDevice: v('o', '/'), ...extra}, ...ifaces};
}
const fs = mounts => ({[U + 'Filesystem']: {MountPoints: v('aay', mounts.map(bytes))}});
const part = {[U + 'Partition']: {Number: v('u', 1)}};
const fixture = {type: 'a{oa{sa{sv}}}', data: [{
  '/org/freedesktop/UDisks2/drives/stick': drive({MediaCompatibility: v('as', ['thumb'])}),
  '/org/freedesktop/UDisks2/block_devices/sdb': block('/org/freedesktop/UDisks2/drives/stick', '/dev/sdb', {IdUsage: v('s', ''), IdType: v('s', '')}),
  '/org/freedesktop/UDisks2/block_devices/sdb1': block('/org/freedesktop/UDisks2/drives/stick', '/dev/sdb1', {}, {...fs(['/run/media/u/BACKUP']), ...part}),
  '/org/freedesktop/UDisks2/drives/sys': drive({Removable: v('b', false), MediaRemovable: v('b', false), Ejectable: v('b', false), ConnectionBus: v('s', ''), RotationRate: v('i', 5400)}),
  '/org/freedesktop/UDisks2/block_devices/sda1': block('/org/freedesktop/UDisks2/drives/sys', '/dev/sda1', {HintSystem: v('b', true)}, fs(['/'])),
  '/org/freedesktop/UDisks2/drives/vault': drive({RotationRate: v('i', -1)}),
  '/org/freedesktop/UDisks2/block_devices/sdc1': block('/org/freedesktop/UDisks2/drives/vault', '/dev/sdc1', {IdUsage: v('s', 'crypto'), IdType: v('s', 'crypto_LUKS'), IdLabel: v('s', '')}, {[U + 'Encrypted']: {}, ...part}),
  '/org/freedesktop/UDisks2/drives/dvd': drive({MediaCompatibility: v('as', ['optical_cd', 'optical_dvd']), MediaAvailable: v('b', false)}),
  '/org/freedesktop/UDisks2/block_devices/sr0': block('/org/freedesktop/UDisks2/drives/dvd', '/dev/sr0', {}, fs([])),
  '/org/freedesktop/UDisks2/block_devices/loop0': block('/', '/dev/loop0', {IdType: v('s', 'iso9660'), IdLabel: v('s', 'ARCH_202611')}, {[U + 'Loop']: {}, ...fs([])}),
}]};

test('busctl JSON: variants unwrapped, byte strings decoded', () => {
  const o = L.parseManagedObjects(JSON.stringify(fixture));
  assert.equal(L.bytes(o['/org/freedesktop/UDisks2/block_devices/sdb1'][U + 'Block'].Device), '/dev/sdb1');
  assert.deepEqual([...L.strings(o['/org/freedesktop/UDisks2/block_devices/sdb1'][U + 'Filesystem'].MountPoints)], ['/run/media/u/BACKUP']);
});

test('devices: removable drives only, empty optical invisible, ISO images as discs, LUKS locked', () => {
  const list = L.devices(L.parseManagedObjects(fixture), {}, {});
  const by = Object.fromEntries([...list].map(d => [d.id.split('/').pop(), d]));
  assert.deepEqual(Object.keys(by).sort(), ['loop0', 'stick', 'vault']);
  assert.equal(by.stick.kind, 'usb'); assert.equal(by.stick.mounted, true); assert.equal(by.stick.mountPoint, '/run/media/u/BACKUP');
  assert.equal(by.stick.fsDevice, '/dev/sdb1'); assert.equal(by.stick.disk, '/dev/sdb'); assert.equal(by.stick.label, 'BACKUP');
  assert.equal(by.vault.kind, 'drive'); assert.equal(by.vault.locked, true); assert.equal(by.vault.encrypted, true);
  assert.equal(by.loop0.kind, 'disc');
});

test('unlocked LUKS: the cleartext filesystem carries mount state', () => {
  const f = JSON.parse(JSON.stringify(fixture));
  f.data[0]['/org/freedesktop/UDisks2/block_devices/dm_2d0'] = block('/', '/dev/dm-0', {CryptoBackingDevice: v('o', '/org/freedesktop/UDisks2/block_devices/sdc1'), IdType: v('s', 'ext4'), IdLabel: v('s', 'VAULT')}, fs(['/run/media/u/VAULT']));
  const vault = [...L.devices(L.parseManagedObjects(f), {}, {})].find(d => d.id.endsWith('vault'));
  assert.equal(vault.locked, false); assert.equal(vault.mounted, true); assert.equal(vault.label, 'VAULT'); assert.equal(vault.fsDevice, '/dev/dm-0');
});

test('classification order and VID:PID overrides', () => {
  const c = (d, b = {}, u = {}, o = {}) => L.classify(d, b, u, o);
  assert.equal(c({MediaCompatibility: ['optical_bd']}), 'disc');
  assert.equal(c({MediaCompatibility: ['floppy_zip']}), 'zip');
  assert.equal(c({MediaCompatibility: ['floppy']}), 'floppy');
  assert.equal(c({MediaCompatibility: ['flash_sd']}), 'sd');
  assert.equal(c({ConnectionBus: 'sdio'}), 'sd');
  assert.equal(c({MediaCompatibility: ['thumb']}), 'usb');
  assert.equal(c({}, {IdLabel: 'RP2350'}), 'pico');
  assert.equal(c({}, {}, {ID_VENDOR_ID: '2E8A', ID_MODEL_ID: '000f'}), 'pico');
  assert.equal(c({}, {IdLabel: 'XIAO-BOOT', IdType: 'vfat'}), 'esp32');
  assert.equal(c({}, {}, {ID_VENDOR_ID: '2237', ID_MODEL_ID: '4228'}), 'ereader');
  assert.equal(c({RotationRate: 7200}), 'drive');
  assert.equal(c({MediaCompatibility: ['flash_cf']}), 'cf');
  assert.equal(c({MediaCompatibility: ['flash_ms']}), 'ms');
  assert.equal(c({}), 'ssd');
  assert.equal(c({MediaCompatibility: ['thumb']}, {}, {ID_VENDOR_ID: '1209', ID_MODEL_ID: 'abcd'}, {'1209:abcd': 'ereader'}), 'ereader');
});

test('udev: phones from MTP and Apple IDs; cameras skipped; df parsing', () => {
  const blocks = L.parseUdev('UDEV  [12.3] add      /devices/pci0/usb1/1-2 (usb)\nACTION=add\nDEVTYPE=usb_device\nID_MTP_DEVICE=1\nID_MODEL=FP6\nID_SERIAL=Fairphone_FP6_ABC\n\n' +
    'P: /devices/pci0/usb1/1-3\nE: DEVTYPE=usb_device\nE: ID_VENDOR_ID=05ac\nE: ID_MODEL=iPhone\nE: ID_SERIAL_SHORT=00008110\n\n' +
    'E: DEVTYPE=usb_device\nE: ID_MTP_DEVICE=1\nE: ID_GPHOTO2=1\nE: ID_MODEL=Camera\n');
  assert.equal(blocks.length, 3);
  const phones = [...blocks].map(L.phoneDevice);
  assert.equal(phones[0].kind, 'android'); assert.equal(phones[0].uri, 'mtp://Fairphone_FP6_ABC/'); assert.equal(phones[0].id, 'usb:/devices/pci0/usb1/1-2');
  assert.equal(phones[1].kind, 'iphone'); assert.equal(phones[1].uri, 'afc://00008110/');
  assert.equal(phones[2], null);
  assert.deepEqual({...L.parseDf('     Used        1B-blocks\n38000000000 64000000000\n')}, {used: 38e9, size: 64e9});
});

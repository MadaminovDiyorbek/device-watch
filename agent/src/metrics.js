const si = require('systeminformation');

let netPrev = { t: 0, rx: 0, tx: 0, iface: null };

async function collectMetrics(options) {
  const location = options.location || '';
  const [osInfo, mem, currentLoad, cpu, fsSize, networkStats, temp, time] = await Promise.all([
    si.osInfo(),
    si.mem(),
    si.currentLoad(),
    si.cpu(),
    si.fsSize(),
    si.networkStats(),
    si.cpuTemperature().catch(() => ({ main: null })),
    si.time(),
  ]);

  const hostname = osInfo.hostname || 'unknown';
  const distro = `${osInfo.distro || osInfo.platform} ${osInfo.release || ''}`.trim();

  const nonInternal = (networkStats || []).filter((n) => n && n.operstate === 'up' && !n.internal);
  const iface = nonInternal[0] || networkStats[0];
  let netUpMbps = 0;
  let netDownMbps = 0;
  const now = Date.now();
  if (iface && netPrev.t && iface.iface === netPrev.iface) {
    const dt = (now - netPrev.t) / 1000;
    if (dt > 0.2) {
      const rxDelta = iface.rx_bytes - netPrev.rx;
      const txDelta = iface.tx_bytes - netPrev.tx;
      netDownMbps = Math.max(0, ((rxDelta * 8) / (dt * 1e6)));
      netUpMbps = Math.max(0, ((txDelta * 8) / (dt * 1e6)));
    }
  }
  if (iface) {
    netPrev = { t: now, rx: iface.rx_bytes, tx: iface.tx_bytes, iface: iface.iface };
  }

  const ramTotalGb = mem.total / 1e9;
  const ramUsedGb = mem.used / 1e9;
  const ramPercent = mem.total ? (mem.used / mem.total) * 100 : 0;

  let mainFs = fsSize.find((f) => {
    const mnt = (f.mount || '').toUpperCase();
    return mnt === '/' || mnt === 'C:' || mnt === 'C:\\';
  });
  if (!mainFs) mainFs = fsSize[0];
  const diskUsedGb = mainFs ? mainFs.used / 1e9 : 0;
  const diskTotalGb = mainFs ? mainFs.size / 1e9 : 0;
  const diskPercent = mainFs && mainFs.size ? mainFs.use : 0;

  const cpuUsage =
    typeof currentLoad.currentload === 'number'
      ? currentLoad.currentload
      : typeof currentLoad.avgload === 'number'
        ? currentLoad.avgload
        : 0;
  const cpuModel = [cpu.manufacturer, cpu.brand].filter(Boolean).join(' ').trim() || 'CPU';

  const specs = {
    cpu: cpuModel,
    ram: `${Math.round(ramTotalGb)} GB`,
    disk: mainFs ? `${Math.round(diskTotalGb)} GB (${mainFs.type || mainFs.fs})` : '—',
    os: distro,
    ip: iface?.ip4 || '—',
    location: location || '—',
  };

  const temperatureCpu =
    typeof temp.main === 'number'
      ? temp.main
      : Array.isArray(temp.main) && temp.main.length
        ? temp.main[0]
        : typeof temp.max === 'number'
          ? temp.max
          : null;

  return {
    hostname,
    cpuUsage,
    cpuModel,
    ramUsedGb: Number(ramUsedGb.toFixed(2)),
    ramTotalGb: Number(ramTotalGb.toFixed(2)),
    ramPercent,
    diskUsedGb: Number(diskUsedGb.toFixed(1)),
    diskTotalGb: Number(diskTotalGb.toFixed(1)),
    diskPercent,
    netUpMbps,
    netDownMbps,
    netTotalUpGb: options.sessionUpGb ?? 0,
    netTotalDownGb: options.sessionDownGb ?? 0,
    osString: `${hostname} / ${distro}`,
    specs,
    temperatureCpu,
    timeServer: time.current,
  };
}

module.exports = { collectMetrics };

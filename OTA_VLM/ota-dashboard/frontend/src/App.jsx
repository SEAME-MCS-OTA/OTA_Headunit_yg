import { useCallback, useEffect, useMemo, useState } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer
} from "recharts";
import { MapContainer, TileLayer, CircleMarker, Tooltip as MapTooltip } from "react-leaflet";

const API_URL =
  import.meta.env.VITE_API_URL ||
  `${window.location.protocol}//${window.location.hostname}:4000`;

function usePolling(fetcher, intervalMs) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let active = true;
    let timer;

    async function tick() {
      try {
        const res = await fetcher();
        if (active) {
          setData(res);
          setError(null);
        }
      } catch (err) {
        if (active) setError(err.message);
      }
      timer = setTimeout(tick, intervalMs);
    }

    tick();

    return () => {
      active = false;
      if (timer) clearTimeout(timer);
    };
  }, [fetcher, intervalMs]);

  return { data, error };
}

async function fetchJson(path) {
  const res = await fetch(`${API_URL}${path}`);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Request failed: ${path}`);
  }
  return res.json();
}

function SummaryCard({ label, value, hint }) {
  return (
    <div className="card summary-card">
      <div className="summary-label">{label}</div>
      <div className="summary-value">{value}</div>
      <div className="summary-hint">{hint}</div>
    </div>
  );
}

function Section({ title, children }) {
  return (
    <section className="card section">
      <header className="section-title">{title}</header>
      {children}
    </section>
  );
}

function buildComment({ scopeLabel, summary, rootCauseData, timeBucketData }) {
  if (!summary || summary.total_records === undefined) {
    return "No data available yet.";
  }

  const total = Number(summary.total_records || 0);
  const failures = Number(summary.failure_records || 0);
  const failureRate = total ? (failures / total) * 100 : 0;

  const topRoot = [...rootCauseData]
    .sort((a, b) => Number(b.count || 0) - Number(a.count || 0))
    .find((item) => item.root_cause && item.root_cause !== "UNKNOWN");

  const topTime = [...timeBucketData]
    .sort((a, b) => Number(b.failures || 0) - Number(a.failures || 0))
    .find((item) => item.time_bucket && item.time_bucket !== "UNKNOWN");

  const parts = [];
  parts.push(`${scopeLabel} shows ${total} logs with a ${failureRate.toFixed(1)}% failure rate.`);
  if (topRoot) {
    parts.push(`Most common failure is ${topRoot.root_cause}.`);
  }
  if (topTime) {
    parts.push(`Failures peak during ${topTime.time_bucket}.`);
  }
  return parts.join(" ");
}

export default function App() {
  const [selectedCity, setSelectedCity] = useState(null);

  const query = selectedCity ? `?city=${encodeURIComponent(selectedCity)}` : "";
  const fetchSummary = useCallback(() => fetchJson(`/stats/summary${query}`), [query]);
  const fetchRootCause = useCallback(() => fetchJson(`/stats/root-cause${query}`), [query]);
  const fetchCities = useCallback(() => fetchJson("/stats/cities"), []);
  const fetchTimeBucket = useCallback(() => fetchJson(`/stats/time-bucket${query}`), [query]);
  const fetchNetworkBuckets = useCallback(
    () => fetchJson(`/stats/network-buckets${query}`),
    [query]
  );
  const fetchModels = useCallback(() => fetchJson(`/stats/models${query}`), [query]);

  const summaryState = usePolling(fetchSummary, 5000);
  const rootCauseState = usePolling(fetchRootCause, 5000);
  const citiesState = usePolling(fetchCities, 5000);
  const timeBucketState = usePolling(fetchTimeBucket, 5000);
  const networkBucketsState = usePolling(fetchNetworkBuckets, 5000);
  const modelsState = usePolling(fetchModels, 5000);

  const summary = summaryState.data;
  const rootCause = rootCauseState.data;
  const cities = citiesState.data;
  const timeBucket = timeBucketState.data;
  const networkBuckets = networkBucketsState.data;
  const models = modelsState.data;

  const rootCauseData = Array.isArray(rootCause) ? rootCause : [];
  const timeBucketData = Array.isArray(timeBucket) ? timeBucket : [];
  const cityData = Array.isArray(cities) ? cities.filter((c) => c.coords) : [];
  const modelData = Array.isArray(models) ? models : [];

  const rssiData = useMemo(() => {
    if (!networkBuckets || !networkBuckets.rssi) return [];
    return Object.entries(networkBuckets.rssi).map(([bucket, count]) => ({
      bucket,
      count
    }));
  }, [networkBuckets]);

  const latencyData = useMemo(() => {
    if (!networkBuckets || !networkBuckets.latency) return [];
    return Object.entries(networkBuckets.latency).map(([bucket, count]) => ({
      bucket,
      count
    }));
  }, [networkBuckets]);

  const failureRate = summary?.failure_rate ?? 0;
  const failurePct = (failureRate * 100).toFixed(1);
  const scopeLabel = selectedCity ? `City: ${selectedCity}` : "Germany Overview";
  const comment = buildComment({
    scopeLabel,
    summary,
    rootCauseData,
    timeBucketData
  });

  return (
    <div className="app">
      <header className="hero">
        <div>
          <p className="eyebrow">OTA OPERATIONS</p>
          <h1>Realtime Failure Analytics</h1>
          <p className="subtitle">
            Live aggregation of VLM-classified failure logs with city-level insights
            for Germany.
          </p>
        </div>
        <div className="pulse">
          <span className="pulse-dot" />
          <span>streaming</span>
        </div>
      </header>

      <section className="scope-bar">
        <div className="scope-title">{scopeLabel}</div>
        {selectedCity && (
          <button className="scope-reset" type="button" onClick={() => setSelectedCity(null)}>
            Reset to Germany
          </button>
        )}
      </section>

      <section className="summary-grid">
        <SummaryCard
          label="Total logs"
          value={summary?.total_records ?? "-"}
          hint="All ingested events"
        />
        <SummaryCard
          label="Failures"
          value={summary?.failure_records ?? "-"}
          hint="Events marked as failure"
        />
        <SummaryCard
          label="Failure rate"
          value={`${failurePct}%`}
          hint="Failures / total"
        />
      </section>

      <section className="map-layout">
        <Section title="Germany Failure Map">
          <div className="map-wrapper">
            <MapContainer
              center={[51.1657, 10.4515]}
              zoom={6}
              scrollWheelZoom={false}
              className="map"
            >
              <TileLayer
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                attribution="&copy; OpenStreetMap contributors"
              />
              {cityData.map((city) => {
                const rate = city.total ? city.failures / city.total : 0;
                const radius = 10 + Math.min(20, rate * 40);
                return (
                  <CircleMarker
                    key={city.city}
                    center={[city.coords.lat, city.coords.lon]}
                    radius={radius}
                    pathOptions={{
                      color: "#f4b350",
                      fillColor: "#f97316",
                      fillOpacity: 0.7
                    }}
                    eventHandlers={{
                      click: () => setSelectedCity(city.city)
                    }}
                  >
                    <MapTooltip>
                      <strong>{city.city}</strong>
                      <div>Failures: {city.failures}</div>
                      <div>Rate: {(rate * 100).toFixed(1)}%</div>
                    </MapTooltip>
                  </CircleMarker>
                );
              })}
            </MapContainer>
          </div>
          <div className="comment-box">
            <div className="comment-title">Ops Comment</div>
            <p className="comment-text">{comment}</p>
          </div>
        </Section>

        <div className="side-stack">
          <Section title="Root Cause Distribution">
            <div className="chart chart-compact">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={rootCauseData} margin={{ left: 10, right: 10 }}>
                  <XAxis dataKey="root_cause" tick={{ fill: "#f4f1eb" }} />
                  <YAxis tick={{ fill: "#f4f1eb" }} />
                  <Tooltip
                    labelStyle={{ color: "#000" }}
                    itemStyle={{ color: "#000" }}
                  />
                  <Bar dataKey="count" fill="var(--accent)" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Section>

          <Section title="Failures by Time Bucket">
            <div className="chart chart-compact">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={timeBucketData} margin={{ left: 10, right: 10 }}>
                  <XAxis dataKey="time_bucket" tick={{ fill: "#f4f1eb" }} />
                  <YAxis tick={{ fill: "#f4f1eb" }} />
                  <Tooltip
                    labelStyle={{ color: "#000" }}
                    itemStyle={{ color: "#000" }}
                  />
                  <Bar dataKey="failures" fill="var(--highlight)" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Section>

          <Section title="Network RSSI (failures)">
            <div className="chart chart-compact">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={rssiData} margin={{ left: 10, right: 10 }}>
                  <XAxis dataKey="bucket" tick={{ fill: "#f4f1eb" }} />
                  <YAxis tick={{ fill: "#f4f1eb" }} />
                  <Tooltip
                    labelStyle={{ color: "#000" }}
                    itemStyle={{ color: "#000" }}
                  />
                  <Bar dataKey="count" fill="var(--accent-2)" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Section>

          <Section title="Network Latency (failures)">
            <div className="chart chart-compact">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={latencyData} margin={{ left: 10, right: 10 }}>
                  <XAxis dataKey="bucket" tick={{ fill: "#f4f1eb" }} />
                  <YAxis tick={{ fill: "#f4f1eb" }} />
                  <Tooltip
                    labelStyle={{ color: "#000" }}
                    itemStyle={{ color: "#000" }}
                  />
                  <Bar dataKey="count" fill="var(--accent-3)" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Section>

          <Section title="Vehicle Series Breakdown">
            <div className="chart chart-compact">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={modelData} margin={{ left: 10, right: 10 }}>
                  <XAxis dataKey="series" tick={{ fill: "#f4f1eb" }} />
                  <YAxis tick={{ fill: "#f4f1eb" }} />
                  <Tooltip
                    labelStyle={{ color: "#000" }}
                    itemStyle={{ color: "#000" }}
                  />
                  <Bar dataKey="count" fill="var(--accent)" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Section>
        </div>
      </section>
    </div>
  );
}

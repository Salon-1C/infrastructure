import http from 'k6/http';
import { check, sleep } from 'k6';

// Demonstrates HikariCP pool exhaustion under 700 VUs and its mitigation via
// Traefik WRR across 2 replicas (each with an independent pool of 10 connections).
//
// ── Run 1: single-replica baseline (expect ~0.50% failures, threshold FAILS) ──
//   docker compose up --scale blume-business-logic-ms=1 -d
//   k6 run -e BASE_URL=https://localhost tests/performance/scaling_test.js
//
// ── Run 2: two-replica scenario (expect 0% failures, threshold PASSES) ────────
//   docker compose up --scale blume-business-logic-ms=2 -d
//   k6 run -e BASE_URL=https://localhost tests/performance/scaling_test.js
//
// Override BASE_URL for remote hosts:
//   k6 run -e BASE_URL=https://192.168.1.X tests/performance/scaling_test.js

const BASE_URL = __ENV.BASE_URL || 'https://localhost';

export const options = {
  insecureSkipTLSVerify: true,

  stages: [
    { duration: '20s', target: 50  },  // warm-up
    { duration: '30s', target: 200 },  // low load
    { duration: '30s', target: 575 },  // single-replica knee (~10 pool × response-time factor)
    { duration: '60s', target: 700 },  // hold: fails 1 replica, passes 2 replicas
    { duration: '20s', target: 0   },  // ramp-down
  ],

  thresholds: {
    http_req_failed: ['rate==0'],  // 0% failures — passes with 2 replicas, fails with 1
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/api/cursos/explorar`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}

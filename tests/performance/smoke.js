import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
  },
  scenarios: {
    health_and_shell: {
      executor: 'constant-vus',
      vus: Number(__ENV.VUS || 10),
      duration: __ENV.DURATION || '30s',
    },
  },
};

const baseUrl = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  const health = http.get(`${baseUrl}/api/v1/platform/status`);
  check(health, { 'platform status responds': (r) => r.status === 200 });
  const login = http.get(`${baseUrl}/login`);
  check(login, { 'login renders': (r) => r.status === 200 });
  sleep(1);
}

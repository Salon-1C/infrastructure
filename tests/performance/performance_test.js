import http from 'k6/http';
import { check, sleep } from 'k6';

// Override with: k6 run -e BASE_URL=https://192.168.1.X performance_test.js
const BASE_URL = __ENV.BASE_URL || 'https://localhost';

export const options = {
  // Required for the self-signed TLS certificate used by Traefik in local deployment
  insecureSkipTLSVerify: true,

  stages: [
    { duration: '30s', target: 1    },  // warm-up
    { duration: '30s', target: 50   },
    { duration: '30s', target: 200  },
    { duration: '30s', target: 500  },
    { duration: '30s', target: 2000 },  // stress / break point
    { duration: '30s', target: 0    },  // ramp-down
  ],
};

export default function () {
  const res = http.get(`${BASE_URL}/api/cursos/explorar`);

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  sleep(1);
}

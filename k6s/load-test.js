import http from 'k6/http';
import { sleep } from 'k6';

export let options = {
  scenarios: {
    // smoke_test_150: {
    //   executor: 'constant-vus',
    //   vus: 150,
    //   duration: '15s',
    //   exec: 'smoke',
    // },

    // smoke_test_250: {
    //   executor: 'constant-vus',
    //   vus: 250,
    //   duration: '15s',
    //   exec: 'smoke',
    // },

    // smoke_test_375: {
    //   executor: 'constant-vus',
    //   vus: 375,
    //   duration: '15s',
    //   exec: 'smoke',
    // },

    // smoke_test_450: {
	//   executor: 'constant-vus',
    //   vus: 450,
    //   duration: '15s',
    //   exec: 'smoke',
    // },

	// 	stress_test_150: {
	// 	executor: 'ramping-vus',
	// 	startVUs: 0,
	// 	stages: [
	// 		{ duration: '15s', target: 25 },
	// 		{ duration: '15s', target: 50 },
	// 		{ duration: '15s', target: 75 },
	// 		{ duration: '15s', target: 100 },
	// 		{ duration: '15s', target: 150 },
	// 		{ duration: '15s', target: 0},
	// 	],
	// 	exec: 'stress',
	// },

	// stress_test_250: {
	// executor: 'ramping-vus',
	// startVUs: 0,
	// stages: [
	// { duration: '15s', target: 50 },
	// { duration: '15s', target: 100 },
	// { duration: '15s', target: 150 },
	// { duration: '15s', target: 200 },
	// { duration: '15s', target: 250 },
	// { duration: '15s', target: 0},
	// ],
	// exec: 'stress',
	// },

	// stress_test_375: {
	// executor: 'ramping-vus',
	// startVUs: 0,
	// stages: [
	// { duration: '15s', target: 75 },
	// { duration: '15s', target: 150 },
	// { duration: '15s', target: 225 },
	// { duration: '15s', target: 300 },
	// { duration: '15s', target: 375 },
	// { duration: '15s', target: 0},
	// ],
	// exec: 'stress',
	// },

	stress_test_375: {
	executor: 'ramping-vus',
	startVUs: 0,
	stages: [
	{ duration: '15s', target: 100 },
	{ duration: '15s', target: 100 },
	{ duration: '15s', target: 300 },
	{ duration: '15s', target: 400 },
	{ duration: '15s', target: 600 },
	{ duration: '15s', target: 0},
	],
	exec: 'stress',
	},
  },
};

export function smoke() {
  http.get('http://104.236.114.203/api/hello');
  sleep(1);
}

export function stress() {
  http.get('http://104.236.114.203/api/hello');
  sleep(0.5);
}

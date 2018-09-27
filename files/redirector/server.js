'use strict';

const fs = require('fs');
const http = require('http');
const https = require('https');
const path = require('path');

/**
 * Redirect all requests for `w3c-test.org` and `not-w3c-test.org` (including
 * subdomains) to the equivalent location on `web-platform-tests.live` and
 * `not-web-platform-tests.live`, respectively.
 */
const onRequest = (protocol, request, response) => {
  const { method, url, httpVersion, headers } = request;

  console.log(method + ' ' + url + ' HTTP/' + httpVersion);
  for (const name in headers) {
    console.log(name + ': ' + headers[name]);
  }
  console.log();

  if (/\/\.well-known/acme-challenge/.test(url)) {
    serveFile(request, response);
    return;
  }

  const host = request.headers.host
    .replace('w3c-test.org', 'web-platform-tests.live');
  const location = protocol + '://' + host + request.url;
  response.statusCode = 307;
  response.setHeader('Location', location);
  response.end();
};

const serveFile = (request, response) => {
  const path = path.join(__dirname, path.resolve('/', request.url));

  fs.readFile(path, 'utf-8', (err, contents) => {
    if (err) {
      response.statusCode = 500;
      response.end(err.message);
      return;
    }

    response.statusCode = 200;
    response.end(contents);
  });
};

const onListening = (protocol) => {
  console.log(protocol + ' server online');
};

const onError = (protocol, error) => {
  console.error(protocol + ' server error: ' + error.message);
  process.exit(1);
};

http.createServer(onRequest.bind(null, 'http'))
  .listen(80)
  .on('listening', onListening.bind(null, 'http'))
  .on('error', onError.bind(null, 'http'));
 
https.createServer(onRequest.bind(null, 'https'))
  .listen(443)
  .on('listening', onListening.bind(null, 'https'))
  .on('error', onError.bind(null, 'https'));

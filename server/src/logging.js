export function privateLoggerOptions(extra = {}) {
  return {
    ...extra,
    redact: ["req.headers.authorization", "req.headers.cookie"],
    serializers: {
      ...extra.serializers,
      req: (request) => ({
        method: request.method,
        url: request.url?.split("?")[0],
        remoteAddress: request.ip ?? request.remoteAddress,
        remotePort: request.socket?.remotePort,
      }),
    },
  };
}
export function safeErrorSummary(error) {
  return {
    errorCode: /^[A-Z0-9_]{1,80}$/.test(error.code ?? "")
      ? error.code
      : "INTERNAL",
    errorType: /^[A-Za-z][A-Za-z0-9]{0,40}$/.test(error.name ?? "")
      ? error.name
      : "Error",
  };
}

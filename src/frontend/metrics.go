package main

import (
	"fmt"
	"net/http"
	"sync/atomic"
)

// withRequestMetrics exposes a per-process counter without request labels.
func withRequestMetrics(next http.Handler, basePath string) http.Handler {
	var completed atomic.Uint64

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == basePath+"/metrics" {
			if r.Method != http.MethodGet && r.Method != http.MethodHead {
				w.Header().Set("Allow", "GET, HEAD")
				http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
				return
			}
			w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
			if r.Method == http.MethodHead {
				return
			}
			fmt.Fprintf(w,
				"# HELP frontend_http_requests_total Completed HTTP requests excluding health and metrics endpoints.\n"+
					"# TYPE frontend_http_requests_total counter\n"+
					"frontend_http_requests_total %d\n", completed.Load())
			return
		}

		next.ServeHTTP(w, r)
		if r.URL.Path != basePath+"/_healthz" {
			completed.Add(1)
		}
	})
}

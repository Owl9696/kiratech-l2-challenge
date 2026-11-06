package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

func TestRequestMetrics(t *testing.T) {
	for _, base := range []string{"", "/shop"} {
		t.Run("base="+base, func(t *testing.T) {
			handler := withRequestMetrics(http.HandlerFunc(
				func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusNoContent)
				}), base)

			request := func(method, path string) *httptest.ResponseRecorder {
				rec := httptest.NewRecorder()
				handler.ServeHTTP(rec, httptest.NewRequest(method, base+path, nil))
				return rec
			}

			assertCount := func(want string) {
				t.Helper()
				rec := request(http.MethodGet, "/metrics")
				if rec.Code != http.StatusOK {
					t.Fatalf("metrics status: %d", rec.Code)
				}
				if rec.Header().Get("Content-Type") != "text/plain; version=0.0.4; charset=utf-8" {
					t.Fatal("unexpected metrics content type")
				}
				if !strings.Contains(rec.Body.String(), "\nfrontend_http_requests_total "+want+"\n") {
					t.Fatalf("unexpected metrics: %s", rec.Body.String())
				}
			}

			assertCount("0")
			request(http.MethodGet, "/_healthz")
			assertCount("0")

			if rec := request(http.MethodGet, "/cart"); rec.Code != http.StatusNoContent {
				t.Fatal("middleware changed the application response")
			}
			assertCount("1")

			if rec := request(http.MethodPost, "/metrics"); rec.Code != http.StatusMethodNotAllowed {
				t.Fatal("POST /metrics should be rejected")
			}
			if rec := request(http.MethodHead, "/metrics"); rec.Body.Len() != 0 {
				t.Fatal("HEAD /metrics should have no body")
			}
			assertCount("1")

			var wg sync.WaitGroup
			for i := 0; i < 100; i++ {
				wg.Add(1)
				go func() {
					defer wg.Done()
					request(http.MethodGet, "/cart")
				}()
			}
			wg.Wait()
			assertCount("101")
		})
	}
}

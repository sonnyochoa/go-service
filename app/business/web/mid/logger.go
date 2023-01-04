package mid

import (
	"context"
	"net/http"
	"time"

	"github.com/sonnyochoa/go-service/foundation/web"
	"go.uber.org/zap"
)

// Logger ...
func Logger(log *zap.SugaredLogger) web.Middleware {

	m := func(handler web.Handler) web.Handler {

		h := func(ctx context.Context, w http.ResponseWriter, r *http.Request) error {

			// If the context is missing this value, request the service to be
			// shutdown gracefully
			v, err := web.GetValues(ctx)
			if err != nil {
				return err // web.NewShutdownError("web value missing from context")
			}

			log.Infow("request started", "trace_id", v.TraceID, "method", r.Method,
				"path", r.URL.Path, "remoteaddr", r.RemoteAddr)

			// call the next handler
			err = handler(ctx, w, r)

			log.Infow("request completed", "trace_id", v.TraceID, "method", r.Method,
				"path", r.URL.Path, "remoteaddr", r.RemoteAddr, "statuscode",
				v.StatusCode, "since", time.Since(v.Now))

			// return the error so it can be handled further up the chain
			return err
		}

		return h
	}

	return m
}

package cmdsignals

import (
	"context"
	"os"

	"github.com/ngicks/go-common/atomicsignal"
)

// SignalReceivedError aliases [atomicsignal.SignalReceivedError], the
// cancellation cause [NotifyContext] uses, so references stay stable as
// `cmdsignals.SignalReceivedError` without importing atomicsignal.
type SignalReceivedError = atomicsignal.SignalReceivedError

// NotifyContext is [atomicsignal.NotifyContext] with [ExitSignals] baked in
// as the canceling set: ctx is cancelled with [*SignalReceivedError] when one
// of [ExitSignals] is received.
//
// [atomicsignal.Notifier.Run] must be called, in another goroutine, to make
// signal propagation work. Callers should defer [atomicsignal.Notifier.Stop]
// and cancel to release resources (Stop also makes Run return); use explicit
// calls instead when a code path exits via [os.Exit], which skips defers:
//
//	n, ctx, cancel := cmdsignals.NotifyContext(ctx)
//	defer cancel(nil)
//	go n.Run()
//	defer n.Stop()
//
// Callers are advised to check errors with [context.Cause].
//
//	err := work(ctx)
//	if err != nil {
//		if errors.Is(err, ctx.Err()) {
//			if sigErr, ok := errors.AsType[*SignalReceivedError](context.Cause(ctx));  ok {
//				// log as signal cancellation using sigErr.Sig
//				// or print nothing and exit as if normal exit
//				return
//			}
//		}
//		// non-cancellation error.
//	}
//
// The registered signal set is fixed for the Notifier's lifetime; pass
// signals to additionally register non-canceling ones up front when a
// swapped-in handler ([atomicsignal.Notifier.Swap]) may need them later.
//
// The Notifier is stored in ctx; retrieve it with
// [atomicsignal.CtxValueNotifier].
func NotifyContext(
	inCtx context.Context,
	signals ...os.Signal,
) (n *atomicsignal.Notifier, ctx context.Context, cancel context.CancelCauseFunc) {
	return atomicsignal.NotifyContext(inCtx, ExitSignals[:], signals...)
}

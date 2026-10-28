package instance

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"

	pocketidinternalv1alpha1 "github.com/aclerici38/pocket-id-operator/api/v1alpha1"
)

func TestReconcile_WorkloadsDisabled_ManagedInstanceNotReady(t *testing.T) {
	ctx := context.Background()
	instance := &pocketidinternalv1alpha1.PocketIDInstance{
		ObjectMeta: metav1.ObjectMeta{Name: "managed", Namespace: "pocket-id"},
		Spec: pocketidinternalv1alpha1.PocketIDInstanceSpec{
			AppURL: "https://auth.example.com",
			EncryptionKey: &pocketidinternalv1alpha1.SensitiveValue{
				Value: "0123456789abcdef",
			},
		},
	}
	r := newReconcilerFor(t, instance)
	r.DisableWorkloads = true

	if _, err := r.Reconcile(ctx, ctrl.Request{NamespacedName: client.ObjectKeyFromObject(instance)}); err != nil {
		t.Fatalf("Reconcile: %v", err)
	}

	cond := readyCondition(t, r, instance)
	if cond.Status != metav1.ConditionFalse || cond.Reason != "WorkloadsDisabled" {
		t.Fatalf("expected Ready=False reason WorkloadsDisabled, got %+v", cond)
	}

	// Nothing may be deployed: the operator holds no RBAC for these kinds.
	if err := r.Get(ctx, client.ObjectKeyFromObject(instance), &appsv1.Deployment{}); !apierrors.IsNotFound(err) {
		t.Errorf("expected no Deployment, got err=%v", err)
	}
	if err := r.Get(ctx, client.ObjectKeyFromObject(instance), &corev1.Service{}); !apierrors.IsNotFound(err) {
		t.Errorf("expected no Service, got err=%v", err)
	}
	secrets := &corev1.SecretList{}
	if err := r.List(ctx, secrets, client.InNamespace(instance.Namespace)); err != nil {
		t.Fatalf("list secrets: %v", err)
	}
	if len(secrets.Items) != 0 {
		t.Errorf("expected no static API key Secret, got %d secrets", len(secrets.Items))
	}
}

func TestReconcile_WorkloadsDisabled_ExternalInstanceStillReconciles(t *testing.T) {
	ctx := context.Background()
	srv := httptest.NewTestServer(t, http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"currentVersion":"2.14.0"}`))
	}))
	srv.Start()

	instance := newExternalInstance(srv.URL)
	r := newReconcilerFor(t, instance, apiKeySecret())
	r.DisableWorkloads = true

	if _, err := r.Reconcile(ctx, ctrl.Request{NamespacedName: client.ObjectKeyFromObject(instance)}); err != nil {
		t.Fatalf("Reconcile: %v", err)
	}

	cond := readyCondition(t, r, instance)
	if cond.Status != metav1.ConditionTrue {
		t.Fatalf("expected Ready=True, got %+v", cond)
	}
}

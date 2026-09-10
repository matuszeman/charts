{{- /*
Provider-agnostic forwardAuth support for routes (ingressRoute + httpRoute).

The named app's `forwardAuth` block (apps.<name>.forwardAuth) is provider-agnostic: generic
controller-agnostic fields (authUrl, signinUrl, authResponseHeaders) plus a
`controllers.<controller>` block for controller-specific settings. For a traefik gateway the
generics map onto the forwardAuth Middleware (authUrl -> address, signinUrl -> authSigninURL)
and controllers.traefik.middlewareParams supplies the rest — the raw forwardAuth Middleware
fields (trustForwardHeader, authRequestHeaders, tls, ...). signinUrl -> authSigninURL gives a
native 401->sign-in redirect (Traefik 3.1+; its {url} return-URL token is a Traefik
substitution), so no custom errors-middleware chain is needed.

`appName` is optional: when unset, the route supplies the whole forwardAuth block (and
passthrough `service`) inline.

Passthrough: a route may declare `forwardAuth.passthrough.path: <path>` (e.g. /oauth2). That
path is routed straight to the provider `service` (apps.<name>.service, overridable per route),
bypassing the middleware — required for single-app oauth2-proxy / authentik setups. When the
provider service is in another namespace, the raw cross-namespace ref only works if you provide
the ReferenceGrant (HTTPRoute) / allowCrossNamespace (IngressRoute) yourself.

These are Traefik resources: they are only ever emitted for gateways whose controller is
`traefik`; any other controller is a hard error.
*/ -}}

{{- /*
Resolve the effective forwardAuth config for a route.
Emits YAML: { enabled, passthrough, spec, service, backend }.
  - spec:            the Traefik forwardAuth Middleware spec (built as described below)
  - service:         the raw resolved provider service {name, namespace, port}
  - backend:         what the passthrough route/rule should target {name, namespace, port}

Config schema — the forwardAuth block (on the app and/or the route) carries:
  - generic, controller-agnostic fields: authUrl, signinUrl (both support tpl), authResponseHeaders
  - controllers.<controller>: controller-specific settings. For traefik:
      middlewareParams: raw forwardAuth Middleware fields (trustForwardHeader,
                        authRequestHeaders, tls, headerField, ...)
      (sibling keys are reserved for future controller-specific settings, e.g. authUrlQueryParams)
Route values override app values field-by-field; controllers.<controller> is deep-merged.

Building the Traefik `spec` (gateway controller = traefik):
  1. map generics -> Traefik field names: authUrl -> address, signinUrl -> authSigninURL,
     authResponseHeaders -> authResponseHeaders
  2. deep-merge controllers.traefik.middlewareParams on top (may add or override mapped fields)
  3. append route.forwardAuth.authQueryParams to spec.address

`service` (passthrough target) = app.service merged with route.forwardAuth.service.

Args: (list $ $route $routeKey $gateway)
*/ -}}
{{- define "idp-app.forwardAuth.resolve" -}}
{{- $ := index . 0 -}}
{{- $route := index . 1 -}}
{{- $routeKey := index . 2 -}}
{{- $gateway := index . 3 -}}
{{- $fa := default dict $route.forwardAuth -}}
{{- $enabled := $fa.enabled | default false -}}
{{- $appFwd := dict -}}
{{- $appService := dict -}}
{{- if $fa.appName -}}
{{-   $app := include "idp-app.clusterConfigMapValue" (list $ "apps" $fa.appName) | fromYaml -}}
{{-   $appFwd = default dict $app.forwardAuth -}}
{{-   $appService = default dict $app.service -}}
{{- end -}}
{{- /* generic controller-agnostic fields, route overrides app */ -}}
{{- $authUrl := $fa.authUrl | default $appFwd.authUrl -}}
{{- $signinUrl := $fa.signinUrl | default $appFwd.signinUrl -}}
{{- $authResponseHeaders := $fa.authResponseHeaders | default $appFwd.authResponseHeaders -}}
{{- /* controller-specific block, route overrides app (deep-merge). Raw traefik forwardAuth
       Middleware fields live under controllers.traefik.middlewareParams; sibling keys are
       reserved for other controller-specific settings (e.g. authUrlQueryParams). */ -}}
{{- $appCtrl := default dict (index (default dict $appFwd.controllers) $gateway.controller) -}}
{{- $routeCtrl := default dict (index (default dict $fa.controllers) $gateway.controller) -}}
{{- $ctrl := mergeOverwrite (deepCopy $appCtrl) (deepCopy $routeCtrl) -}}
{{- $middlewareParams := default dict $ctrl.middlewareParams -}}
{{- /* map generics to the Traefik forwardAuth Middleware spec, then layer the raw params.
       authUrl/signinUrl support tpl; signinUrl -> authSigninURL keeps Traefik's {url}
       substitution token (single-brace, untouched by tpl). */ -}}
{{- $spec := dict -}}
{{- with $authUrl -}}{{-   $_ := set $spec "address" (tpl . $) -}}{{- end -}}
{{- with $signinUrl -}}{{-   $_ := set $spec "authSigninURL" (tpl . $) -}}{{- end -}}
{{- with $authResponseHeaders -}}{{-   $_ := set $spec "authResponseHeaders" . -}}{{- end -}}
{{- $spec = mergeOverwrite $spec (deepCopy $middlewareParams) -}}
{{- with $fa.authQueryParams -}}
{{-   $_ := set $spec "address" (printf "%s?%s" ($spec.address | required "forwardAuth: authUrl required (set apps.<appName>.forwardAuth.authUrl or forwardAuth.authUrl)") (include "idp-app.queryString" .)) -}}
{{- end -}}
{{- $passthroughPath := (default dict $fa.passthrough).path | default "" -}}
{{- $service := mergeOverwrite (deepCopy $appService) (deepCopy (default dict $fa.service)) -}}
{{- $backend := dict "name" $service.name "namespace" ($service.namespace | default $.Release.Namespace) "port" $service.port -}}
{{- toYaml (dict "enabled" $enabled "passthrough" $passthroughPath "spec" $spec "service" $service "backend" $backend) -}}
{{- end -}}

{{- /*
Render the Traefik forwardAuth Middleware resource for a route.
Traefik-only: fails for any other gateway controller.

Args: (list $ $route $routeKey $gateway)
*/ -}}
{{- define "idp-app.forwardAuth.middleware" -}}
{{- $ := index . 0 -}}
{{- $route := index . 1 -}}
{{- $routeKey := index . 2 -}}
{{- $gateway := index . 3 -}}
{{- if ne $gateway.controller "traefik" -}}
{{- fail (printf "forwardAuth: gateway '%s' has controller '%s', forwardAuth is only supported with 'traefik'" $route.gatewayName $gateway.controller) -}}
{{- end -}}
{{- $fa := include "idp-app.forwardAuth.resolve" (list $ $route $routeKey $gateway) | fromYaml -}}
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: {{ include "idp-app.fullname" $ }}-{{ $routeKey }}-forwardauth
  labels:
    {{- include "idp-app.labels" $ | nindent 4 }}
    {{- with $gateway.labelSelector }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- if or $route.annotations $gateway.annotationSelector }}
  annotations:
    {{- with $gateway.annotationSelector }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $route.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
spec:
  forwardAuth:
    {{- toYaml $fa.spec | nindent 4 }}
{{- end -}}

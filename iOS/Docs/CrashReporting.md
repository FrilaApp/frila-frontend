# Relatório de falhas e privacidade

Decisão da fundação: **MetricKit + Organizer do Xcode**.

Motivos: não adiciona um terceiro que receba telemetria, reduz a superfície de LGPD antes do piloto e já entrega diagnósticos simbolizados aos membros da conta Apple. O `ColetorMetricKit` assina payloads de métricas e diagnósticos desde a abertura do app.

Regras:

- Logs contêm somente código estável do erro, nome da RPC e duração.
- Nunca registrar nome, e-mail, telefone, token, payload ou coordenada.
- Erros de API são não fatais e passam por `TelemetryReporter`.
- O manifesto `PrivacyInfo.xcprivacy` declara que o app não rastreia nem transmite dados a terceiros nesta fundação.
- Para validar: distribuir um build interno, usar a ação Debug de falha controlada, aguardar o processamento do MetricKit e conferir a pilha simbolizada no Organizer em até 24 horas.

Se o time migrar para Crashlytics, a decisão exige revisão do manifesto de privacidade, do App Privacy e do fluxo de consentimento antes de adicionar o SDK.

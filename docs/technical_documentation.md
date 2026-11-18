# Documentação Técnica — CineGestor

## 1. Visão Geral da Arquitetura

O **CineGestor** segue o padrão **MVC / Provider (ChangeNotifier)** em Flutter, desacoplando regras de negócio, dados em nuvem e interface do usuário:

```text
               assets/cinemas/<unidade>/sala_X.json
                               │
                               ▼
                        RoomRepository
                               │
                               ▼
Firebase Firestore ◄──► RoomController (ChangeNotifier) ◄──► SharedPreferences (Cache)
(southamerica-east1)           │
       │                       ├──────────────────────┬──────────────────────┐
       ▼                       ▼                      ▼                      ▼
  AuthGate / Login     RoomSelectionPage       MaintenancePage        StagingPage
       │                       │                      │                      │
       ▼                       ▼                      ▼                      ▼
AuthController         DefectSummaryPage         HistoryPage     UserManagementPage
```

---

## 2. Modelos de Domínio (`lib/models/`)

### 2.1. `AppUser` e `UserRole` (`lib/models/app_user.dart`)
Define os **6 perfis hierárquicos de acesso (RBAC)**:

| Perfil | Abertura de Chamado | Triagem | Conclusão | Reabertura / Exclusão | Gestão de Equipe |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `operacao` | `staging` (Triagem) | ❌ | ❌ | ❌ | ❌ |
| `assistente` | `active` (Direto) | ❌ | ❌ | ❌ | ❌ |
| `encarregado` | `active` (Direto) | Aprova/Recusa | Conclui | ❌ | ❌ |
| `gerente` | `active` (Direto) | Aprova/Recusa | Conclui | Reabre e Exclui | Sim (Cinema Local) |
| `supervisor` | `active` (Direto) | Aprova/Recusa | Conclui | Reabre e Exclui | Sim (Rede / Multi-Cinema) |
| `admin` | Total | Total | Total | Total | Total (Sistema e Atualizações) |

* **Campos principais:** `id`, `name`, `username`, `email`, `role`, `cinemaId`, `cinemaName`, `active`, `mustChangePassword`.

### 2.2. `MaintenanceIssue` e `IssueStatus` (`lib/models/maintenance_issue.dart`)
Controla o ciclo de vida completo de cada demanda de manutenção:
* **Estados (`IssueStatus`):**
  - `staging`: Aguardando aprovação na triagem (aberto pela Operação).
  - `rejected`: Rejeitado na triagem com justificativa (`rejectionReason`).
  - `active`: Manutenção em andamento (poltrona em manutenção ativa).
  - `resolved`: Concluído com registro de data/hora (`resolvedAt`) e responsável (`resolvedBy`).
* **Impacto Operacional (`isBlockingSeat`):**
  - Defeitos como *Encosto Solto* ou *Assento Solto* são classificados como bloqueantes de venda.
* **Evidências Fotográficas:**
  - `beforePhotoBase64`: Foto tirada na abertura do chamado.
  - `afterPhotoBase64`: Foto do reparo concluído.

### 2.3. `Room` e `Seat` (`lib/models/room.dart`, `lib/models/seat.dart`)
Renderização em matriz fiel aos mapas oficiais de cinema (1.671 assentos no UCI Park Campo Grande):
* Linhas, colunas, corredores verticais e horizontais, além da localização da tela (`stage`).
* Tipos de assento: `Regular` (Normal), `Disability` (PCD Cadeirante), `Companion` (Acompanhante PCD) e `Obese` (P.O.).
* Marcadores de estado: `hasDefect`, `hasBlockingDefect` e `hasStaging`.

---

## 3. Segurança e Regras de Servidor (`firestore.rules`)

As regras de segurança estão implantadas no Cloud Firestore na região **`southamerica-east1` (São Paulo)**:
1. **Isolamento Multi-Tenant:** Um colaborador só lê e altera documentos pertencentes ao seu `cinemaId` (`belongsToCinema(resource.data.cinemaId)`).
2. **Imutabilidade de Histórico:** Campos essenciais de auditoria (`id`, `cinemaId`, `roomId`, `seatId`, `dateTime`, `reportedBy`, `beforePhotoBase64`) são estritamente imutáveis no servidor.
3. **Validação de Transições de Status:** O servidor bloqueia tentativas ilegais de alterar status sem o cargo exigido (ex: `operacao` não consegue aprovar chamados).
4. **Proteção de Fotos:** Limite estrito de tamanho de string Base64 no servidor (máximo 450 KB).

---

## 4. Otimização de Performance e Redução de Custos

Para operar com folga máxima dentro do plano gratuito (Spark) do Firebase:
1. **Stream Filtrado:** O `_listenToFirestoreIssues` escuta apenas `status in ['staging', 'active']`. Chamados finalizados deixam o stream e não gastam leituras na navegação diária.
2. **Leituras Únicas:** Eliminada a busca `.get()` redundante antes do stream.
3. **Persistência em Disco:** `FirebaseFirestore.instance.settings` configurado com `persistenceEnabled: true` e `cacheSizeBytes: CACHE_SIZE_UNLIMITED` (SQLite no Android e IndexedDB na Web).
4. **Paginação do Histórico:** `loadHistoricalIssues()` busca chamados resolvidos sob demanda com `.limit(25)`.
5. **Cache em Memória de Atualizações:** A verificação de novas versões em `app_config/version` possui teto de 1 checagem a cada 30 minutos.

---

## 5. Sessão e Login Persistente (`AuthGate`)

* Rota raiz `'/'` direciona para o componente `AuthGate` ([lib/widgets/auth_gate.dart](file:///home/lima/Projetos/manutencine/cinegestor-main/lib/widgets/auth_gate.dart)).
* **Comportamento:**
  - Carrega a credencial do `SharedPreferences` e valida o token do `FirebaseAuth`.
  - Usuário previamente logado entra **direto na tela de salas (`RoomSelectionPage`)** sem tela de login intermediária.
  - O logout limpa as preferências locais, encerra a sessão no Firebase e redireciona de volta ao Login.

---

## 6. Rotas da Aplicação (`lib/main.dart`)

* `/`: `AuthGate` — Ponto de entrada com verificação de sessão e roteamento automático.
* `/login`: `LoginPage` — Autenticação por e-mail e senha.
* `/rooms`: `RoomSelectionPage` — Seleção de salas, termômetro operacional, contadores e atalhos rápidos.
* `/maintenance`: `MaintenancePage` — Mapa interativo da sala, zoom, detalhes e abertura de chamados.
* `/staging`: `StagingPage` — Triagem de solicitações pendentes abertas pela Operação.
* `/history`: `HistoryPage` — Histórico com filtros por sala, assento, status e paginação.
* `/defects`: `DefectSummaryPage` — Roteiro de manutenção em lote agrupado por tipo de defeito e exportação para WhatsApp.
* `/users`: `UserManagementPage` — Painel de gestão da equipe, criação de logins, troca de cargos e desativação.

---

## 7. Ambientes e Distribuição

* **Web (PWA):** Hospedado no Firebase Hosting: `https://cinegestor-manutencao.web.app` (seletor nativo de fotos via HTML5 Canvas).
* **Android:** Compilação nativa otimizada (`arm64-v8a`) com ícone adaptativo e serviço integrado de atualização automática de APK (`AppUpdateService`).
